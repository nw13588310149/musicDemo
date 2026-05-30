import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:music_xml/music_xml.dart';
import 'package:xml/xml.dart';

import '../../music_companion/audio/music_companion_audio_catalog.dart';
import '../config/smart_sight_singing_config.dart';
import 'ktv_pitch_guide.dart';
import 'midi_sight_singing_service.dart';
import 'pitch_track.dart';

/// MusicXML 解析预览（尚未选定声部）。
class MusicXmlParsePreview {
  const MusicXmlParsePreview({
    required this.document,
    required this.rawXml,
    required this.summaries,
    required this.suggestedPartIndex,
  });

  final MusicXmlDocument document;
  final String rawXml;
  final List<MidiTrackSummary> summaries;
  final int suggestedPartIndex;
}

/// MusicXML 解析结果（与 [MidiSightSingingBundle] 结构一致，便于复用播放/打分链路）。
class MusicXmlSightSingingBundle {
  const MusicXmlSightSingingBundle({
    required this.track,
    required this.playbackEvents,
    required this.melodyPartIndex,
    required this.totalMs,
  });

  final PitchTrack track;
  final List<MidiPlaybackEvent> playbackEvents;
  final int melodyPartIndex;
  final int totalMs;
}

class MusicXmlSightSingingException implements Exception {
  MusicXmlSightSingingException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract final class MusicXmlSightSingingService {
  /// 解析 `.xml` / `.musicxml` 字符串或 `.mxl` 二进制。
  static MusicXmlParsePreview parseBytes(Uint8List bytes, {String? fileName}) {
    final rawXml = _decodeXmlString(bytes, fileName: fileName);
    return parseXml(rawXml);
  }

  static MusicXmlParsePreview parseXml(String rawXml) {
    final trimmed = rawXml.trim();
    if (trimmed.isEmpty) {
      throw MusicXmlSightSingingException('MusicXML 内容为空。');
    }

    final MusicXmlDocument document;
    try {
      document = MusicXmlDocument.parse(trimmed);
    } catch (e) {
      throw MusicXmlSightSingingException('MusicXML 解析失败：$e');
    }

    final parts = document.score.parts;
    if (parts.isEmpty) {
      throw MusicXmlSightSingingException('MusicXML 中没有声部。');
    }

    final suggested = _suggestMelodyPartIndex(document);
    final summaries = <MidiTrackSummary>[];
    for (var i = 0; i < parts.length; i++) {
      summaries.add(_summaryForPart(document, i, suggested));
    }

    if (summaries.every((item) => !item.hasNotes)) {
      throw MusicXmlSightSingingException('MusicXML 中没有可跟唱的音符。');
    }

    return MusicXmlParsePreview(
      document: document,
      rawXml: trimmed,
      summaries: summaries,
      suggestedPartIndex: suggested,
    );
  }

  static MusicXmlSightSingingBundle buildBundle(
    MusicXmlDocument document,
    int partIndex, {
    String? rawXml,
  }) {
    if (partIndex < 1 || partIndex > document.score.parts.length) {
      throw MusicXmlSightSingingException('声部编号无效：$partIndex');
    }

    final part = document.score.parts[partIndex - 1];
    final notes = _collectPartNotes(part);
    if (notes.isEmpty) {
      throw MusicXmlSightSingingException('声部 $partIndex 没有可跟唱音符。');
    }

    final leadIn = _resolveLeadIn(document, partIndex, rawXml: rawXml);
    final leadInMs = leadIn?.durationMs ?? 0;
    final shiftedNotes = leadInMs > 0 ? _shiftNotes(notes, leadInMs) : notes;

    final range = KtvPitchGuideBuilder.rangeForNotes(shiftedNotes);
    final baseTotalMs = math.max(
      (document.totalTimeSecs * 1000).ceil(),
      notes.map((n) => n.endMs).reduce(math.max),
    );
    // 播放时间轴含预备拍；进度条总时长仅反映旋律部分。
    final playbackTotalMs = baseTotalMs + leadInMs;

    final track = PitchTrack(
      frames: const <PitchFrame>[],
      notes: shiftedNotes,
      totalMs: baseTotalMs,
      frameStepMs: SmartSightSingingMidiConfig.referenceFrameStepMs,
      minMidi: range.minMidi,
      maxMidi: range.maxMidi,
    );

    final playbackEvents = <MidiPlaybackEvent>[
      if (leadIn != null) ...leadIn.playbackEvents,
      ...notes.map(
        (n) => MidiPlaybackEvent(
          timeMs: n.startMs + leadInMs,
          pitch: n.midi.round(),
          velocity: 96,
        ),
      ),
    ]
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));

