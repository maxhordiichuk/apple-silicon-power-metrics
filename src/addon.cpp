// addon.cpp - Node.js N-API binding for power metrics
#include <napi.h>
#include "power_metrics.h"

// getPowerMetrics([durationMs]) -> { cpuW, gpuW, aneW, dramW, systemW, totalW }
//
// durationMs: sampling window in milliseconds (default 200, minimum 50).
//   Two IOReport samples are taken this many ms apart; energy delta is
//   divided by the elapsed time to yield average watts.
//
// systemW: power drawn by components not captured by IOReport
//          (PSTR − component sum), or 0 when PSTR ≤ component sum.
// totalW : max(component sum, PSTR).
Napi::Object GetPowerMetrics(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();

  int durationMs = 200;
  if (info.Length() > 0 && info[0].IsNumber()) {
    durationMs = info[0].As<Napi::Number>().Int32Value();
    if (durationMs < 50)
      durationMs = 50;
  }

  PowerMetrics pm = samplePowerMetrics(durationMs);

  double componentSum =
      pm.cpuPower + pm.gpuPower + pm.anePower + pm.dramPower + pm.gpuSramPower;
  double totalW = componentSum;
  double systemW = 0.0;

  if (pm.systemPower > componentSum) {
    totalW = pm.systemPower;
    systemW = pm.systemPower - componentSum;
  }

  Napi::Object result = Napi::Object::New(env);
  result.Set("cpuW", Napi::Number::New(env, pm.cpuPower));
  result.Set("gpuW", Napi::Number::New(env, pm.gpuPower));
  result.Set("aneW", Napi::Number::New(env, pm.anePower));
  result.Set("dramW", Napi::Number::New(env, pm.dramPower));
  result.Set("systemW", Napi::Number::New(env, systemW));
  result.Set("totalW", Napi::Number::New(env, totalW));

  return result;
}

Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports.Set("getPowerMetrics",
              Napi::Function::New(env, GetPowerMetrics));
  return exports;
}

NODE_API_MODULE(apple_silicon_power_metrics, Init)
