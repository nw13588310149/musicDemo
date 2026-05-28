import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'osmd_score_shell.dart';

const _readyChannel = 'OsmdHostReady';
const _loadedChannel = 'OsmdScoreLoaded';

/// iPad / 原生 WebView：本地 OSMD + 文件加载 MusicXML，避免 WKWebView 大字符串 eval 崩溃。
class OsmdScoreViewer extends StatefulWidget {
  const OsmdScoreViewer({
    required this.musicXml,
    required this.playbackMs,
    this.onsetMs = const <int>[],
    super.key,
  });

  final String musicXml;
  final int playbackMs;
  final List<int> onsetMs;

  @override
  State<OsmdScoreViewer> createState() => _OsmdScoreViewerState();
}

class _OsmdScoreViewerState extends State<OsmdScoreViewer> {
  static Future<Directory>? _hostDirFuture;

  static var _counter = 0;

  late final WebViewController _controller;
  late final String _containerId;
  late final Directory _hostDir;

  var _hostReady = false;
  var _scoreLoaded = false;
  var _failed = false;
  String? _failureMessage;

  String _lastLoadedXml = '';
  List<int> _lastOnsets = const <int>[];
  int _lastSeekIndex = -1;

  @override
  void initState() {
    super.initState();
    _containerId = 'sight-osmd-${_counter++}';
    _controller = _createController();
    unawaited(_bootstrapHost());
  }

  WebViewController _createController() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF5F6F8))
      ..addJavaScriptChannel(
        _readyChannel,
        onMessageReceived: (JavaScriptMessage msg) {
          if (!mounted) return;
          if (msg.message == 'ready') {
            setState(() => _hostReady = true);
            unawaited(_applyXml(force: true));
            _applyOnsets(force: true);
          } else {
            setState(() {
              _failed = true;
              _failureMessage = '乐谱渲染器初始化失败';
            });
          }
        },
      )
      ..addJavaScriptChannel(
        _loadedChannel,
        onMessageReceived: (JavaScriptMessage msg) {
          if (!mounted) return;
          if (msg.message == 'loaded:$_containerId') {
            setState(() => _scoreLoaded = true);
            _applySeek(force: true);
          } else if (msg.message.startsWith('error:')) {
            setState(() {
              _failed = true;
              _failureMessage = 'MusicXML 渲染失败';
            });
          }
        },
      );

    return controller;
  }

  static Future<Directory> _ensureHostDir() {
    return _hostDirFuture ??= () async {
      final dir = Directory(
        '${Directory.systemTemp.path}/sight_singing_osmd_host',
      );
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final osmdAsset = await rootBundle.load(
        'assets/smart_sight_singing/${OsmdScoreShell.osmdScriptFileName}',
      );
      await File('${dir.path}/${OsmdScoreShell.osmdScriptFileName}').writeAsBytes(
        osmdAsset.buffer.asUint8List(
          osmdAsset.offsetInBytes,
          osmdAsset.lengthInBytes,
        ),
        flush: true,
      );

      return dir;
    }();
  }

  Future<void> _bootstrapHost() async {
    try {
      _hostDir = await _ensureHostDir();
      final htmlPath = '${_hostDir.path}/${OsmdScoreShell.hostHtmlFileName}';
      await File(htmlPath).writeAsString(
        OsmdScoreShell.hostHtml(containerId: _containerId),
        flush: true,
      );

      final platform = _controller.platform;
      if (platform is WebKitWebViewController) {
        await platform.loadFileWithParams(
          WebKitLoadFileParams(
            absoluteFilePath: htmlPath,
            readAccessPath: _hostDir.path,
          ),
        );
      } else {
        await _controller.loadFile(htmlPath);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _failureMessage = e is StateError ? e.message : '$e';
      });
    }
  }

  @override
  void didUpdateWidget(covariant OsmdScoreViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hostReady) return;
    if (oldWidget.musicXml != widget.musicXml) {
      unawaited(_applyXml());
    }
    if (!listEquals(oldWidget.onsetMs, widget.onsetMs)) {
      _applyOnsets();
    }
    if (oldWidget.playbackMs != widget.playbackMs) {
      _applySeek();
    }
  }

  Future<void> _applyXml({bool force = false}) async {
    final xml = widget.musicXml.trim();
    if (xml.isEmpty || !_hostReady) return;
    if (!force && xml == _lastLoadedXml) return;

    _lastLoadedXml = xml;
    _lastSeekIndex = -1;
    _scoreLoaded = false;

    try {
      final xmlPath = '${_hostDir.path}/${OsmdScoreShell.scoreXmlFileName}';
      await File(xmlPath).writeAsString(xml, flush: true);

      final divId = jsonEncode(_containerId);
      final fileName = jsonEncode(OsmdScoreShell.scoreXmlFileName);
      await _runJs(
        'window.__SightSingingOsmd && window.__SightSingingOsmd.loadFromFile($divId, $fileName);',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _failureMessage = '乐谱文件写入失败';
      });
    }
  }

  void _applyOnsets({bool force = false}) {
    if (!_hostReady) return;
    if (!force && listEquals(_lastOnsets, widget.onsetMs)) return;
    _lastOnsets = List<int>.unmodifiable(widget.onsetMs);
    _lastSeekIndex = -1;

    final divId = jsonEncode(_containerId);
    final encoded = jsonEncode(widget.onsetMs);
    unawaited(
      _runJs(
        'window.__SightSingingOsmd && window.__SightSingingOsmd.setOnsets($divId, $encoded);',
      ),
    );
  }

  void _applySeek({bool force = false}) {
    if (!_hostReady || !_scoreLoaded) return;

    final index = _noteIndexAt(widget.playbackMs);
    if (!force && index == _lastSeekIndex) return;
    _lastSeekIndex = index;

    final divId = jsonEncode(_containerId);
    unawaited(
      _runJs(
        'window.__SightSingingOsmd && window.__SightSingingOsmd.seek($divId, ${widget.playbackMs});',
      ),
    );
  }

  int _noteIndexAt(int ms) {
    final onsets = widget.onsetMs;
    if (onsets.isEmpty) return 0;

    var lo = 0;
    var hi = onsets.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (onsets[mid] <= ms) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return (lo - 1).clamp(0, onsets.length - 1);
  }

  Future<void> _runJs(String js) async {
    try {
      await _controller.runJavaScript(js);
    } catch (_) {
      // WebView 销毁时忽略。
    }
  }

  @override
  void dispose() {
    final divId = jsonEncode(_containerId);
    unawaited(
      _runJs(
        'window.__SightSingingOsmd && window.__SightSingingOsmd.dispose($divId);',
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _failed
        ? _OsmdErrorPlaceholder(message: _failureMessage)
        : WebViewWidget(
            controller: _controller,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
            },
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class _OsmdErrorPlaceholder extends StatelessWidget {
  const _OsmdErrorPlaceholder({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message?.isNotEmpty == true ? '乐谱加载失败：$message' : '乐谱加载失败',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            fontFamily: 'PingFang SC',
          ),
        ),
      ),
    );
  }
}
