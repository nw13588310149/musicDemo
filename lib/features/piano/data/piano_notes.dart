class PianoNote {
  const PianoNote({
    required this.id,
    required this.name,
    required this.sampleFile,
    required this.displayNumber,
    required this.solfege,
    required this.octaveMark,
    this.nameSuffix,
    this.highlight = false,
    this.isBlack = false,
  });

  final int id;
  final String name;
  final String sampleFile;
  final int displayNumber;
  final String solfege;
  final String octaveMark;
  final String? nameSuffix;
  final bool highlight;
  final bool isBlack;
}

class PianoNotes {
  PianoNotes._();

  // 与 uniapp notes.js 的映射一致（C2 ~ B6，35 个白键）
  static const List<String> _whiteFiles = <String>[
    'a49.mp3',
    'a50.mp3',
    'a51.mp3',
    'a52.mp3',
    'a53.mp3',
    'a54.mp3',
    'a55.mp3',
    'a56.mp3',
    'a57.mp3',
    'a48.mp3',
    'a81.mp3',
    'a87.mp3',
    'a69.mp3',
    'a82.mp3',
    'a84.mp3',
    'a89.mp3',
    'a85.mp3',
    'a73.mp3',
    'a79.mp3',
    'a80.mp3',
    'a65.mp3',
    'a83.mp3',
    'a68.mp3',
    'a70.mp3',
    'a71.mp3',
    'a72.mp3',
    'a74.mp3',
    'a75.mp3',
    'a76.mp3',
    'a90.mp3',
    'a88.mp3',
    'a67.mp3',
    'a86.mp3',
    'a66.mp3',
    'a78.mp3',
  ];

  // 与 uniapp notes.js 的映射一致（C#2 ~ A#6，25 个黑键）
  static const List<String> _blackFiles = <String>[
    'b49.mp3',
    'b50.mp3',
    'b52.mp3',
    'b53.mp3',
    'b54.mp3',
    'b56.mp3',
    'b57.mp3',
    'b81.mp3',
    'b87.mp3',
    'b69.mp3',
    'b84.mp3',
    'b89.mp3',
    'b73.mp3',
    'b79.mp3',
    'b80.mp3',
    'b83.mp3',
    'b68.mp3',
    'b71.mp3',
    'b72.mp3',
    'b74.mp3',
    'b76.mp3',
    'b90.mp3',
    'b67.mp3',
    'b86.mp3',
    'b66.mp3',
  ];

  static const List<String> _whiteNames = <String>[
    'C2', 'D2', 'E2', 'F2', 'G2', 'A2', 'B2',
    'C3', 'D3', 'E3', 'F3', 'G3', 'A3', 'B3',
    'C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4',
    'C5', 'D5', 'E5', 'F5', 'G5', 'A5', 'B5',
    'C6', 'D6', 'E6', 'F6', 'G6', 'A6', 'B6',
  ];

  static const List<String> _blackNames = <String>[
    'C#2', 'D#2', 'F#2', 'G#2', 'A#2',
    'C#3', 'D#3', 'F#3', 'G#3', 'A#3',
    'C#4', 'D#4', 'F#4', 'G#4', 'A#4',
    'C#5', 'D#5', 'F#5', 'G#5', 'A#5',
    'C#6', 'D#6', 'F#6', 'G#6', 'A#6',
  ];

  static const List<int> _degree = <int>[1, 2, 3, 4, 5, 6, 7];
  static const List<String> _solfege = <String>['C', 'D', 'E', 'F', 'G', 'A', 'B'];

  static List<PianoNote> buildWhite() {
    final List<PianoNote> notes = <PianoNote>[];
    for (int i = 0; i < _whiteNames.length; i++) {
      final int group = i ~/ 7;
      final int inGroup = i % 7;
      notes.add(
        PianoNote(
          id: i + 1,
          name: _whiteNames[i],
          sampleFile: _whiteFiles[i],
          displayNumber: _degree[inGroup],
          solfege: _solfege[inGroup].toLowerCase(),
          octaveMark: _octaveMarkByGroup(group),
          nameSuffix: _nameSuffixByGroup(group),
          highlight: _whiteNames[i] == 'C4',
        ),
      );
    }
    return notes;
  }

  static List<PianoNote> buildBlack() {
    final List<PianoNote> notes = <PianoNote>[];
    for (int i = 0; i < _blackNames.length; i++) {
      notes.add(
        PianoNote(
          id: 100 + i,
          name: _blackNames[i],
          sampleFile: _blackFiles[i],
          displayNumber: 0,
          solfege: '',
          octaveMark: '',
          isBlack: true,
        ),
      );
    }
    return notes;
  }

  static Set<String> allSampleFiles() {
    return <String>{..._whiteFiles, ..._blackFiles};
  }

  static String _octaveMarkByGroup(int group) {
    switch (group) {
      case 0:
        return '..';
      case 1:
        return '.';
      case 2:
        return '';
      case 3:
        return '1.';
      case 4:
        return '1..';
      default:
        return '';
    }
  }

  static String _nameSuffixByGroup(int group) {
    if (group >= 2) {
      return '${group - 1}';
    }
    return '';
  }
}
