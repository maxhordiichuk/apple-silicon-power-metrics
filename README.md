# apple-silicon-power-metrics

A native Node.js addon that reads real-time power consumption metrics on Apple Silicon Macs (M-series chips). Uses Apple's private IOReport framework and System Management Controller (SMC) to sample CPU, GPU, Neural Engine, and DRAM power draw.

## Requirements

- Apple Silicon Mac (M1, M2, M3, or later)
- macOS 12.0 or later
- Node.js 18+

## Installation

```bash
npm install apple-silicon-power-metrics
```

No build step required — a prebuilt binary for `darwin-arm64` is included in the package.

## Usage

```typescript
import { getPowerMetrics } from 'apple-silicon-power-metrics';

const metrics = getPowerMetrics(200); // sample over 200ms
console.log(metrics);
// {
//   cpuW: 3.21,
//   gpuW: 0.87,
//   aneW: 0.0,
//   dramW: 0.54,
//   systemW: 1.12,
//   totalW: 5.74
// }
```

## API

### `getPowerMetrics(durationMs?: number): PowerMetrics`

Takes two IOReport snapshots separated by `durationMs` milliseconds, computes the energy delta for each component, and returns power in watts.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `durationMs` | `number` | `200` | Sampling window in milliseconds. Minimum: 50ms. |

### `PowerMetrics`

| Field | Unit | Description |
|-------|------|-------------|
| `cpuW` | W | CPU package power |
| `gpuW` | W | GPU power |
| `aneW` | W | Apple Neural Engine power |
| `dramW` | W | DRAM power |
| `systemW` | W | Residual system power (total minus component sum), or 0 |
| `totalW` | W | `max(componentSum, SMC PSTR)` |

`totalW` is the greater of the sum of component readings and the board-level total reported by the SMC PSTR key. `systemW` captures any remaining power not attributed to a named component.

## How It Works

1. Opens subscriptions to IOReport channels (`Energy Model`, `GPU Stats`, `CPU Stats`) and reads the SMC `PSTR` key via IOKit.
2. Waits `durationMs` milliseconds.
3. Takes a second snapshot and computes the energy delta for each channel.
4. Converts energy (reported in µJ, mJ, or nJ depending on the channel) to watts: `watts = Δenergy / Δtime`.
5. Returns the six-field `PowerMetrics` object.

IOReport and SMC connections are initialized lazily on first call and reused for subsequent calls.

## Build Scripts

| Script | Description |
|--------|-------------|
| `npm run build` | Build native addon and compile TypeScript |
| `npm run build:native` | Rebuild native addon only (node-gyp) |
| `npm run build:ts` | Compile TypeScript only |
| `npm run prebuild` | Compile prebuilt binary into `prebuilds/` for publishing |

## Notes

- This library uses Apple's **private IOReport API**, which is not documented and may change across macOS releases.
- The native module is compiled for **ARM64 only** and will not run on Intel Macs.
- Accuracy improves with longer sampling windows. Values below 50ms are clamped to 50ms.
