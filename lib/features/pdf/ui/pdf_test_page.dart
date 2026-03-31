import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfTestPage extends StatefulWidget {
  const PdfTestPage({super.key});

  /// 你提供的在线 PDF（用于加载/缩放/滚动等常规功能验证）
  static final Uri testUri = Uri.parse('https://pdfyl.ertongbook.com/25/31190083.pdf');

  @override
  State<PdfTestPage> createState() => _PdfTestPageState();
}

class _PdfTestPageState extends State<PdfTestPage> {
  final PdfViewerController _controller = PdfViewerController();

  int? _pageNumber;
  int _pageCount = 0;
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!_controller.isReady) return;
    final int? page = _controller.pageNumber;
    final int count = _controller.pageCount;
    final double zoom = _controller.currentZoom;
    if (page == _pageNumber && count == _pageCount && (zoom - _zoom).abs() < 0.001) return;
    setState(() {
      _pageNumber = page;
      _pageCount = count;
      _zoom = zoom;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF 测试（pdfrx）'),
        actions: <Widget>[
          IconButton(
            tooltip: '缩小',
            onPressed: () => _controller.zoomDown(),
            icon: const Icon(Icons.zoom_out),
          ),
          IconButton(
            tooltip: '放大',
            onPressed: () => _controller.zoomUp(),
            icon: const Icon(Icons.zoom_in),
          ),
          IconButton(
            tooltip: '适配宽度（cover）',
            onPressed: () {
              if (!_controller.isReady) return;
              _controller.setZoom(_controller.centerPosition, _controller.coverScale);
            },
            icon: const Icon(Icons.fit_screen),
          ),
          IconButton(
            tooltip: '适配整页（alternative fit）',
            onPressed: () {
              if (!_controller.isReady) return;
              final double? z = _controller.alternativeFitScale;
              if (z == null) return;
              _controller.setZoom(_controller.centerPosition, z);
            },
            icon: const Icon(Icons.fullscreen),
          ),
          IconButton(
            tooltip: '重置',
            onPressed: () {
              if (!_controller.isReady) return;
              _controller.setZoom(_controller.centerPosition, 1.0);
            },
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: <Widget>[
          _StatusBar(pageNumber: _pageNumber, pageCount: _pageCount, zoom: _zoom),
          Expanded(
            child: PdfViewer.uri(
              PdfTestPage.testUri,
              controller: _controller,
              // preferRangeAccess: true 在部分服务器支持 Range 时可以更快定位与减少一次性下载；
              // 如果服务端不支持 Range，pdfrx 也会自动回退。
              preferRangeAccess: true,
              params: PdfViewerParams(
                backgroundColor: const Color(0xFFEDEDED),
                margin: 8,
                // 内存限制：更贴近老旧 iPad 场景，避免缓存过多高分辨率 page bitmap。
                limitRenderingCache: true,
                maxImageBytesCachedOnMemory: 64 * 1024 * 1024,
                // 交互：开启平移/缩放；最大缩放与最小缩放可按需调整。
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.5,
                maxScale: 6.0,
                // 加载/错误提示：默认 banner 的同时，也可以在这里自定义。
                loadingBannerBuilder:
                    (BuildContext context, int bytesDownloaded, int? totalBytes) {
                  return Center(
                    child: CircularProgressIndicator(
                      value: totalBytes == null ? null : bytesDownloaded / totalBytes,
                    ),
                  );
                },
                errorBannerBuilder: (BuildContext context, Object error,
                    StackTrace? stackTrace, PdfDocumentRef documentRef) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'PDF 加载失败：$error',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.pageNumber,
    required this.pageCount,
    required this.zoom,
  });

  final int? pageNumber;
  final int pageCount;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodySmall;
    final String page = pageNumber == null ? '—' : '$pageNumber';
    final String count = pageCount <= 0 ? '—' : '$pageCount';
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.black.withValues(alpha: 0.04),
      alignment: Alignment.centerLeft,
      child: Text(
        '页码：$page / $count    缩放：x${zoom.toStringAsFixed(2)}',
        style: style,
      ),
    );
  }
}

