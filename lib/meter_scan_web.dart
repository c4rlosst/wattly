import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('wattlyScan')
external JSPromise<JSString?> _wattlyScan(JSNumber? last, JSFunction onPicked);

bool get meterScanSupported => globalContext.has('wattlyScan');

/// Opens a live camera view that finds and reads the meter digits, on this
/// device. [last] is the previous reading, which helps pick the right number.
/// Returns the recognised text, or null if the student cancelled. Throws if
/// the text reader can't be loaded (e.g. no connection the first time).
Future<String?> scanMeter(void Function() onPicked, {double? last}) async {
  final text = await _wattlyScan(last?.toJS, onPicked.toJS).toDart;
  return text?.toDart;
}
