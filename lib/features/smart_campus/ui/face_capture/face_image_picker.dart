import 'dart:typed_data';

import 'package:flutter/widgets.dart';

// 使用条件导入：web 走 dart:html / dart:ui_web 实现，桌面 / 移动走 file_picker。
import 'face_image_picker_io.dart'
    if (dart.library.html) 'face_image_picker_web.dart';

/// 一张已经被采集成 JPEG 字节流的人脸照片。`bytes` 始终非空。
class FaceCapturedPhoto {
  const FaceCapturedPhoto({
    required this.bytes,
    required this.name,
    this.mimeType = 'image/jpeg',
  });

  final Uint8List bytes;

  /// 文件名（来自系统选择器或人为生成的 `camera-<ts>.jpg`），方便上传时透传。
  final String name;
  final String mimeType;

  int get sizeBytes => bytes.length;
}

/// 弹出系统文件选择器，让用户从本地选取一张图片（仅图片）。
/// 用户取消或读取失败时返回 `null`。
Future<FaceCapturedPhoto?> pickFacePhotoFromFile() =>
    pickFacePhotoFromFileImpl();

/// 调起摄像头预览并截取一张正脸照片。
///
/// - **Web**：会先 `navigator.mediaDevices.getUserMedia` 申请权限，
///   然后弹出预览对话框，用户按「拍摄」截取当前帧。
/// - **其它平台**：暂未支持，立即返回 `null`，调用方应回退到上传照片。
Future<FaceCapturedPhoto?> captureFacePhotoFromCamera(BuildContext context) =>
    captureFacePhotoFromCameraImpl(context);

/// 当前平台是否支持摄像头采集。Web 返回 true（仍需用户授权），其它平台 false。
bool get isCameraCaptureSupported => isCameraCaptureSupportedImpl;
