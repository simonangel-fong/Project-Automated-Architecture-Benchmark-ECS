// constant_read.js
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.4/index.js";
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js";
import { parseNumberEnv, getDeviceForVU } from "./utils.js";
import { getTelemetryLatest } from "./target_url.js";

// ==============================
// Environment
// ==============================
const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";

// Tag to distinguish solution variants
const SOLUTION_ID = __ENV.SOLUTION_ID || "baseline";
const PROFILE = "constant-read";
const ABORT_ON_FAIL = false;

// High-performance read test parameters
const RATE_TARGET = parseNumberEnv("RATE_TARGET", 1000); // peak RPS

// -------- Stage --------
const STAGE_START = parseNumberEnv("STAGE_START", 1); // minutes per start stage
const STAGE_CONSTANT = parseNumberEnv("STAGE_CONSTANT", 1); // minutes for constant

// VU pool
const VU = parseNumberEnv("VU", 50); // pre-allocated VUs
const MAX_VU = parseNumberEnv("MAX_VU", 200); // max VUs

// ==============================
// k6 options
// ==============================
export const options = {
  cloud: {
    name: `Constant(Read): ${SOLUTION_ID} – ${RATE_TARGET} RPS`,
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
    "http_req_failed{scenario:constant_read}": [
      {
        threshold: "rate<0.01", // Failure rate < 1%
        abortOnFail: ABORT_ON_FAIL,
        // delayAbortEval: "10s",
      },
    ],

    // GET /telemetry/latest
    "http_req_duration{scenario:constant_read,endpoint:telemetry_get_latest}": [
      {
        threshold: "p(99)<300", // 99% of requests < 300ms
        // abortOnFail: ABORT_ON_FAIL, // abort when 1st failure
        // delayAbortEval: "10s",
      },
      { threshold: "p(90)<1000" },
    ],
  },

  scenarios: {
    constant_read: {
      executor: "ramping-arrival-rate",
      startRate: 0, // initial RPS
      timeUnit: "1s", // RPS-based

      preAllocatedVUs: VU, // initial VU pool
      maxVUs: MAX_VU, // safety upper bound

      // Smooth ramp up to RATE_TARGET and then hold
      stages: [
        { duration: `${STAGE_START}m`, target: RATE_TARGET }, //
        { duration: `${STAGE_CONSTANT}m`, target: RATE_TARGET }, //
      ],
      gracefulStop: "60s",
      exec: "constant_read",
    },
  },
};

// ==============================
// Scenario function
// ==============================
export function constant_read() {
  const device = getDeviceForVU();
  getTelemetryLatest({ base_url: BASE_URL, device });
}

export default constant_read;

// ==============================
// Summary output
// ==============================
export function handleSummary(data) {
  return {
    "constant_read.json": JSON.stringify(data, null, 2),
    "constant_read.html": htmlReport(data),
    stdout: textSummary(data, { indent: " ", enableColors: true }),
  };
}
