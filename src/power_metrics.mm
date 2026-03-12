// power_metrics.mm - IOReport/IOKit power metrics for Apple Silicon
// Adapted from mactop (https://github.com/metaspartan/mactop), MIT License

#include "power_metrics.h"
#include "smc.h"

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

#include <stdint.h>
#include <string.h>
#include <unistd.h>

// ---------------------------------------------------------------------------
// IOReport private API declarations (C linkage)
// ---------------------------------------------------------------------------

typedef void *IOReportSubscriptionRef_t;

extern "C" {
CFDictionaryRef IOReportCopyChannelsInGroup(CFStringRef group,
                                            CFStringRef subgroup,
                                            uint64_t a, uint64_t b,
                                            uint64_t c);
void IOReportMergeChannels(CFDictionaryRef a, CFDictionaryRef b,
                           CFTypeRef unused);
IOReportSubscriptionRef_t
IOReportCreateSubscription(void *a, CFMutableDictionaryRef channels,
                           CFMutableDictionaryRef *out, uint64_t d,
                           CFTypeRef e);
CFDictionaryRef IOReportCreateSamples(IOReportSubscriptionRef_t sub,
                                      CFMutableDictionaryRef channels,
                                      CFTypeRef unused);
CFDictionaryRef IOReportCreateSamplesDelta(CFDictionaryRef a, CFDictionaryRef b,
                                           CFTypeRef unused);
int64_t IOReportSimpleGetIntegerValue(CFDictionaryRef item, int32_t idx);
CFStringRef IOReportChannelGetGroup(CFDictionaryRef item);
CFStringRef IOReportChannelGetChannelName(CFDictionaryRef item);
CFStringRef IOReportChannelGetUnitLabel(CFDictionaryRef item);
} // extern "C"

// ---------------------------------------------------------------------------
// Global state
// ---------------------------------------------------------------------------

static IOReportSubscriptionRef_t g_subscription = NULL;
static CFMutableDictionaryRef g_channels = NULL;
static io_connect_t g_smcConn = 0;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static int cfStringMatch(CFStringRef str, const char *match) {
  if (str == NULL || match == NULL)
    return 0;
  CFStringRef matchStr = CFStringCreateWithCString(kCFAllocatorDefault, match,
                                                   kCFStringEncodingUTF8);
  if (matchStr == NULL)
    return 0;
  int result = (CFStringCompare(str, matchStr, 0) == kCFCompareEqualTo);
  CFRelease(matchStr);
  return result;
}

static int cfStringContains(CFStringRef str, const char *substr) {
  if (str == NULL || substr == NULL)
    return 0;
  CFStringRef substrRef = CFStringCreateWithCString(kCFAllocatorDefault, substr,
                                                    kCFStringEncodingUTF8);
  if (substrRef == NULL)
    return 0;
  CFRange result = CFStringFind(str, substrRef, 0);
  CFRelease(substrRef);
  return (result.location != kCFNotFound);
}

static int cfStringStartsWith(CFStringRef str, const char *prefix) {
  if (str == NULL || prefix == NULL)
    return 0;
  CFStringRef prefixRef = CFStringCreateWithCString(kCFAllocatorDefault, prefix,
                                                    kCFStringEncodingUTF8);
  if (prefixRef == NULL)
    return 0;
  int result = CFStringHasPrefix(str, prefixRef);
  CFRelease(prefixRef);
  return result;
}

// Convert an accumulated energy delta to average watts over durationMs.
static double energyToWatts(int64_t energy, CFStringRef unitRef,
                            double durationMs) {
  if (durationMs <= 0)
    durationMs = 1;
  double rate = (double)energy / (durationMs / 1000.0);

  if (unitRef == NULL)
    return rate / 1e6; // default: assume uJ

  char unit[32] = {0};
  CFStringGetCString(unitRef, unit, sizeof(unit), kCFStringEncodingUTF8);

  // Strip trailing spaces
  for (int i = 0; unit[i]; i++) {
    if (unit[i] == ' ') {
      unit[i] = '\0';
      break;
    }
  }

  if (strcmp(unit, "mJ") == 0)
    return rate / 1e3;
  if (strcmp(unit, "uJ") == 0)
    return rate / 1e6;
  if (strcmp(unit, "nJ") == 0)
    return rate / 1e9;

  return rate / 1e6; // fallback
}

// ---------------------------------------------------------------------------
// Initialisation
// ---------------------------------------------------------------------------