    return MusicXmlSightSingingBundle(
      track: track,
      playbackEvents: playbackEvents,
      melodyPartIndex: partIndex,
      totalMs: playbackTotalMs,
    );
  }

  static String _decodeXmlString(Uint8List bytes, {String? fileName}) {
    final lowerName = fileName?.toLowerCase() ?? '';
    final isMxl =
        lowerName.endsWith('.mxl') ||
        (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B);
    if (isMxl) {
      try {
        return MusicXmlDocument.parseMxl(bytes).toXmlString();
      } catch (e) {
        throw MusicXmlSightSingingException('压缩 MusicXML (.mxl) 解析失败：$e');
      }
    }

    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      throw MusicXmlSightSingingException('无法读取 MusicXML 文本，请确认文件编码为 UTF-8。');
    }
  }

  static List<KtvNoteSegment> _collectPartNotes(Part part) {
    final notes = <KtvNoteSegment>[];
    for (final measure in part.measures) {
      for (final note in measure.notes) {
        if (note.isRest || note.isGraceNote || note.continuesOtherNote) {
          continue;
        }
        if (note.isInChord) {
          continue;
        }
        final midi = note.pitchMap?.value;
        if (midi == null || midi <= 0) {
          continue;
        }

        final tiedDuration = note.noteDurationTied;
        final durationSec = tiedDuration.seconds > 0
            ? tiedDuration.seconds
            : note.noteDuration.seconds;
        if (durationSec <= 0) {
          continue;
        }

        final startMs = (note.noteDuration.timePosition * 1000).round();
        final endMs = math.max(
          startMs + SmartSightSingingMidiConfig.minMidiNoteMs,
          ((note.noteDuration.timePosition + durationSec) * 1000).round(),
        );

        notes.add(
          KtvNoteSegment(
            startMs: startMs,
            endMs: endMs,
            midi: midi.toDouble(),
            startBeat: note.noteDuration.timePosition,
            durationBeats: durationSec,
          ),
        );
      }
    }
    notes.sort((a, b) => a.startMs.compareTo(b.startMs));
    return notes;
  }

  static List<KtvNoteSegment> _shiftNotes(
    List<KtvNoteSegment> notes,
    int offsetMs,
  ) {
    return notes
        .map(
          (note) => KtvNoteSegment(
            startMs: note.startMs + offsetMs,
            endMs: note.endMs + offsetMs,
            midi: note.midi,
            startBeat: note.startBeat,
            durationBeats: note.durationBeats,
          ),
        )
        .toList(growable: false);
  }

  static _MusicXmlLeadIn? _resolveLeadIn(
    MusicXmlDocument document,
    int partIndex, {
    String? rawXml,
  }) {
    final raw = _resolveLeadInFromRawXml(rawXml, partIndex);
    if (raw != null) return raw;

    // Fallback for MusicXML files that use <sound tempo="...">, which the
    // music_xml package parses into Measure.tempos.
    final part = document.score.parts[partIndex - 1];
    double? qpm;
    for (final measure in part.measures) {
      if (measure.tempos.isNotEmpty) {
        qpm = measure.tempos.first.qpm;
        break;
      }
    }
    if (qpm == null || qpm <= 0) return null;

    final signature = _firstParsedTimeSignature(part);
    return _MusicXmlLeadIn.fromTempoAndSignature(
      qpm: qpm,
      beats: signature.beats,
      beatType: signature.beatType,
    );
  }

  static _MusicXmlLeadIn? _resolveLeadInFromRawXml(
    String? rawXml,
    int partIndex,
  ) {
    final raw = rawXml?.trim();
    if (raw == null || raw.isEmpty) return null;

    try {
      final xml = XmlDocument.parse(raw);
      final parts = xml.rootElement
          .findElements('part')
          .where((part) => part.name.local == 'part')
          .toList(growable: false);
      if (partIndex < 1 || partIndex > parts.length) return null;

      final selectedPart = parts[partIndex - 1];
      final firstMeasure = selectedPart.findElements('measure').firstOrNull;
      if (firstMeasure == null) return null;

      final qpm = _tempoFromRawMeasure(firstMeasure);
      if (qpm == null || qpm <= 0) return null;

      final signature = _timeSignatureFromRawMeasure(firstMeasure);
      return _MusicXmlLeadIn.fromTempoAndSignature(
        qpm: qpm,
        beats: signature.beats,
        beatType: signature.beatType,
      );
    } catch (_) {
      return null;
    }
  }

  static double? _tempoFromRawMeasure(XmlElement measure) {
    for (final sound in measure.findAllElements('sound')) {
      final tempo = double.tryParse(sound.getAttribute('tempo') ?? '');
      if (tempo != null && tempo > 0) return tempo;
    }

    for (final metronome in measure.findAllElements('metronome')) {
      final perMinute = metronome.getElement('per-minute')?.innerText.trim();
      final tempo = double.tryParse(perMinute ?? '');
      if (tempo != null && tempo > 0) return tempo;
    }
    return null;
  }

  static _MusicXmlTimeSignature _timeSignatureFromRawMeasure(
    XmlElement measure,
  ) {
    final time = measure.findAllElements('time').firstOrNull;
    if (time == null) return const _MusicXmlTimeSignature(beats: 4, beatType: 4);

    final beats = int.tryParse(time.getElement('beats')?.innerText.trim() ?? '');
    final beatType = int.tryParse(
      time.getElement('beat-type')?.innerText.trim() ?? '',
    );
    return _MusicXmlTimeSignature(
      beats: beats != null && beats > 0 ? beats : 4,
      beatType: beatType != null && beatType > 0 ? beatType : 4,
    );
  }

  static _MusicXmlTimeSignature _firstParsedTimeSignature(Part part) {
    for (final measure in part.measures) {
      for (final attributes in measure.attributesList) {
        if (attributes.times.isEmpty) continue;
        final time = attributes.times.first;
        if (time.numerator > 0 && time.denominator > 0) {
          return _MusicXmlTimeSignature(
            beats: time.numerator,
            beatType: time.denominator,
          );
        }
      }
    }
    return const _MusicXmlTimeSignature(beats: 4, beatType: 4);
  }

  static MidiTrackSummary _summaryForPart(
    MusicXmlDocument document,
    int partIndex,
    int suggestedPartIndex,
  ) {
    final part = document.score.parts[partIndex];
    final notes = _collectPartNotes(part);

    if (notes.isEmpty) {
      return MidiTrackSummary(
        trackIndex: partIndex + 1,
        noteCount: 0,
        minPitch: 0,
        maxPitch: 0,
        durationMs: (document.totalTimeSecs * 1000).ceil(),
        recommended: partIndex + 1 == suggestedPartIndex,
      );
    }

    final pitches = notes.map((n) => n.midi.round()).toList(growable: false);
    return MidiTrackSummary(
      trackIndex: partIndex + 1,
      noteCount: notes.length,
      minPitch: pitches.reduce(math.min),
      maxPitch: pitches.reduce(math.max),
      durationMs: notes.map((n) => n.endMs).reduce(math.max),
      recommended: partIndex + 1 == suggestedPartIndex,
    );
  }

  static int _suggestMelodyPartIndex(MusicXmlDocument document) {
    var bestPart = 1;
    var bestScore = -1.0;

    for (var i = 0; i < document.score.parts.length; i++) {
      final notes = _collectPartNotes(document.score.parts[i]);
      if (notes.isEmpty) {
        continue;
      }

      final pitches = notes.map((n) => n.midi.round()).toList();
      final vocalCount = pitches
          .where(
            (p) =>
                p >= SmartSightSingingMidiConfig.melodyMidiMin &&
                p <= SmartSightSingingMidiConfig.melodyMidiMax,
          )
          .length;
      final lowCount = pitches
          .where(
            (p) => p < SmartSightSingingMidiConfig.lowPitchPenaltyBelowMidi,
          )
          .length;
      final score =
          vocalCount * SmartSightSingingMidiConfig.vocalPitchWeight -
          lowCount * SmartSightSingingMidiConfig.lowPitchPenaltyWeight -
          (notes.length - SmartSightSingingMidiConfig.idealMelodyNoteCount)
                  .abs() *
              SmartSightSingingMidiConfig.noteCountDistancePenalty;

      if (score > bestScore) {
        bestScore = score;
        bestPart = i + 1;
      }
    }

    return bestPart;
  }
}

