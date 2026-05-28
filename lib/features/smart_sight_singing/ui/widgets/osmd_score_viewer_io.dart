import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'osmd_score_shell.dart';

/// 使用 OpenSheetMusicDisplay 渲染 MusicXML 乐谱（标准五线谱排版）。
class OsmdScoreViewer extends StatefulWidget {
  const OsmdScoreViewer({
    required this.musicXml,
    required this.playbackMs,
    super.key,
  });

  final String musicXml;
  final int playbackMs;

  @override
  State<OsmdScoreViewer> createState() => _OsmdScoreViewerState();
}

class _OsmdScoreViewerState extends State<OsmdScoreViewer> {
  late final WebViewController _controller;
  var _ready = false;
  var _lastLoadedXml = '';
  var _lastSeekMs = -1;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF5F6F8))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted) {
              return;
            }
            setState(() => _ready = true);
            _loadScoreIfNeeded(force: true);
            _seekIfNeeded(force: true);
          },
        ),
      )
      ..loadHtmlString(OsmdScoreShell.htmlDocument(), baseUrl: 'https://localhost/');
  }

  @override
  void didUpdateWidget(covariant OsmdScoreViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) {
      return;
    }
    if (oldWidget.musicXml != widget.musicXml) {
      _loadScoreIfNeeded(force: true);
    }
    if (oldWidget.playbackMs != widget.playbackMs) {
      _seekIfNeeded();
    }
  }

  Future<void> _loadScoreIfNeeded({bool force = false}) async {
    final xml = widget.musicXml.trim();
    if (xml.isEmpty || (!_ready && !force)) {
      return;
    }
    if (!force && xml == _lastLoadedXml) {
      return;
    }
    _lastLoadedXml = xml;
    _lastSeekMs = -1;
    final encoded = base64Encode(utf8.encode(xml));
    await _controller.runJavaScript('window.renderScoreFromBase64("$encoded");');
    await _seekIfNeeded(force: true);
  }

  Future<void> _seekIfNeeded({bool force = false}) async {
    if (!_ready) {
      return;
    }
    final ms = widget.playbackMs;
    if (!force && ms == _lastSeekMs) {
      return;
    }
    _lastSeekMs = ms;
    await _controller.runJavaScript('window.seekToMs($ms);');
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
