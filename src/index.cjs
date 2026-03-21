'use strict';

const addon = require('node-gyp-build')(__dirname);

exports.getPowerMetrics = function (durationMs = 200) {
  return addon.getPowerMetrics(durationMs);
};