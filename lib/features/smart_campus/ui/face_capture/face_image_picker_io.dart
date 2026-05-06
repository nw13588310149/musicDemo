// 桌面 / 移动平台兜底实现：上传照片走 file_picker，摄像头采集暂不支持。

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

import 'face_image_picker.dart';

bool get isCameraCaptureSupportedImpl => false;

Future<FaceCapturedPhoto?> pickFacePhotoFromFileImpl() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final f = result.files.first;
  Uint8List? bytes = f.bytes;
  if ((bytes == null || bytes.isEmpty) && f.path != null) {
    try {
      bytes = await File(f.path!).readAsBytes();
    } catch (_) {
      return null;
    }
  }
  if (bytes == null || bytes.isEmpty) return null;
  return FaceCapturedPhoto(
    bytes: bytes,
    name: f.name,
    mimeType: _guessMime(f.name),
  );
}

Future<FaceCapturedPhoto?> captureFacePhotoFromCameraImpl(
  BuildContext context,
) async {
  // 当前平台暂未接入相机；调用方会基于返回 null 引导用户用上传照片。
  return null;
}

String _guessMime(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.bmp')) return 'image/bmp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}
