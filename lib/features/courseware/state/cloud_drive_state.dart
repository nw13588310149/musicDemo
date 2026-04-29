import 'dart:convert';

enum CloudFileType {
  audio(1),
  score(2),
  courseware(3);

  const CloudFileType(this.value);

  final int value;

  static CloudFileType fromValue(dynamic value) {
    final intValue = value is int
        ? value
        : int.tryParse(value?.toString() ?? '');
    return switch (intValue) {
      2 => CloudFileType.score,
      3 => CloudFileType.courseware,
      _ => CloudFileType.audio,
    };
  }

  String get label {
    return switch (this) {
      CloudFileType.audio => '音频',
      CloudFileType.score => '谱例',
      CloudFileType.courseware => '课件',
    };
  }
}

enum CloudDriveViewMode { overview, files }

enum CloudDriveSortType {
  name('名称'),
  time('时间'),
  size('大小'),
  type('类型');

  const CloudDriveSortType(this.label);

  final String label;
}

enum CloudUploadKind {
  image('图片'),
  score('谱例'),
  courseware('课件');

  const CloudUploadKind(this.label);

  final String label;
}

class CloudCategoryItem {
  const CloudCategoryItem({
    required this.id,
    required this.name,
    required this.count,
  });

  final int id;
  final String name;
  final int count;

  String get subtitle => '已存储 $count 个文件';
}

class CloudFolderItem {
  const CloudFolderItem({
    required this.id,
    required this.title,
    this.sizeLabel = '10MB',
    this.dateLabel = '2026.04.07',
    this.isCreateShortcut = false,
  });

  final int id;
  final String title;
  final String sizeLabel;
  final String dateLabel;
  final bool isCreateShortcut;

  CloudFolderItem copyWith({
    int? id,
    String? title,
    String? sizeLabel,
    String? dateLabel,
    bool? isCreateShortcut,
  }) {
    return CloudFolderItem(
      id: id ?? this.id,
      title: title ?? this.title,
      sizeLabel: sizeLabel ?? this.sizeLabel,
      dateLabel: dateLabel ?? this.dateLabel,
      isCreateShortcut: isCreateShortcut ?? this.isCreateShortcut,
    );
  }
}

class CloudFileItem {
  const CloudFileItem({
    required this.id,
    required this.title,
    required this.type,
    required this.audioUrl,
    required this.imageUrls,
    this.dateLabel = '04.07.2026',
    this.sizeLabel = '10MB',
    this.isPlaying = false,
  });

  final int id;
  final String title;
  final CloudFileType type;
  final String audioUrl;
  final List<String> imageUrls;
  final String dateLabel;
  final String sizeLabel;
  final bool isPlaying;

  CloudFileItem copyWith({
    bool? isPlaying,
    String? title,
    CloudFileType? type,
    String? audioUrl,
    List<String>? imageUrls,
    String? dateLabel,
    String? sizeLabel,
  }) {
    return CloudFileItem(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      audioUrl: audioUrl ?? this.audioUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      dateLabel: dateLabel ?? this.dateLabel,
      sizeLabel: sizeLabel ?? this.sizeLabel,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }

  Map<String, dynamic> toSharePayload() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'param1': '${type.value}',
      'param2': audioUrl,
      'param3': jsonEncode(imageUrls),
    };
  }
}

class CloudShareClassItem {
  const CloudShareClassItem({
    required this.id,
    required this.name,
    this.selected = false,
  });

  final int id;
  final String name;
  final bool selected;

  CloudShareClassItem copyWith({bool? selected}) {
    return CloudShareClassItem(
      id: id,
      name: name,
      selected: selected ?? this.selected,
    );
  }
}

class CloudDriveState {
  const CloudDriveState({
    this.loading = true,
    this.busy = false,
    this.errorMessage = '',
    this.categories = const [],
    this.selectedCategoryId = 0,
    this.folders = const [],
    this.viewMode = CloudDriveViewMode.overview,
    this.currentFolderName = '',
    this.files = const [],
    this.selectedFileIds = const [],
    this.sortType = CloudDriveSortType.size,
  });

  final bool loading;
  final bool busy;
  final String errorMessage;
  final List<CloudCategoryItem> categories;
  final int selectedCategoryId;
  final List<CloudFolderItem> folders;
  final CloudDriveViewMode viewMode;
  final String currentFolderName;
  final List<CloudFileItem> files;
  final List<int> selectedFileIds;
  final CloudDriveSortType sortType;

  CloudCategoryItem? get selectedCategory {
    for (final item in categories) {
      if (item.id == selectedCategoryId) {
        return item;
      }
    }
    return categories.isEmpty ? null : categories.first;
  }

  bool get isFolderView => viewMode == CloudDriveViewMode.files;

  CloudDriveState copyWith({
    bool? loading,
    bool? busy,
    String? errorMessage,
    List<CloudCategoryItem>? categories,
    int? selectedCategoryId,
    List<CloudFolderItem>? folders,
    CloudDriveViewMode? viewMode,
    String? currentFolderName,
    List<CloudFileItem>? files,
    List<int>? selectedFileIds,
    CloudDriveSortType? sortType,
  }) {
    return CloudDriveState(
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      errorMessage: errorMessage ?? this.errorMessage,
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      folders: folders ?? this.folders,
      viewMode: viewMode ?? this.viewMode,
      currentFolderName: currentFolderName ?? this.currentFolderName,
      files: files ?? this.files,
      selectedFileIds: selectedFileIds ?? this.selectedFileIds,
      sortType: sortType ?? this.sortType,
    );
  }
}
