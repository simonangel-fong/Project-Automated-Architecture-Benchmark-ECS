// stress_testing_write.js
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.4/index.js";
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js";
import { parseNumberEnv, getDeviceForVU } from "./utils.js";
import { postTelemetry } from "./target_url.js";

// ==============================
// Environment
// ==============================
const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";

// Tag to distinguish solution variants
const SOLUTION_ID = __ENV.SOLUTION_ID || "baseline"; // e.g. Sol-Baseline / Sol-ECS / Sol-Redis
const PROFILE = "write-stress-testing";
const ABORT_ON_FAIL = true;

// High-performance write test parameters
const RATE_START = parseNumberEnv("RATE_START", 50); // initial RPS
const RATE_TARGET = parseNumberEnv("RATE_TARGET", 1000); // peak RPS

// -------- Stage --------
const STAGE_START = parseNumberEnv("STAGE_START", 1); // minutes per start stage
const STAGE_RAMP = parseNumberEnv("STAGE_RAMP", 1); // minutes per ramp stage
const STAGE_PEAK = parseNumberEnv("STAGE_PEAK", 1); // minutes to hold peak

// VU pool
const VU = parseNumberEnv("VU", 50); // pre-allocated VUs
const MAX_VU = parseNumberEnv("MAX_VU", 200); // safety upper bound

// ==============================
// k6 options
// ==============================
export const options = {
  cloud: {
    name: `Stress Testing(Write): ${SOLUTION_ID} – ${RATE_TARGET} RPS`,
  },

  // Global tags applied to all metrics
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
    "http_req_failed{scenario:hp_write_telemetry}": [
      {
        threshold: "rate<0.01", // Failure rate < 1%
        abortOnFail: ABORT_ON_FAIL,
        // delayAbortEval: "10s",
      },
    ],

    // POST /telemetry
    "http_req_duration{scenario:hp_write_telemetry,endpoint:telemetry_post}": [
      {
        threshold: "p(99)<300", // 99% of requests < 300ms
        // abortOnFail: ABORT_ON_FAIL, // abort when 1st failure
        // delayAbortEval: "10s",
      },
      { threshold: "p(90)<1000" },
    ],
  },

  scenarios: {
    hp_write_telemetry: {
      executor: "ramping-arrival-rate",
      startRate: 0, // initial RPS
      timeUnit: "1s", // RPS-based

      preAllocatedVUs: VU, // initial VU pool
      maxVUs: MAX_VU, // max VUs

      // Smooth ramp to RATE_TARGET and then hold
      stages: [
        { duration: `2m`, target: 400 }, //
        { duration: `60m`, target: 700 }, //


        // { duration: `${STAGE_START}m`, target: RATE_START }, // warm-up
        // { duration: `${STAGE_RAMP}m`, target: 150 }, //
        // { duration: `${STAGE_RAMP}m`, target: 150 }, //
        // { duration: `${STAGE_RAMP}m`, target: 200 }, //
        // { duration: `${STAGE_RAMP}m`, target: 200 }, //
        // { duration: `${STAGE_RAMP}m`, target: 250 }, //
        // { duration: `${STAGE_RAMP}m`, target: 250 }, //
        // { duration: `${STAGE_RAMP}m`, target: 300 }, //
        // { duration: `${STAGE_RAMP}m`, target: 300 }, //
        // { duration: `${STAGE_RAMP}m`, target: 350 }, //
        // { duration: `${STAGE_RAMP}m`, target: 350 }, //
        // { duration: `${STAGE_RAMP}m`, target: 400 }, //
        // { duration: `${STAGE_RAMP}m`, target: 400 }, //
        // { duration: `${STAGE_RAMP}m`, target: 450 }, //
        // { duration: `${STAGE_RAMP}m`, target: 450 }, //
        // { duration: `${STAGE_RAMP}m`, target: 500 }, //
        // { duration: `${STAGE_RAMP}m`, target: 500 }, //
        // { duration: `${STAGE_RAMP}m`, target: 550 }, //
        // { duration: `${STAGE_RAMP}m`, target: 550 }, //
        // { duration: `${STAGE_RAMP}m`, target: 600 }, //
        // { duration: `${STAGE_RAMP}m`, target: 600 }, //
        // { duration: `${STAGE_RAMP}m`, target: 650 }, //
        // { duration: `${STAGE_RAMP}m`, target: 650 }, //
        // { duration: `${STAGE_RAMP}m`, target: 700 }, //
        // { duration: `${STAGE_RAMP}m`, target: 700 }, //
        // { duration: `${STAGE_RAMP}m`, target: 750 }, //
        // { duration: `${STAGE_RAMP}m`, target: 750 }, //
        // { duration: `${STAGE_RAMP}m`, target: 800 }, //
        // { duration: `${STAGE_RAMP}m`, target: 800 }, //
        // { duration: `${STAGE_RAMP}m`, target: 850 }, //
        // { duration: `${STAGE_RAMP}m`, target: 850 }, //
        // { duration: `${STAGE_RAMP}m`, target: 900 }, //
        // { duration: `${STAGE_RAMP}m`, target: 900 }, //
        // { duration: `${STAGE_RAMP}m`, target: 950 }, //
        // { duration: `${STAGE_RAMP}m`, target: 950 }, //
        // { duration: `${STAGE_PEAK}m`, target: RATE_TARGET }, // hold peak
        // { duration: `1m`, target: 0 }, // cool down
      ],


      gracefulStop: "60s",
      exec: "hp_write_telemetry", // scenario function below
    },
  },
};

// ==============================
// Scenario function
// ==============================
export function hp_write_telemetry() {
  const device = getDeviceForVU();
  postTelemetry({ base_url: BASE_URL, device });
}

export default hp_write_telemetry;

// ==============================
// Summary output
// ==============================
export function handleSummary(data) {
  return {
    "hp_write_test.json": JSON.stringify(data, null, 2),
    "hp_write_test.html": htmlReport(data),
    stdout: textSummary(data, { indent: " ", enableColors: true }),
  };
}
