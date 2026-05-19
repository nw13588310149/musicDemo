import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/scaled_dialog.dart';
import '../../../shell/ui/shell_layout.dart';
import 'face_id_frame_overlay.dart';
import 'face_id_photo_flow.dart';
import 'face_id_photo_spec.dart';

/// 证件照取景相机：全屏预览 + 标准一寸框，拍摄后进入裁切页输出标准尺寸。
class FaceIdCameraPage extends StatefulWidget {
  const FaceIdCameraPage({super.key});

  @override
  State<FaceIdCameraPage> createState() => _FaceIdCameraPageState();
}

class _FaceIdCameraPageState extends State<FaceIdCameraPage> {
  CameraController? _controller;
  String? _initError;
  bool _busy = false;
  Size _previewLayoutSize = Size.zero;
  Rect _frameRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _initError = '未检测到可用摄像头');
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (Platform.isIOS) {
        await controller.lockCaptureOrientation(DeviceOrientation.landscapeLeft);
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _initError = '无法打开摄像头：$e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onPreviewLayout(Size size) {
    if (size == _previewLayoutSize) return;
    _previewLayoutSize = size;
    _frameRect = FaceIdPhotoSpec.frameRectInPreview(size);
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) {
      return;
    }

    setState(() => _busy = true);
    try {
      final file = await controller.takePicture();
      final raw = await File(file.path).readAsBytes();
      try {
        await File(file.path).delete();
      } catch (_) {}

      if (!mounted) return;
      final cropped = await openFaceIdPhotoCropFlow(
        context,
        sourceBytes: raw,
        sourceName: 'camera.jpg',
        title: '确认证件照',
        hint: '可拖动或缩放微调，将面部对准框内后确认',
      );
      if (!mounted) return;
      if (cropped != null) {
        Navigator.of(context).pop(cropped);
      } else {
        setState(() => _busy = false);
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, '拍摄失败：$e');
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(8)),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: Colors.white, size: ui(24)),
                  ),
                  Expanded(
                    child: Text(
                      '拍摄证件照',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ui(17),
                        color: Colors.white,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(48)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(24)),
              child: Text(
                '请将面部置于框内，保持正面免冠、光线均匀，露出额头与双耳',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui(13),
                  color: Colors.white70,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(height: ui(12)),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: ui(20)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ui(12)),
                  child: _initError != null
                      ? _ErrorPane(message: _initError!)
                      : _controller?.value.isInitialized == true
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            final size = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            _onPreviewLayout(size);
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                _CoverCameraPreview(controller: _controller!),
                                CustomPaint(
                                  painter: FaceIdFramePainter(
                                    frameRect: _frameRect,
                                    previewSize: size,
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                ),
              ),
            ),
            SizedBox(height: ui(16)),
            Padding(
              padding: EdgeInsets.fromLTRB(ui(24), 0, ui(24), ui(20)),
              child: AppDialogActionBar(
                cancelLabel: '取消',
                confirmLabel: _busy ? '处理中…' : '拍摄',
                confirmEnabled: !_busy,
                onCancel: _busy ? () {} : () => Navigator.of(context).pop(),
                onConfirm: _capture,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 与裁切算法一致的 [BoxFit.cover] 相机预览。
class _CoverCameraPreview extends StatelessWidget {
  const _CoverCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = controller.value.previewSize;
        if (previewSize == null) {
          return CameraPreview(controller);
        }
        var camW = previewSize.width;
        var camH = previewSize.height;
        final viewW = constraints.maxWidth;
        final viewH = constraints.maxHeight;
        final viewAspect = viewW / viewH;
        final camAspect = camW / camH;
        if (camAspect > viewAspect) {
          camH = viewH;
          camW = camH * camAspect;
        } else {
          camW = viewW;
          camH = camW / camAspect;
        }
        return ClipRect(
          child: OverflowBox(
            maxWidth: camW,
            maxHeight: camH,
            alignment: Alignment.center,
            child: SizedBox(
              width: camW,
              height: camH,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
    );
  }
}
