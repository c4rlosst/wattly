/// Reading a meter from a photo needs the browser; elsewhere it isn't offered.
bool get meterScanSupported => false;

Future<String?> scanMeter(void Function() onPicked) async => null;
