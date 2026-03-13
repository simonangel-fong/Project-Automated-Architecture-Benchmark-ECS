// utils.js
import http from "k6/http";
import { check } from "k6";
import { SharedArray } from "k6/data";

// ============================================
// Function for GET an endpoint
// ============================================
export function checkGet({
  url,
  endpoint = "",
  headers = {},
  expectedStatuses = [200],
}) {
  const res = http.get(url, {
    headers,
    tags: { endpoint },
  });

  // Base status check
  const checks = {
    [`${endpoint} ok`]: (r) => expectedStatuses.includes(r.status),
  };
  const ok = check(res, checks);
  return { res, ok };
}

// ============================================
// Function for POST an endpoint
// ============================================
export function checkPost({
  url,
  endpoint = "",
  headers = {},
  body = null,
  expectedStatuses = [201],
}) {
  const res = http.post(url, body, {
    headers,
    body,
    tags: { endpoint },
  });

  // Base status check
  const checks = {
    [`${endpoint} ok`]: (r) => expectedStatuses.includes(r.status),
  };
  const ok = check(res, checks);
  return { res, ok };
}

// ============================================
// Algorithm to simulate movement
// ============================================
export function buildTelemetryPayload({ xMax = 10, yMax = 10 } = {}) {
  return JSON.stringify({
    x_coord: Math.random() * xMax,
    y_coord: Math.random() * yMax,
    device_time: new Date().toISOString(),
  });
}

// ============================================
// Function helps parse Boolean ENV var
// ============================================
export function parseBoolEnv(name, defaultValue) {
  const raw = __ENV[name];

  if (raw === undefined) return defaultValue;

  const normalized = String(raw).toLowerCase().trim();

  if (["true", "1", "yes", "y"].includes(normalized)) return true;
  if (["false", "0", "no", "n"].includes(normalized)) return false;

  return defaultValue;
}

// ============================================
// Function helps parse Number ENV var
// ============================================
export function parseNumberEnv(name, defaultValue) {
  const raw = __ENV[name];
  if (raw === undefined) return defaultValue;
  const n = Number(raw);
  return Number.isNaN(n) ? defaultValue : n;
}

// ============================================
// Generic JSON array loader with SharedArray
// ============================================
/**
 * Load a JSON array from a file into a SharedArray.
 *
 * @param {string} name - Logical name for the SharedArray (for k6).
 * @param {string} path - Path to the JSON file (relative to script).
 * @returns {Array<any>} - The loaded array, shared across VUs.
 */
export function loadJsonArray(name, path) {
  return new SharedArray(name, () => {
    const raw = open(path);
    const parsed = JSON.parse(raw);

    if (!Array.isArray(parsed)) {
      throw new Error(`Expected JSON array in ${path}, got: ${typeof parsed}`);
    }

    return parsed;
  });
}

// Default device pool using cred.json
export const DEVICES = loadJsonArray("devices", "./cred.json");

// ============================================
// Map each VU to one item from a pool (1:1)
// ============================================
/**
 * Map the current VU to one entry from a given pool.
 *
 * @param {Array<any>} pool - Array of items (e.g., devices).
 * @returns {any} - Item assigned to this VU.
 */
export function getItemForVU(pool) {
  if (!pool.length) {
    throw new Error("getItemForVU called with empty pool");
  }
  // __VU is 1-based index in k6
  const idx = (__VU - 1) % pool.length;
  return pool[idx];
}

/**
 * Convenience wrapper: get device for current VU
 * from the default DEVICES pool.
 */
export function getDeviceForVU() {
  return getItemForVU(DEVICES);
}
