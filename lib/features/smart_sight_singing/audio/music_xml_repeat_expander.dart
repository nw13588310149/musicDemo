import 'package:xml/xml.dart';

/// 按 MusicXML 反复 / 跳房子 / D.C. / D.S. 等规则展开小节播放顺序。
///
/// 使用原始 XML 解析导航记号（music_xml 包尚未完整支持 barline repeat / sound 导航）。
abstract final class MusicXmlRepeatExpander {
  /// 返回 0-based 小节下标序列（可含重复小节）。
  static List<int> expandMeasureOrder({
    required String? rawXml,
    required int partIndex,
    required int measureCount,
  }) {
    if (measureCount <= 0) return const <int>[];
    final nav = _parsePartMeasureNav(rawXml, partIndex, measureCount);
    if (nav == null || !nav.any((m) => m.hasNavigation)) {
      return List<int>.generate(measureCount, (i) => i);
    }
    return _simulatePlayback(nav);
  }

  static List<_MeasureNav>? _parsePartMeasureNav(
    String? rawXml,
    int partIndex,
    int measureCount,
  ) {
    final raw = rawXml?.trim();
    if (raw == null || raw.isEmpty) return null;

    try {
      final xml = XmlDocument.parse(raw);
      final parts = xml.rootElement
          .findElements('part')
          .where((p) => p.name.local == 'part')
          .toList(growable: false);
      if (partIndex < 1 || partIndex > parts.length) return null;

      final measures = parts[partIndex - 1]
          .findElements('measure')
          .where((m) => m.name.local == 'measure')
          .toList(growable: false);
      if (measures.isEmpty) return null;

      final result = <_MeasureNav>[];
      for (var i = 0; i < measures.length; i++) {
        result.add(_parseMeasureNav(measures[i]));
      }
      while (result.length < measureCount) {
        result.add(const _MeasureNav());
      }
      if (result.length > measureCount) {
        result.removeRange(measureCount, result.length);
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  static _MeasureNav _parseMeasureNav(XmlElement measure) {
    var forwardRepeat = false;
    var backwardRepeat = false;
    int? repeatTimes;
    var daCapo = false;
    var dalSegno = false;
    var fine = false;
    var toCoda = false;
    var hasSegno = false;
    var hasCoda = false;
    final endingStarts = <int>{};
    final endingStops = <int>{};

    for (final barline in measure.findElements('barline')) {
      if (barline.name.local != 'barline') continue;
      final location = barline.getAttribute('location') ?? 'right';
      for (final repeat in barline.findElements('repeat')) {
        if (repeat.name.local != 'repeat') continue;
        final direction = repeat.getAttribute('direction');
        if (direction == 'forward' && location == 'left') {
          forwardRepeat = true;
        } else if (direction == 'backward') {
          backwardRepeat = true;
          repeatTimes = int.tryParse(repeat.getAttribute('times') ?? '');
        }
      }
      for (final ending in barline.findElements('ending')) {
        if (ending.name.local != 'ending') continue;
        final numbers = _parseEndingNumbers(ending.getAttribute('number'));
        final type = ending.getAttribute('type');
        if (type == 'start') {
          endingStarts.addAll(numbers);
        } else if (type == 'stop' || type == 'discontinue') {
          endingStops.addAll(numbers);
        }
      }
    }

    for (final direction in measure.findAllElements('direction')) {
      if (direction.name.local != 'direction') continue;
      for (final sound in direction.findElements('sound')) {
        if (sound.name.local != 'sound') continue;
        if (_isYes(sound.getAttribute('dacapo'))) daCapo = true;
        if (_isYes(sound.getAttribute('dalsegno'))) dalSegno = true;
        if (_isYes(sound.getAttribute('fine'))) fine = true;
        if (sound.getAttribute('segno') != null) hasSegno = true;
        if (sound.getAttribute('coda') != null) hasCoda = true;
        if (sound.getAttribute('tocoda') != null) toCoda = true;
      }
      for (final type in direction.findElements('direction-type')) {
        if (type.name.local != 'direction-type') continue;
        if (type.findElements('segno').isNotEmpty) hasSegno = true;
        if (type.findElements('coda').isNotEmpty) hasCoda = true;
        for (final words in type.findElements('words')) {
          final text = words.innerText.toUpperCase();
          if (text.contains('D.C')) daCapo = true;
          if (text.contains('D.S')) dalSegno = true;
          if (text.contains('FINE')) fine = true;
          if (text.contains('TO CODA') || text.contains('CODA')) {
            toCoda = true;
          }
        }
      }
    }

    return _MeasureNav(
      forwardRepeat: forwardRepeat,
      backwardRepeat: backwardRepeat,
      repeatTimes: repeatTimes,
      daCapo: daCapo,
      dalSegno: dalSegno,
      fine: fine,
      toCoda: toCoda,
      hasSegno: hasSegno,
      hasCoda: hasCoda,
      endingStarts: endingStarts,
      endingStops: endingStops,
    );
  }

  static Set<int> _parseEndingNumbers(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {1};
    final numbers = <int>{};
    for (final part in raw.split(RegExp(r'[,\s]+'))) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final range = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(trimmed);
      if (range != null) {
        final start = int.parse(range.group(1)!);
        final end = int.parse(range.group(2)!);
        for (var i = start; i <= end; i++) {
          numbers.add(i);
        }
        continue;
      }
      final value = int.tryParse(trimmed);
      if (value != null && value > 0) numbers.add(value);
    }
    return numbers.isEmpty ? {1} : numbers;
  }

  static bool _isYes(String? value) {
    if (value == null) return false;
    final lower = value.toLowerCase();
    return lower == 'yes' || lower == 'true' || lower == '1';
  }

  static List<int> _simulatePlayback(List<_MeasureNav> nav) {
    final order = <int>[];
    var index = 0;
    var forwardRepeatIndex = -1;
    final repeatPassByForward = <int, int>{};
    var activeEndingPass = 1;
    var playUntilFine = false;
    var jumpToCodaPending = false;

    var segnoIndex = -1;
    var codaIndex = -1;
    for (var i = 0; i < nav.length; i++) {
      if (nav[i].hasSegno) segnoIndex = i;
      if (nav[i].hasCoda) codaIndex = i;
    }

    var guard = 0;
    const maxSteps = 4096;

    while (index >= 0 && index < nav.length && guard < maxSteps) {
      guard += 1;

      if (jumpToCodaPending && codaIndex >= 0 && index < codaIndex) {
        index = codaIndex;
        jumpToCodaPending = false;
        continue;
      }

      final current = nav[index];
      if (!_shouldPlayMeasure(current, activeEndingPass)) {
        index += 1;
        continue;
      }

      if (current.forwardRepeat) {
        forwardRepeatIndex = index;
        repeatPassByForward.putIfAbsent(index, () => 0);
      }

      order.add(index);

      if (current.toCoda) {
        jumpToCodaPending = true;
      }

      if (current.fine && playUntilFine) {
        break;
      }

      if (current.daCapo) {
        playUntilFine = true;
        index = 0;
        forwardRepeatIndex = -1;
        continue;
      }

      if (current.dalSegno) {
        playUntilFine = true;
        index = segnoIndex >= 0 ? segnoIndex : 0;
        forwardRepeatIndex = -1;
        continue;
      }

      if (current.backwardRepeat) {
        final anchor = forwardRepeatIndex >= 0 ? forwardRepeatIndex : 0;
        final maxPasses = current.repeatTimes ?? 2;
        final taken = repeatPassByForward[anchor] ?? 0;
        if (taken + 1 < maxPasses) {
          repeatPassByForward[anchor] = taken + 1;
          activeEndingPass = taken + 2;
          index = anchor;
          continue;
        }
        forwardRepeatIndex = -1;
        activeEndingPass = 1;
      }

      index += 1;
    }

    return order.isEmpty ? List<int>.generate(nav.length, (i) => i) : order;
  }

  static bool _shouldPlayMeasure(_MeasureNav nav, int endingPass) {
    if (nav.endingStarts.isEmpty && nav.endingStops.isEmpty) {
      return true;
    }
    if (nav.endingStarts.isNotEmpty) {
      return nav.endingStarts.contains(endingPass);
    }
    if (nav.endingStops.isNotEmpty) {
      return nav.endingStops.contains(endingPass);
    }
    return true;
  }
}

class _MeasureNav {
  const _MeasureNav({
    this.forwardRepeat = false,
    this.backwardRepeat = false,
    this.repeatTimes,
    this.daCapo = false,
    this.dalSegno = false,
    this.fine = false,
    this.toCoda = false,
    this.hasSegno = false,
    this.hasCoda = false,
    this.endingStarts = const <int>{},
    this.endingStops = const <int>{},
  });

  final bool forwardRepeat;
  final bool backwardRepeat;
  final int? repeatTimes;
  final bool daCapo;
  final bool dalSegno;
  final bool fine;
  final bool toCoda;
  final bool hasSegno;
  final bool hasCoda;
  final Set<int> endingStarts;
  final Set<int> endingStops;

  bool get hasNavigation =>
      forwardRepeat ||
      backwardRepeat ||
      daCapo ||
      dalSegno ||
      fine ||
      toCoda ||
      hasSegno ||
      hasCoda ||
      endingStarts.isNotEmpty ||
      endingStops.isNotEmpty;
}