static int initIOReport() {
  if (g_channels != NULL)
    return 0;

  CFDictionaryRef energyChan =
      IOReportCopyChannelsInGroup(CFSTR("Energy Model"), NULL, 0, 0, 0);
  if (energyChan == NULL)
    return -1;

  CFDictionaryRef gpuChan =
      IOReportCopyChannelsInGroup(CFSTR("GPU Stats"), NULL, 0, 0, 0);
  if (gpuChan != NULL) {
    IOReportMergeChannels(energyChan, gpuChan, NULL);
    CFRelease(gpuChan);
  }

  CFDictionaryRef cpuChan =
      IOReportCopyChannelsInGroup(CFSTR("CPU Stats"), NULL, 0, 0, 0);
  if (cpuChan != NULL) {
    IOReportMergeChannels(energyChan, cpuChan, NULL);
    CFRelease(cpuChan);
  }

  CFIndex size = CFDictionaryGetCount(energyChan);
  g_channels =
      CFDictionaryCreateMutableCopy(kCFAllocatorDefault, size, energyChan);
  CFRelease(energyChan);

  if (g_channels == NULL)
    return -2;

  CFMutableDictionaryRef subsystem = NULL;
  g_subscription =
      IOReportCreateSubscription(NULL, g_channels, &subsystem, 0, NULL);

  if (g_subscription == NULL) {
    CFRelease(g_channels);
    g_channels = NULL;
    return -3;
  }

  g_smcConn = SMCOpen();

  return 0;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

PowerMetrics samplePowerMetrics(int durationMs) {
  PowerMetrics metrics = {0, 0, 0, 0, 0, 0};

  @autoreleasepool {
    if (g_subscription == NULL || g_channels == NULL) {
      if (initIOReport() != 0)
        return metrics;
    }

    CFDictionaryRef sample1 =
        IOReportCreateSamples(g_subscription, g_channels, NULL);
    if (sample1 == NULL)
      return metrics;

    usleep(durationMs * 1000);

    CFDictionaryRef sample2 =
        IOReportCreateSamples(g_subscription, g_channels, NULL);
    if (sample2 == NULL) {
      CFRelease(sample1);
      return metrics;
    }

    CFDictionaryRef delta = IOReportCreateSamplesDelta(sample1, sample2, NULL);
    CFRelease(sample1);
    CFRelease(sample2);

    if (delta == NULL)
      return metrics;

    CFArrayRef channels =
        (CFArrayRef)CFDictionaryGetValue(delta, CFSTR("IOReportChannels"));
    if (channels == NULL) {
      CFRelease(delta);
      return metrics;
    }

    CFIndex count = CFArrayGetCount(channels);
    for (CFIndex i = 0; i < count; i++) {
      CFDictionaryRef item =
          (CFDictionaryRef)CFArrayGetValueAtIndex(channels, i);
      if (item == NULL)
        continue;

      CFStringRef groupRef = IOReportChannelGetGroup(item);
      CFStringRef channelRef = IOReportChannelGetChannelName(item);

      if (groupRef == NULL || channelRef == NULL)
        continue;

      if (cfStringMatch(groupRef, "Energy Model")) {
        CFStringRef unitRef = IOReportChannelGetUnitLabel(item);
        int64_t val = IOReportSimpleGetIntegerValue(item, 0);
        double watts = energyToWatts(val, unitRef, (double)durationMs);

        if (cfStringContains(channelRef, "CPU Energy")) {
          metrics.cpuPower += watts;
        } else if (cfStringMatch(channelRef, "GPU Energy")) {
          metrics.gpuPower += watts;
        } else if (cfStringStartsWith(channelRef, "ANE")) {
          metrics.anePower += watts;
        } else if (cfStringStartsWith(channelRef, "DRAM")) {
          metrics.dramPower += watts;
        } else if (cfStringStartsWith(channelRef, "GPU SRAM")) {
          metrics.gpuSramPower += watts;
        }
      }
    }

    CFRelease(delta);

    // Read total system power from SMC key "PSTR"
    if (g_smcConn) {
      metrics.systemPower = SMCGetFloatValue(g_smcConn, "PSTR");
    }
  }

  return metrics;
}

void cleanupIOReport(void) {
  if (g_channels != NULL) {
    CFRelease(g_channels);
    g_channels = NULL;
  }
  g_subscription = NULL;
  if (g_smcConn) {
    SMCClose(g_smcConn);
    g_smcConn = 0;
  }
}
