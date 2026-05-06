import 'dart:typed_data';

import 'courseware_file_picker_io.dart'
    if (dart.library.html) 'courseware_file_picker_web.dart';

/// Picked file data.
class CoursewarePickedFile {
  const CoursewarePickedFile({
    required this.name,
    this.bytes,
    this.path,
    this.size,
  });

  final String name;
  final Uint8List? bytes;
  final String? path;
  final int? size;

  bool get hasBytes => bytes != null && bytes!.isNotEmpty;
  bool get hasPath => path != null && path!.isNotEmpty;
  bool get canUpload => hasBytes || hasPath;
}

/// Picks files and returns filename + either bytes (web) or a local path (native).
///
/// - `allowMultiple`: only meaningful on web/image selection.
Future<List<CoursewarePickedFile>> pickCoursewareFiles({
  required bool allowMultiple,
}) {
  return pickCoursewareFilesImpl(allowMultiple: allowMultiple);
}
