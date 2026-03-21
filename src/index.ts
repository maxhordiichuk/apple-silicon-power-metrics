import path = require('path');

const addon = require('node-gyp-build')(path.join(__dirname, '..')) as {
  getPowerMetrics(durationMs: number): PowerMetrics;
};

export interface PowerMetrics {
  /** CPU package power in watts */
  cpuW: number;
  /** GPU power in watts */
  gpuW: number;
  /** Apple Neural Engine power in watts */
  aneW: number;
  /** DRAM power in watts */
  dramW: number;
  /** Residual system power not attributed to components (SMC PSTR − component sum), in watts */
  systemW: number;
  /** Total SoC power: max(componentSum, SMC PSTR) in watts */
  totalW: number;
}

/**
 * Sample power metrics from Apple's IOReport/IOKit framework.
 *
 * Two IOReport snapshots are taken `durationMs` milliseconds apart; the
 * energy delta is divided by the elapsed time to yield average watts.
 * SMC key `PSTR` is read for total board power.
 *
 * IOReport and SMC connections are initialized lazily on the first call
 * and reused on subsequent calls.
 *
 * @param durationMs - Sampling window in milliseconds (default 200, minimum 50).
 */
export function getPowerMetrics(durationMs = 200): PowerMetrics {
  return addon.getPowerMetrics(durationMs);
}
