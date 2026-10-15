import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final directory =
      Platform.environment['WORTGARTEN_CAPTURE_DIR'] ??
      'output/app-store/raw/iphone';
  await Directory(directory).create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await File('$directory/$name.png').writeAsBytes(bytes);
      return true;
    },
  );
}
