// test_hp_read.js
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.4/index.js";
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js";
import { parseNumberEnv, parseBoolEnv, getDeviceForVU } from "./utils.js";
import { getTelemetryLatest } from "./target_url.js";

// ==============================
// Environment
// ==============================
const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";

// Tag to distinguish solution variants
const SOLUTION_ID = __ENV.SOLUTION_ID || "baseline";
const PROFILE = "read-heavy";
const ABORT_ON_FAIL = parseBoolEnv("ABORT_ON_FAIL", false);

// High-performance read test parameters
const RATE_START = parseNumberEnv("RATE_START", 50); // initial RPS
const RATE_TARGET = parseNumberEnv("RATE_TARGET", 1000); // peak RPS

// -------- Stage --------
const STAGE_START = parseNumberEnv("STAGE_START", 1); // minutes per start stage
const STAGE_RAMP = parseNumberEnv("STAGE_RAMP", 10); // minutes per ramp stage
const STAGE_PEAK = parseNumberEnv("STAGE_PEAK", 5); // minutes to hold peak

// VU pool
const VU = parseNumberEnv("VU", 50); // pre-allocated VUs
const MAX_VU = parseNumberEnv("MAX_VU", 300); // max VUs

// ==============================
// k6 options
// ==============================
export const options = {
  cloud: {
    name: `${SOLUTION_ID}: ${PROFILE}`,
    distribution: {
      distributionLabel1: { loadZone: "amazon:ca:montreal", percent: 100 },
    },
  },
  // Global tags for all metrics
  tags: {
    solution: SOLUTION_ID,
    profile: PROFILE,
  },

  // SLO:
  // "rate<0.01": Less than 1% of requests return an error.
  // "p(99)<300": 99% of requests have a response time below 300ms.
  // "p(90)<1000": 90% of requests have a response time below 1000ms.

  thresholds: {
    // Overall failure rate
    "http_req_failed{scenario:hp_read_telemetry}": [
      {
        threshold: "rate<0.01", // Failure rate < 1%
        abortOnFail: ABORT_ON_FAIL,
        delayAbortEval: "10s",
      },
    ],

    // GET /telemetry/latest
    "http_req_duration{scenario:hp_read_telemetry,endpoint:telemetry_get_latest}":
      [
        {
          threshold: "p(99)<300", // 99% of requests < 300ms
          abortOnFail: ABORT_ON_FAIL, // abort when 1st failure
          delayAbortEval: "10s",
        },
        { threshold: "p(90)<1000" },
      ],
  },

  scenarios: {
    hp_read_telemetry: {
      executor: "ramping-arrival-rate",
      startRate: 0, // initial RPS
      timeUnit: "1s", // RPS-based

      preAllocatedVUs: VU, // initial VU pool
      maxVUs: MAX_VU, // safety upper bound

      // Smooth ramp up to RATE_TARGET and then hold
      stages: [
        { duration: `${STAGE_START}m`, target: RATE_START }, // warm-up
        { duration: `${STAGE_RAMP}m`, target: RATE_TARGET }, // reach peak
        { duration: `${STAGE_PEAK}m`, target: RATE_TARGET }, // hold peak
        { duration: `1m`, target: 0 }, // cool down
      ],

      gracefulStop: "60s",
      exec: "hp_read_telemetry",
    },
  },
};

// ==============================
// Scenario function
// ==============================
export function hp_read_telemetry() {
  const device = getDeviceForVU();
  getTelemetryLatest({ base_url: BASE_URL, device });
}

export default hp_read_telemetry;

// ==============================
// Summary output
// ==============================
export function handleSummary(data) {
  return {
    "hp_read_test.json": JSON.stringify(data, null, 2),
    "hp_read_test.html": htmlReport(data),
    stdout: textSummary(data, { indent: " ", enableColors: true }),
  };
}
