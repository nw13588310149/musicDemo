import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// 全屏图片查看器：半透明黑底 + PhotoViewGallery，支持
/// 双击 / 捏合缩放、左右滑切换、Hero 转场。
///
/// 使用方法：
/// ```dart
/// showImageGallery(
///   context,
///   images: ['https://...', 'https://...'],
///   initialIndex: 0,
///   heroTagPrefix: 'theory_assignment',
/// );
/// ```
Future<void> showImageGallery(
  BuildContext context, {
  required List<String> images,
  int initialIndex = 0,
  String heroTagPrefix = 'image_gallery',
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) =>
          ImageGalleryViewer(
            images: images,
            initialIndex: initialIndex,
            heroTagPrefix: heroTagPrefix,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// 与 [showImageGallery] 配合使用的全屏图片查看器组件。也可以单独使用。
class ImageGalleryViewer extends StatefulWidget {
  const ImageGalleryViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.heroTagPrefix = 'image_gallery',
  });

  final List<String> images;
  final int initialIndex;
  final String heroTagPrefix;

  @override
  State<ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<ImageGalleryViewer> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.of(context).padding;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          GestureBinding.instance.pointerSignalResolver.register(event, (_) {});
        }
      },
      child: Material(
        color: Colors.black87,
        child: SizedBox.expand(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ScrollConfiguration(
                  behavior: const MaterialScrollBehavior().copyWith(
                    dragDevices: <PointerDeviceKind>{
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: PhotoViewGallery.builder(
                    pageController: _controller,
                    itemCount: widget.images.length,
                    scrollPhysics: const BouncingScrollPhysics(),
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    loadingBuilder: (context, progress) {
                      if (progress == null) {
                        return const SizedBox.shrink();
                      }
                      return const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    builder: (context, index) {
                      final image = widget.images[index];
                      // 交给 PhotoView 用图片真实像素尺寸计算 contained 缩放，
                      // 保证宽或高一侧贴满视口、另一侧留白，且绝不拉伸。
                      // ResizeImage 只限制较长边，避免同时设 cacheWidth+cacheHeight
                      // 在 iOS 上把解码结果压成视口比例导致变形。
                      return PhotoViewGalleryPageOptions(
                        imageProvider: _galleryImageProvider(context, image),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 4,
                        initialScale: PhotoViewComputedScale.contained,
                        filterQuality: FilterQuality.medium,
                        heroAttributes: PhotoViewHeroAttributes(
                          tag: '${widget.heroTagPrefix}_${image}_$index',
                        ),
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: mediaPadding.top + 12,
                right: 16,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              if (widget.images.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: mediaPadding.bottom + 18,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${widget.images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontFamily: 'Manrope',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 画廊网络图：仅按视口较长边限制解码宽度，高度随原图比例缩放。
ImageProvider _galleryImageProvider(BuildContext context, String url) {
  final viewport = MediaQuery.sizeOf(context);
  final longestSide = viewport.width > viewport.height
      ? viewport.width
      : viewport.height;
  final cacheWidth = _galleryDecodeExtent(context, longestSide, 4096);
  if (cacheWidth == null) {
    return NetworkImage(url);
  }
  return ResizeImage(
    NetworkImage(url),
    width: cacheWidth,
  );
}

int? _galleryDecodeExtent(
  BuildContext context,
  double logicalExtent,
  int maxPixels,
) {
  if (!logicalExtent.isFinite || logicalExtent <= 0) {
    return null;
  }
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (logicalExtent * dpr).ceil().clamp(1, maxPixels).toInt();
}
