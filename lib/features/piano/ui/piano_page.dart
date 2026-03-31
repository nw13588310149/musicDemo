import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/piano_audio_manager.dart';
import '../data/piano_notes.dart';

class PianoPage extends StatefulWidget {
  const PianoPage({super.key});

  @override
  State<PianoPage> createState() => _PianoPageState();
}

class _PianoPageState extends State<PianoPage> {
  final List<PianoNote> _whiteNotes = PianoNotes.buildWhite();
  final List<PianoNote> _blackNotes = PianoNotes.buildBlack();
  final Set<int> _pressedIds = <int>{};
  final ScrollController _scrollController = ScrollController();

  bool _showLabels = false;
  bool _loadingAudio = true;
  double _zoom = 1.0;
  final Map<int, int> _pointerToNote = <int, int>{};
  double _scrollRatio = 0;

  static const List<int> _leftWhiteIndexes = <int>[0, 1, 3, 4, 5];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onKeyboardScroll);
    _prepareAudio();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onKeyboardScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onKeyboardScroll() {
    if (!_scrollController.hasClients) return;
    final double max = _scrollController.position.maxScrollExtent;
    final double ratio = max <= 0 ? 0 : (_scrollController.offset / max).clamp(0, 1);
    if ((ratio - _scrollRatio).abs() < 0.001) return;
    setState(() => _scrollRatio = ratio);
  }

  Future<void> _prepareAudio() async {
    try {
      await PianoAudioManager.instance.preloadAll();
    } finally {
      if (!mounted) return;
      setState(() => _loadingAudio = false);
    }
  }

  void _onKeyDown(PianoNote note) {
    setState(() => _pressedIds.add(note.id));
    PianoAudioManager.instance.playByFileName(note.sampleFile);
  }

  void _onKeyUp(PianoNote note) {
    setState(() => _pressedIds.remove(note.id));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('钢琴（CSS 样式复刻）'),
        backgroundColor: cs.inversePrimary,
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints pageConstraints) {
          final double viewportWidth = pageConstraints.maxWidth;
          final double whiteKeyWidth = 52 * _zoom;
          final double keyboardWidth = whiteKeyWidth * _whiteNotes.length;
          final double blackKeyWidth = whiteKeyWidth * 0.7;

          return Column(
            children: <Widget>[
              _buildTopBar(viewportWidth: viewportWidth, keyboardWidth: keyboardWidth),
              if (_loadingAudio) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return Stack(
                      children: <Widget>[
                        Container(color: Colors.white),
                        SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: SizedBox(
                            width: math.max(constraints.maxWidth, keyboardWidth),
                            height: constraints.maxHeight,
                            child: Stack(
                              children: <Widget>[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: _whiteNotes.map((PianoNote note) {
                                    return _WhiteKey(
                                      note: note,
                                      width: whiteKeyWidth,
                                      showLabel: _showLabels,
                                      active: _pressedIds.contains(note.id),
                                    );
                                  }).toList(growable: false),
                                ),
                                ..._buildBlackKeys(
                                  whiteKeyWidth: whiteKeyWidth,
                                  blackKeyWidth: blackKeyWidth,
                                  keyboardHeight: constraints.maxHeight,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: (PointerDownEvent e) {
                            _handlePointer(
                              pointer: e.pointer,
                              localPosition: e.localPosition,
                              whiteKeyWidth: whiteKeyWidth,
                              blackKeyWidth: blackKeyWidth,
                              keyboardHeight: constraints.maxHeight,
                            );
                          },
                          onPointerMove: (PointerMoveEvent e) {
                            _handlePointer(
                              pointer: e.pointer,
                              localPosition: e.localPosition,
                              whiteKeyWidth: whiteKeyWidth,
                              blackKeyWidth: blackKeyWidth,
                              keyboardHeight: constraints.maxHeight,
                            );
                          },
                          onPointerUp: (PointerUpEvent e) => _releasePointer(e.pointer),
                          onPointerCancel: (PointerCancelEvent e) => _releasePointer(e.pointer),
                          child: const SizedBox.expand(),
                        ),
                        Positioned(
                          right: 5,
                          bottom: 160,
                          child: GestureDetector(
                            onTap: () => setState(() => _showLabels = !_showLabels),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Image.asset(
                                    _showLabels
                                        ? 'assets/images/piano/eye_close.jpg'
                                        : 'assets/images/piano/eye_open.jpg',
                                    errorBuilder: (_, __, ___) => Icon(
                                      _showLabels ? Icons.visibility_off : Icons.visibility,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildBlackKeys({
    required double whiteKeyWidth,
    required double blackKeyWidth,
    required double keyboardHeight,
  }) {
    final List<Widget> widgets = <Widget>[];
    for (int i = 0; i < _blackNotes.length; i++) {
      final PianoNote note = _blackNotes[i];
      final int octave = i ~/ 5;
      final int positionInOctave = i % 5;
      final int leftWhiteIndex = octave * 7 + _leftWhiteIndexes[positionInOctave];
      final double left = ((leftWhiteIndex + 1) * whiteKeyWidth) - (blackKeyWidth / 2);

      widgets.add(
        Positioned(
          left: left,
          top: 0,
          width: blackKeyWidth,
          height: keyboardHeight * 0.52,
          child: _BlackKey(
            note: note,
            active: _pressedIds.contains(note.id),
          ),
        ),
      );
    }
    return widgets;
  }

  void _handlePointer({
    required int pointer,
    required Offset localPosition,
    required double whiteKeyWidth,
    required double blackKeyWidth,
    required double keyboardHeight,
  }) {
    final PianoNote? hit = _hitTestNote(
      localPosition: localPosition,
      whiteKeyWidth: whiteKeyWidth,
      blackKeyWidth: blackKeyWidth,
      keyboardHeight: keyboardHeight,
    );

    final int? oldId = _pointerToNote[pointer];
    if (hit == null) {
      if (oldId != null) {
        final PianoNote oldNote = _noteById(oldId);
        _onKeyUp(oldNote);
        _pointerToNote.remove(pointer);
      }
      return;
    }

    if (oldId == hit.id) return;

    if (oldId != null) {
      final PianoNote oldNote = _noteById(oldId);
      _onKeyUp(oldNote);
    }

    _pointerToNote[pointer] = hit.id;
    _onKeyDown(hit);
  }

  void _releasePointer(int pointer) {
    final int? noteId = _pointerToNote.remove(pointer);
    if (noteId == null) return;
    _onKeyUp(_noteById(noteId));
  }

  PianoNote _noteById(int id) {
    return _whiteNotes.followedBy(_blackNotes).firstWhere((PianoNote n) => n.id == id);
  }

  PianoNote? _hitTestNote({
    required Offset localPosition,
    required double whiteKeyWidth,
    required double blackKeyWidth,
    required double keyboardHeight,
  }) {
    final double scrollX = _scrollController.hasClients ? _scrollController.offset : 0;
    final double x = localPosition.dx + scrollX;
    final double y = localPosition.dy;

    if (x < 0 || y < 0 || y > keyboardHeight) return null;

    final double blackHeight = keyboardHeight * 0.52;
    if (y <= blackHeight) {
      for (int i = 0; i < _blackNotes.length; i++) {
        final int octave = i ~/ 5;
        final int pos = i % 5;
        final int leftWhiteIndex = octave * 7 + _leftWhiteIndexes[pos];
        final double left = ((leftWhiteIndex + 1) * whiteKeyWidth) - (blackKeyWidth / 2);
        final double right = left + blackKeyWidth;
        if (x >= left && x <= right) {
          return _blackNotes[i];
        }
      }
    }

    final int whiteIndex = (x / whiteKeyWidth).floor();
    if (whiteIndex < 0 || whiteIndex >= _whiteNotes.length) return null;
    return _whiteNotes[whiteIndex];
  }

  Widget _buildTopBar({
    required double viewportWidth,
    required double keyboardWidth,
  }) {
    final double visibleRatio = (viewportWidth / keyboardWidth).clamp(0.18, 1);
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF333333), Color(0xFF171A20), Color(0xFF333333)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: <Widget>[
          _CircleButton(
            icon: Icons.remove,
            onPressed: () => setState(() => _zoom = (_zoom - 0.1).clamp(0.75, 1.8)),
            assetPath: 'assets/images/piano/del.png',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final double trackWidth = c.maxWidth;
                final double thumbWidth = (trackWidth * visibleRatio).clamp(56, trackWidth);
                final double maxX = math.max(0, trackWidth - thumbWidth);
                final double thumbX = maxX * _scrollRatio;

                return ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (TapDownDetails d) {
                      if (maxX <= 0) return;
                      final double ratio = ((d.localPosition.dx - thumbWidth / 2) / maxX).clamp(0, 1);
                      _scrollToRatio(ratio);
                    },
                    onHorizontalDragUpdate: (DragUpdateDetails d) {
                      if (maxX <= 0) return;
                      final double ratio = ((_scrollRatio * maxX + d.delta.dx) / maxX).clamp(0, 1);
                      _scrollToRatio(ratio);
                    },
                    child: Stack(
                      children: <Widget>[
                        const Positioned.fill(child: ColoredBox(color: Color(0xFF4A4F63))),
                        const Positioned.fill(
                          child: _OptionalAssetImage(path: 'assets/images/piano/piano_bg1.jpg'),
                        ),
                        Positioned(
                          left: thumbX,
                          top: 0,
                          bottom: 0,
                          width: thumbWidth,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const _OptionalAssetImage(path: 'assets/images/piano/piano_bg.jpg'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          _CircleButton(
            icon: Icons.add,
            onPressed: () => setState(() => _zoom = (_zoom + 0.1).clamp(0.75, 1.8)),
            assetPath: 'assets/images/piano/add.png',
          ),
        ],
      ),
    );
  }

  void _scrollToRatio(double ratio) {
    if (!_scrollController.hasClients) return;
    final double max = _scrollController.position.maxScrollExtent;
    if (max <= 0) {
      if (_scrollRatio != 0) setState(() => _scrollRatio = 0);
      return;
    }
    final double target = (ratio.clamp(0, 1)) * max;
    _scrollController.jumpTo(target);
    setState(() => _scrollRatio = ratio.clamp(0, 1));
  }
}

class _OptionalAssetImage extends StatelessWidget {
  const _OptionalAssetImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onPressed,
    this.assetPath,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Center(
            child: assetPath == null
                ? Icon(icon, size: 20, color: Colors.white)
                : Image.asset(
                    assetPath!,
                    width: 22,
                    height: 22,
                    errorBuilder: (_, __, ___) => Icon(icon, size: 20, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}

class _WhiteKey extends StatelessWidget {
  const _WhiteKey({
    required this.note,
    required this.width,
    required this.showLabel,
    required this.active,
  });

  final PianoNote note;
  final double width;
  final bool showLabel;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 45),
      width: width,
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(
                colors: <Color>[
                  Color.fromRGBO(0, 0, 0, 0.60),
                  Color.fromRGBO(0, 0, 0, 0.40),
                  Color.fromRGBO(0, 0, 0, 0.60),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: active ? null : Colors.white,
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(5),
        ),
        boxShadow: <BoxShadow>[
          if (!active)
            const BoxShadow(
              color: Colors.black54,
              offset: Offset(0, 4),
              blurRadius: 3,
            ),
        ],
      ),
      child: showLabel
          ? Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  const Spacer(),
                  SizedBox(
                    width: 22,
                    height: 20,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: note.highlight ? const Color(0xFF00C9A4) : _labelColor(note.id - 1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            note.solfege,
                            style: TextStyle(
                              color: note.highlight ? Colors.white : Colors.black87,
                              fontSize: 12,
                              height: 1,
                            ),
                          ),
                          if ((note.nameSuffix ?? '').isNotEmpty)
                            Transform.translate(
                              offset: const Offset(0, -3),
                              child: Text(
                                note.nameSuffix!,
                                style: TextStyle(
                                  color: note.highlight ? Colors.white : Colors.black87,
                                  fontSize: 9,
                                  height: 1,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${note.displayNumber}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 22, child: _OctaveDotMarker(marker: note.octaveMark)),
                  const SizedBox(height: 2),
                ],
              )
          : null,
    );
  }

  Color _labelColor(int index) {
    if (index < 7) return const Color(0xCCFDBCD2);
    if (index < 14) return const Color(0xCCACAFFE);
    if (index < 21) return const Color(0xCCFEE5C6);
    if (index < 28) return const Color(0xCCA6FFFB);
    return const Color(0xCCA4FEBE);
  }
}

class _OctaveDotMarker extends StatelessWidget {
  const _OctaveDotMarker({required this.marker});

  final String marker;

  @override
  Widget build(BuildContext context) {
    if (marker.isEmpty) return const SizedBox.shrink();
    if (marker == '.') return const Text('.', style: TextStyle(height: 1, fontSize: 14));
    if (marker == '..') return _buildDots(2);
    if (marker == '1.') return _buildDots(1);
    if (marker == '1..') return _buildDots(2);
    return _buildDots(3);
  }

  Widget _buildDots(int count) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(
        count,
        (int index) => const Text('.', style: TextStyle(height: 1, fontSize: 14)),
      ),
    );
  }
}

class _BlackKey extends StatelessWidget {
  const _BlackKey({
    required this.note,
    required this.active,
  });

  final PianoNote note;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 35),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(
                colors: <Color>[Color(0xFF696969), Color(0xFF171A20), Colors.black],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              )
            : const LinearGradient(
                colors: <Color>[Color(0xFF333333), Color(0xFF171A20), Color(0xFF333333)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
        border: const Border(
          top: BorderSide(color: Color(0xFF666666), width: 1),
          left: BorderSide(color: Color(0xFF555555), width: 1),
          right: BorderSide(color: Color(0xFF222222), width: 2),
          bottom: BorderSide(color: Color(0xFF111111), width: 7),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(2),
          bottomRight: Radius.circular(2),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: active ? 0.45 : 0.35),
            offset: const Offset(0, 2),
            blurRadius: 3,
          ),
        ],
      ),
    );
  }
}
