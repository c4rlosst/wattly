/// Reading a meter with the camera needs the browser; elsewhere it isn't offered.
bool get meterScanSupported => false;

Future<String?> scanMeter(void Function() onPicked, {double? last}) async =>
    null;
