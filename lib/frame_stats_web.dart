import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/scheduler.dart';

/// Feeds the on-screen frame-rate readout, which only exists when the page is
/// opened with ?fps (see web/fps.js). Otherwise this does nothing.
void reportFrameTimes() {
  if (!globalContext.has('wattlyFrame')) return;
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      globalContext.callMethod<JSAny?>(
        'wattlyFrame'.toJS,
        (t.buildDuration.inMicroseconds / 1000).toJS,
        (t.rasterDuration.inMicroseconds / 1000).toJS,
      );
    }
  });
}
