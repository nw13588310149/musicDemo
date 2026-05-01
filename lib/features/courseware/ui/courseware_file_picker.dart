import 'courseware_file_picker_io.dart'
    if (dart.library.html) 'courseware_file_picker_web.dart';

/// Picked file data (in-memory).
class CoursewarePickedFile {
  const CoursewarePickedFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

/// Picks files and returns bytes + filename.
///
/// - `allowMultiple`: only meaningful on web/image selection.
Future<List<CoursewarePickedFile>> pickCoursewareFiles({
  required bool allowMultiple,
}) {
  return pickCoursewareFilesImpl(allowMultiple: allowMultiple);
}