class _MusicXmlTimeSignature {
  const _MusicXmlTimeSignature({required this.beats, required this.beatType});

  final int beats;
  final int beatType;
}

class _MusicXmlLeadIn {
  const _MusicXmlLeadIn({
    required this.durationMs,
    required this.playbackEvents,
  });

  final int durationMs;
  final List<MidiPlaybackEvent> playbackEvents;

  static _MusicXmlLeadIn? fromTempoAndSignature({
    required double qpm,
    required int beats,
    required int beatType,
  }) {
    if (!qpm.isFinite || qpm <= 0 || beats <= 0 || beatType <= 0) {
      return null;
    }

    final beatMs = (60000 / qpm) * (4 / beatType);
    if (!beatMs.isFinite || beatMs <= 0) return null;

    final beatCount = beats.clamp(1, 12);
    final referenceBeats =
        SmartSightSingingMidiConfig.musicXmlReferencePitchBeats.clamp(1, 4);
    final referenceOffsetMs = (referenceBeats * beatMs).round();
    final events = <MidiPlaybackEvent>[
      MidiPlaybackEvent(
        timeMs: 0,
        pitch: SmartSightSingingMidiConfig.musicXmlReferencePitchMidi,
        velocity: 96,
      ),
      for (var i = 0; i < beatCount; i++)
        MidiPlaybackEvent(
          timeMs: referenceOffsetMs + (i * beatMs).round(),
          pitch: -1,
          velocity: i == 0 ? 127 : 117,
          metronomeCue: i == 0
              ? MusicCompanionMetronomeCue.tone1Accent
              : MusicCompanionMetronomeCue.tone1Regular,
        ),
    ];

    return _MusicXmlLeadIn(
      durationMs: referenceOffsetMs + (beatCount * beatMs).round(),
      playbackEvents: events,
    );
  }
}
