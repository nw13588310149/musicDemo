import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/scaled_dialog.dart';
import '../../../shell/ui/shell_layout.dart';
import 'face_id_frame_overlay.dart';
import 'face_id_photo_crop.dart';
import 'face_id_photo_spec.dart';
import 'face_image_picker.dart';

/// 证件照裁切页：相册选图 / 相机原图均经此页调整并输出标准尺寸。
class FaceIdPhotoCropPage extends StatefulWidget {
  const FaceIdPhotoCropPage({
    required this.sourceBytes,
    required this.sourceName,
    this.title = '调整证件照',
    this.hint = '拖动或双指缩放图片，将面部对准框内后点击确认',
    super.key,
  });

  final Uint8List sourceBytes;
  final String sourceName;
  final String title;
  final String hint;

  @override
  State<FaceIdPhotoCropPage> createState() => _FaceIdPhotoCropPageState();
}

class _FaceIdPhotoCropPageState extends State<FaceIdPhotoCropPage> {
  final TransformationController _transform = TransformationController();
  late final Size _imageSize;
  late final bool _decodeFailed;
  Size _viewportSize = Size.zero;
  Rect _frameRect = Rect.zero;
  bool _busy = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final decoded = img.decodeImage(widget.sourceBytes);
    if (decoded == null) {
      _decodeFailed = true;
      _imageSize = Size.zero;
      return;
    }
    _decodeFailed = false;
    final oriented = img.bakeOrientation(decoded);
    _imageSize = Size(oriented.width.toDouble(), oriented.height.toDouble());
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _applyCoverTransform(Size viewport) {
    _transform.value = faceIdPhotoCoverTransform(
      imageSize: _imageSize,
      viewportSize: viewport,
    );
    _ready = true;
  }

  void _onViewportLayout(Size size) {
    if (size == _viewportSize) return;
    _viewportSize = size;
    _frameRect = FaceIdPhotoSpec.frameRectInPreview(size);
    if (!_ready && !_decodeFailed) {
      _applyCoverTransform(size);
    }
  }

  Future<void> _confirm() async {
    if (_busy || _frameRect == Rect.zero || _viewportSize == Size.zero) return;
    setState(() => _busy = true);
    try {
      final cropped = cropFaceIdPhotoFromViewport(
        sourceBytes: widget.sourceBytes,
        frameInViewport: _frameRect,
        imageToViewport: _transform.value,
      );
      if (!mounted) return;
      if (cropped == null || cropped.isEmpty) {
        AppToast.show(context, '裁切失败，请重试');
        setState(() => _busy = false);
        return;
      }
      final ext = _outputExtension(widget.sourceName);
      final name =
          'face-${DateTime.now().millisecondsSinceEpoch}$ext';
      Navigator.of(context).pop(
        FaceCapturedPhoto(bytes: cropped, name: name, mimeType: 'image/jpeg'),
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, '裁切失败：$e');
      setState(() => _busy = false);
    }
  }

  static String _outputExtension(String sourceName) {
    final dot = sourceName.lastIndexOf('.');
    if (dot >= 0) return sourceName.substring(dot);
    return '.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final decodeFailed = _decodeFailed;

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
                      widget.title,
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
                widget.hint,
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
                  child: decodeFailed
                      ? const Center(
                          child: Text(
                            '无法读取图片，请换一张重试',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final size = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            _onViewportLayout(size);
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                InteractiveViewer(
                                  transformationController: _transform,
                                  minScale: 0.4,
                                  maxScale: 6,
                                  boundaryMargin: const EdgeInsets.all(240),
                                  child: SizedBox(
                                    width: _imageSize.width,
                                    height: _imageSize.height,
                                    child: Image.memory(
                                      widget.sourceBytes,
                                      fit: BoxFit.fill,
                                      filterQuality: FilterQuality.high,
                                    ),
                                  ),
                                ),
                                IgnorePointer(
                                  child: CustomPaint(
                                    painter: FaceIdFramePainter(
                                      frameRect: _frameRect,
                                      previewSize: size,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ),
            ),
            SizedBox(height: ui(16)),
            Padding(
              padding: EdgeInsets.fromLTRB(ui(24), 0, ui(24), ui(20)),
              child: AppDialogActionBar(
                cancelLabel: '取消',
                confirmLabel: _busy ? '处理中…' : '确认裁切',
                confirmEnabled: !_busy && !decodeFailed,
                onCancel: _busy ? () {} : () => Navigator.of(context).pop(),
                onConfirm: _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
