// test_hp_mixed.js
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.4/index.js";
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js";
import { parseNumberEnv, parseBoolEnv, getDeviceForVU } from "./utils.js";
import { getTelemetryLatest, postTelemetry } from "./target_url.js";

// ==============================
// Environment
// ==============================
const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";

// Tag to distinguish solution variants
const SOLUTION_ID = __ENV.SOLUTION_ID || "baseline";
const PROFILE = "mixed"; // Mixed profile
const ABORT_ON_FAIL = parseBoolEnv("ABORT_ON_FAIL", false);

// read-write ratio: read/write
const RATIO = __ENV.RATIO || 1;

// -------- Read (GET) parameters --------
const RATE_READ_START = parseNumberEnv("RATE_READ_START", 50); // initial write RPS
const RATE_READ_TARGET = parseNumberEnv("RATE_READ_TARGET", 500); // peak write RPS

// -------- Write (POST) parameters --------
const RATE_WRITE_START = RATE_READ_START * RATIO; // initial write RPS
const RATE_WRITE_TARGET = RATE_READ_TARGET * RATIO; // peak write RPS

// -------- Stage --------
const STAGE_START = parseNumberEnv("STAGE_START", 1); // minutes per ramp stage
const STAGE_RAMP = parseNumberEnv("STAGE_RAMP", 20); // minutes per ramp stage
const STAGE_PEAK = parseNumberEnv("STAGE_PEAK", 5); // minutes to hold peak

// -------- VU --------
const W_VU = parseNumberEnv("W_VU", 20); // pre-allocated VUs for write
const W_MAX_VU = parseNumberEnv("W_MAX_VU", 300); // max VUs for write scenario

const R_VU = parseNumberEnv("R_VU", 20); // pre-allocated VUs for read
const R_MAX_VU = parseNumberEnv("R_MAX_VU", 300); // max VUs for read scenario

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

  // SLO:
  // "rate<0.01": Less than 1% of requests return an error.
  // "p(99)<300": 99% of requests have a response time below 300ms.
  // "p(90)<1000": 90% of requests have a response time below 1000ms.

  // Global tags applied to all metrics
  tags: {
    solution: SOLUTION_ID,
    profile: PROFILE,
  },

  thresholds: {
    // Overall failure rates
    "http_req_failed{scenario:hp_write_telemetry}": [
      {
        threshold: "rate<0.01", // Failure rate < 1%
        abortOnFail: ABORT_ON_FAIL,
        delayAbortEval: "10s",
      },
    ],
    "http_req_failed{scenario:hp_read_telemetry}": [
      {
        threshold: "rate<0.01", // Failure rate < 1%
        abortOnFail: ABORT_ON_FAIL,
        delayAbortEval: "10s",
      },
    ],
    // Write performance (POST /telemetry)
    "http_req_duration{scenario:hp_write_telemetry,endpoint:telemetry_post}": [
      {
        threshold: "p(95)<300", // 95% of requests < 300ms
        abortOnFail: ABORT_ON_FAIL, // abort when 1st failure
        delayAbortEval: "10s",
      },
      { threshold: "p(90)<1000" },
    ],

    // Read performance (GET /telemetry/latest)
    "http_req_duration{scenario:hp_read_telemetry,endpoint:telemetry_get_latest}":
      [
        {
          threshold: "p(95)<300", // 95% of requests < 300ms
          abortOnFail: ABORT_ON_FAIL, // abort when 1st failure
          delayAbortEval: "10s",
        },
        { threshold: "p(90)<1000" },
      ],
  },

  scenarios: {
    // ==========================
    // Read (GET)
    // ==========================
    hp_read_telemetry: {
      executor: "ramping-arrival-rate",
      startRate: 0,
      timeUnit: "1s",

      preAllocatedVUs: R_VU,
      maxVUs: R_MAX_VU,

      stages: [
        { duration: `${STAGE_START}m`, target: RATE_READ_START },
        { duration: `${STAGE_RAMP}m`, target: RATE_READ_TARGET },
        { duration: `${STAGE_PEAK}m`, target: RATE_READ_TARGET },
        { duration: `1m`, target: 0 },
      ],

      gracefulStop: "60s",
      exec: "hp_read_telemetry",
      tags: {
        role: "read",
      },
    },

    // ==========================
    // Write (POST)
    // ==========================
    hp_write_telemetry: {
      executor: "ramping-arrival-rate",
      startRate: 0,
      timeUnit: "1s",

      preAllocatedVUs: W_VU,
      maxVUs: W_MAX_VU,

      stages: [
        { duration: `${STAGE_START}m`, target: RATE_WRITE_START },
        { duration: `${STAGE_RAMP}m`, target: RATE_WRITE_TARGET },
        { duration: `${STAGE_PEAK}m`, target: RATE_WRITE_TARGET },
        { duration: `1m`, target: 0 },
      ],

      gracefulStop: "60s",
      exec: "hp_write_telemetry",
      tags: {
        role: "write",
      },
    },
  },
};

// ==============================
// Scenario functions
// ==============================
export function hp_write_telemetry() {
  const device = getDeviceForVU();
  postTelemetry({ base_url: BASE_URL, device });
}

export function hp_read_telemetry() {
  const device = getDeviceForVU();
  getTelemetryLatest({ base_url: BASE_URL, device });
}

export default hp_write_telemetry;

// ==============================
// Summary output
// ==============================
export function handleSummary(data) {
  return {
    "hp_mixed_test.json": JSON.stringify(data, null, 2),
    "hp_mixed_test.html": htmlReport(data),
    stdout: textSummary(data, { indent: " ", enableColors: true }),
  };
}
