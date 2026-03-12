import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { getPowerMetrics, type PowerMetrics } from './index.js';

describe('getPowerMetrics', () => {
  it('returns an object with all six fields', () => {
    const m = getPowerMetrics();
    const fields: (keyof PowerMetrics)[] = ['cpuW', 'gpuW', 'aneW', 'dramW', 'systemW', 'totalW'];
    for (const field of fields) {
      assert.ok(field in m, `missing field: ${field}`);
      assert.strictEqual(typeof m[field], 'number', `${field} should be a number`);
      assert.ok(Number.isFinite(m[field]), `${field} should be finite`);
    }
  });

  it('all fields are non-negative', () => {
    const m = getPowerMetrics();
    for (const [key, val] of Object.entries(m)) {
      assert.ok(val >= 0, `${key} should be >= 0, got ${val}`);
    }
  });

  it('totalW equals the sum of all component fields', () => {
    const m = getPowerMetrics();
    const componentSum = m.cpuW + m.gpuW + m.aneW + m.dramW + m.systemW;
    assert.ok(
      Math.abs(m.totalW - componentSum) < 0.01,
      `totalW (${m.totalW}) should equal cpuW+gpuW+aneW+dramW+systemW (${componentSum})`
    );
  });

  it('accepts a custom durationMs', () => {
    const m = getPowerMetrics(100);
    assert.strictEqual(typeof m.totalW, 'number');
    assert.ok(m.totalW >= 0);
  });

  it('clamps durationMs below 50ms without throwing', () => {
    assert.doesNotThrow(() => getPowerMetrics(10));
  });

  it('returns plausible wattage values (< 1000 W)', () => {
    const m = getPowerMetrics();
    for (const [key, val] of Object.entries(m)) {
      assert.ok(val < 1000, `${key} value ${val} W seems implausibly high`);
    }
  });
});
