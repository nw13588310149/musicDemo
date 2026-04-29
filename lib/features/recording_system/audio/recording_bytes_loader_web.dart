// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List> readRecordedBytes(String source) async {
  final request = await html.HttpRequest.request(
    source,
    method: 'GET',
    responseType: 'arraybuffer',
  );
  final response = request.response;
  if (response is ByteBuffer) {
    return Uint8List.view(response);
  }
  if (response is Uint8List) {
    return response;
  }
  return Uint8List(0);
}

String createTemporaryRecordingPath() => 'recording.wav';
