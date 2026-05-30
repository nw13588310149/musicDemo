import '../../../core/audio/piano_note_assets.dart';

enum MusicCompanionMetronomeCue {
  tone1Accent,
  tone1Regular,
  tone2Accent,
  tone2Regular,
  tone2Special,
  tone3Beat1,
  tone3Beat2,
  tone3Beat3,
  tone3Beat4,
  tone3Beat5,
  tone3Beat6,
  tone3Beat7,
  tone3Beat8,
  tone3Beat9,
  tone3Beat10,
  tone3Beat11,
  tone3Beat12,
}

/// Shared piano map for music companion, music play, smart sight singing, etc.
const Map<String, String> kMusicCompanionPianoAssetByNote = kPianoNoteAssetByNote;

const Map<MusicCompanionMetronomeCue, String>
kMusicCompanionMetronomeAssetByCue = <MusicCompanionMetronomeCue, String>{
  MusicCompanionMetronomeCue.tone1Accent:
      'assets/audio/music_companion/metronome/beat0/audio1.mp3',
  MusicCompanionMetronomeCue.tone1Regular:
      'assets/audio/music_companion/metronome/beat0/audio2.mp3',
  MusicCompanionMetronomeCue.tone2Accent:
      'assets/audio/music_companion/metronome/beat2/2.mp3',
  MusicCompanionMetronomeCue.tone2Regular:
      'assets/audio/music_companion/metronome/beat2/3.mp3',
  MusicCompanionMetronomeCue.tone2Special:
      'assets/audio/music_companion/metronome/beat2/4.mp3',
  MusicCompanionMetronomeCue.tone3Beat1:
      'assets/audio/music_companion/metronome/beat3/1.mp3',
  MusicCompanionMetronomeCue.tone3Beat2:
      'assets/audio/music_companion/metronome/beat3/2.mp3',
  MusicCompanionMetronomeCue.tone3Beat3:
      'assets/audio/music_companion/metronome/beat3/3.mp3',
  MusicCompanionMetronomeCue.tone3Beat4:
      'assets/audio/music_companion/metronome/beat3/4.mp3',
  MusicCompanionMetronomeCue.tone3Beat5:
      'assets/audio/music_companion/metronome/beat3/5.mp3',
  MusicCompanionMetronomeCue.tone3Beat6:
      'assets/audio/music_companion/metronome/beat3/6.mp3',
  MusicCompanionMetronomeCue.tone3Beat7:
      'assets/audio/music_companion/metronome/beat3/7.mp3',
  MusicCompanionMetronomeCue.tone3Beat8:
      'assets/audio/music_companion/metronome/beat3/8.mp3',
  MusicCompanionMetronomeCue.tone3Beat9:
      'assets/audio/music_companion/metronome/beat3/9.mp3',
  MusicCompanionMetronomeCue.tone3Beat10:
      'assets/audio/music_companion/metronome/beat3/10.mp3',
  MusicCompanionMetronomeCue.tone3Beat11:
      'assets/audio/music_companion/metronome/beat3/11.mp3',
  MusicCompanionMetronomeCue.tone3Beat12:
      'assets/audio/music_companion/metronome/beat3/12.mp3',
};
