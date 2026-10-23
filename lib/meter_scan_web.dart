import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('wattlyScan')
external JSPromise<JSString?> _wattlyScan(JSFunction onPicked);

bool get meterScanSupported => globalContext.has('wattlyScan');

/// Opens the camera and reads the digits off the photo, on this device.
/// Returns the raw recognised text, or null if the student cancelled. Throws
/// if the text reader can't be loaded (e.g. no connection the first time).
Future<String?> scanMeter(void Function() onPicked) async {
  final text = await _wattlyScan(onPicked.toJS).toDart;
  return text?.toDart;
}
