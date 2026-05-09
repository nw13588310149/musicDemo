import 'dart:typed_data';

Future<Uint8List> readRecordedBytes(String source) async {
  throw UnsupportedError(
    'Recording is not supported on Flutter Web. Please use the iPad or mobile app.',
  );
}

String createTemporaryRecordingPath() => 'recording.m4a';
