// test_smoke.js
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.4/index.js";
import { parseNumberEnv, getDeviceForVU } from "./utils.js";
import {
  getHome,
  getHealth,
  getHealthDB,
  getDevices,
  getTelemetryLatest,
  postTelemetry,
} from "./target_url.js";

// ==============================
// Environment parameters
// ==============================

const SOLUTION_ID = __ENV.SOLUTION_ID || "baseline";
const PROFILE = "smoke-testing";
const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";
const VU = parseNumberEnv("VU", 10); // # of devices
const DEVICE_INTERVAL = parseNumberEnv("DEVICE_INTERVAL", 10); // interval of hub request data
const RATE = Math.ceil(VU / DEVICE_INTERVAL); // rate
const DURATION = parseNumberEnv("DURATION", 1); // minute

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
  thresholds: {
    checks: ["rate>0.99"],
    http_reqs: ["count>0"],

    http_req_failed: ["rate<0.01"], // HTTP-level failures
    // http_req_duration: ["p(95)<500"], // Global latency guardrail

    // "http_req_duration{endpoint:home}": ["p(95)<300", "p(99)<500"], // Home latency
    // "http_req_duration{endpoint:telemetry_post}": ["p(95)<800", "p(99)<1300"], // Post latency
  },

  scenarios: {
    smoke_test: {
      executor: "constant-arrival-rate",
      preAllocatedVUs: VU,
      rate: RATE, // iterations per second
      duration: `${DURATION}m`,
      gracefulStop: "10s",
      exec: "smoke_test",
    },
  },
};

// ==============================
// Scenario function
// ==============================
export function smoke_test() {
  // init device
  const device = getDeviceForVU();

  // Basic platform checks
  getHome({ base_url: BASE_URL });
  getHealth({ base_url: BASE_URL });
  // getHealthDB({ base_url: BASE_URL });
  // getDevices({ base_url: BASE_URL });

  // telemetry
  getTelemetryLatest({ base_url: BASE_URL, device });
  postTelemetry({ base_url: BASE_URL, device });
}

export default smoke_test;

// ==============================
// Summary output
// ==============================
export function handleSummary(data) {
  return {
    "summary_smoke.json": JSON.stringify(data, null, 2),
    stdout: textSummary(data, { indent: " ", enableColors: true }),
  };
}
