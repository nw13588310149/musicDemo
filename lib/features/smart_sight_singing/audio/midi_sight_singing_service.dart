import 'dart:math' as math;
import 'dart:typed_data';

import 'ktv_pitch_guide.dart';
import 'midi_file_parser.dart';
import 'pitch_track.dart';

/// MIDI 播放事件（钢琴短音）。
class MidiPlaybackEvent {
  const MidiPlaybackEvent({
    required this.timeMs,
    required this.pitch,
    required this.velocity,
  });

  final int timeMs;
  final int pitch;
  final int velocity;
}

/// 智能视唱 MIDI 解析结果。
class MidiSightSingingBundle {
  const MidiSightSingingBundle({
    required this.track,
    required this.playbackEvents,
    required this.melodyTrackIndex,
    required this.totalMs,
  });

  final PitchTrack track;
  final List<MidiPlaybackEvent> playbackEvents;
  final int melodyTrackIndex;
  final int totalMs;
}

class MidiSightSingingException implements Exception {
  MidiSightSingingException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract final class MidiSightSingingService {
  static const int _percussionChannel = 9;
  static const int _melodyMidiMin = 55;
  static const int _melodyMidiMax = 84;

  static MidiSightSingingBundle fromBytes(Uint8List bytes) {
    final parsed = MidiFileParser.parse(bytes);
    if (parsed.notes.isEmpty) {
      throw MidiSightSingingException('MIDI 中没有可播放的音符。');
    }

    final melodyTrackIndex = _pickMelodyTrackIndex(parsed);
    final melodyNotes = parsed.notesOnTrack(melodyTrackIndex);
    if (melodyNotes.isEmpty) {
      throw MidiSightSingingException('未找到可用的主旋律轨（track $melodyTrackIndex）。');
    }

    final notes = melodyNotes
        .where((n) => n.endMs > n.startMs && n.pitch > 0)
        .map(
          (n) => KtvNoteSegment(
            startMs: n.startMs.round(),
            endMs: math.max(n.endMs.round(), n.startMs.round() + 40),
            midi: n.pitch.toDouble(),
          ),
        )
        .toList(growable: false);

    if (notes.isEmpty) {
      throw MidiSightSingingException('主旋律轨没有有效音符。');
    }

    final range = KtvPitchGuideBuilder.rangeForNotes(notes);
    final totalMs = parsed.totalMs.ceil();

    final track = PitchTrack(
      frames: const <PitchFrame>[],
      notes: notes,
      totalMs: totalMs,
      frameStepMs: 23,
      minMidi: range.minMidi,
      maxMidi: range.maxMidi,
    );

    final playbackEvents = parsed.notes
        .where(
          (n) =>
              n.channel != _percussionChannel &&
              n.pitch > 0 &&
              n.velocity > 0 &&
              n.endMs > n.startMs,
        )
        .map(
          (n) => MidiPlaybackEvent(
            timeMs: n.startMs.round(),
            pitch: n.pitch,
            velocity: n.velocity,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));

    return MidiSightSingingBundle(
      track: track,
      playbackEvents: playbackEvents,
      melodyTrackIndex: melodyTrackIndex,
      totalMs: totalMs,
    );
  }

  static int _pickMelodyTrackIndex(ParsedMidiFile parsed) {
    var bestTrack = 1;
    var bestScore = -1.0;

    for (var track = 1; track <= parsed.tracks; track++) {
      final notes = parsed.notesOnTrack(track);
      if (notes.isEmpty) continue;

      final pitches = notes.map((n) => n.pitch).toList();
      final vocalCount =
          pitches.where((p) => p >= _melodyMidiMin && p <= _melodyMidiMax).length;
      final lowCount = pitches.where((p) => p < 50).length;
      final score = vocalCount * 2.0 -
          lowCount * 1.5 -
          (notes.length - 180).abs() * 0.08;

      if (score > bestScore) {
        bestScore = score;
        bestTrack = track;
      }
    }

    return bestTrack;
  }
}
