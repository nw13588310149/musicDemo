import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'osmd_score_shell.dart';

extension on web.Window {
  void evalScript(String code) {
    (this as JSObject).callMethod('eval'.toJS, code.toJS);
  }
}

/// Web 端通过 HtmlElementView + OSMD 渲染标准五线谱。
class OsmdScoreViewer extends StatefulWidget {
  const OsmdScoreViewer({
    required this.musicXml,
    required this.playbackMs,
    super.key,
  });

  final String musicXml;
  final int playbackMs;

  @override
  State<OsmdScoreViewer> createState() => _OsmdScoreViewerWebState();
}

class _OsmdScoreViewerWebState extends State<OsmdScoreViewer> {
  static var _viewCounter = 0;
  late final String _viewType;
  late final web.HTMLIFrameElement _frame;
  var _ready = false;
  var _lastLoadedXml = '';
  var _lastSeekMs = -1;

  @override
  void initState() {
    super.initState();
    _viewType = 'osmd-score-view-${_viewCounter++}';
    _frame = web.HTMLIFrameElement()
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#F5F6F8'
      ..srcdoc = OsmdScoreShell.htmlDocument().toJS
      ..onLoad.listen((_) {
        if (!mounted) {
          return;
        }
        setState(() => _ready = true);
        _loadScoreIfNeeded(force: true);
        _seekIfNeeded(force: true);
      });

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _frame,
    );
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

  void _loadScoreIfNeeded({bool force = false}) {
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
    _frame.contentWindow?.evalScript('window.renderScoreFromBase64("$encoded");');
    _seekIfNeeded(force: true);
  }

  void _seekIfNeeded({bool force = false}) {
    if (!_ready) {
      return;
    }
    final ms = widget.playbackMs;
    if (!force && ms == _lastSeekMs) {
      return;
    }
    _lastSeekMs = ms;
    _frame.contentWindow?.evalScript('window.seekToMs($ms);');
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
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
