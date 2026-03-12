// power_metrics.h
#ifndef POWER_METRICS_H
#define POWER_METRICS_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  double cpuPower;
  double gpuPower;
  double anePower;
  double dramPower;
  double gpuSramPower;
  double systemPower; // raw PSTR value from SMC (total system watts)
} PowerMetrics;

// Sample power metrics over durationMs milliseconds.
// Initializes IOReport and SMC on first call (lazy).
PowerMetrics samplePowerMetrics(int durationMs);

// Release IOReport and SMC resources.
void cleanupIOReport(void);

#ifdef __cplusplus
}
#endif

#endif
