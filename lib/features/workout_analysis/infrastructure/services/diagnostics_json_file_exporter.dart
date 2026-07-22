import 'dart:convert';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

Future<void> shareDiagnosticsJsonFile({
  required String json,
  required String fileName,
  Rect? sharePositionOrigin,
}) async {
  await Share.shareXFiles(
    <XFile>[XFile.fromData(utf8.encode(json), mimeType: 'application/json')],
    fileNameOverrides: <String>[fileName],
    sharePositionOrigin: sharePositionOrigin,
  );
}
