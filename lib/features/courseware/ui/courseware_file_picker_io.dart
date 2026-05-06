import 'package:file_picker/file_picker.dart';

import 'courseware_file_picker.dart';

Future<List<CoursewarePickedFile>> pickCoursewareFilesImpl({
  required bool allowMultiple,
}) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: allowMultiple,
    withData: false,
  );
  final files = result?.files ?? const <PlatformFile>[];
  if (files.isEmpty) {
    return const <CoursewarePickedFile>[];
  }
  return files
      .where((f) => f.path != null && f.path!.isNotEmpty)
      .map(
        (f) => CoursewarePickedFile(name: f.name, path: f.path, size: f.size),
      )
      .toList();
}
