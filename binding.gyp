{
  "targets": [{
    "target_name": "apple_silicon_power_metrics",
    "sources": [
      "src/addon.cpp",
      "src/power_metrics.mm",
      "src/smc.c"
    ],
    "include_dirs": [
      "<!@(node -p \"require('node-addon-api').include\")",
      "src"
    ],
    "defines": ["NAPI_DISABLE_CPP_EXCEPTIONS"],
    "xcode_settings": {
      "MACOSX_DEPLOYMENT_TARGET": "12.0",
      "CLANG_ENABLE_OBJC_ARC": "NO"
    },
    "link_settings": {
      "libraries": [
        "-framework CoreFoundation",
        "-framework IOKit",
        "-framework Foundation",
        "-lIOReport"
      ]
    }
  }]
}
