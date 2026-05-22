import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'midi_file_picker.dart';

const int kMaxLocalMidiBytes = 8 * 1024 * 1024;

Future<PickedMidiFile?> pickLocalMidiFileImpl() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['mid', 'midi'],
    allowMultiple: false,
    withData: true,
  );
  final files = result?.files ?? const <PlatformFile>[];
  if (files.isEmpty) return null;

  final file = files.first;
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) return null;
  if (bytes.length > kMaxLocalMidiBytes) {
    throw StateError('本地 MIDI 过大，请使用 8MB 以内的文件。');
  }

  final name = file.name.trim().isEmpty ? 'local.mid' : file.name.trim();
  return PickedMidiFile(
    name: name,
    bytes: Uint8List.fromList(bytes),
  );
}
