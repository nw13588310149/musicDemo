import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cloud_drive_repository.dart';
import 'cloud_drive_state.dart';

final cloudDriveControllerProvider =
    StateNotifierProvider.autoDispose<CloudDriveController, CloudDriveState>((
      ref,
    ) {
      final repository = ref.watch(cloudDriveRepositoryProvider);
      return CloudDriveController(repository: repository);
    });

class CloudDriveController extends StateNotifier<CloudDriveState> {
  CloudDriveController({required CloudDriveRepository repository})
    : _repository = repository,
      super(const CloudDriveState()) {
    unawaited(refresh());
  }

  final CloudDriveRepository _repository;

  static const List<CloudCategoryItem> _fallbackCategories =
      <CloudCategoryItem>[
        CloudCategoryItem(id: -1, name: '声乐教学', count: 85),
        CloudCategoryItem(id: -2, name: '器乐教学', count: 36),
        CloudCategoryItem(id: -3, name: '我的谱例', count: 28),
        CloudCategoryItem(id: -4, name: '钢琴谱例', count: 18),
      ];

  static const List<CloudShareClassItem> _fallbackClasses =
      <CloudShareClassItem>[
        CloudShareClassItem(id: 1001, name: '艺考声乐一班'),
        CloudShareClassItem(id: 1002, name: '艺考器乐二班'),
        CloudShareClassItem(id: 1003, name: '钢琴集训班'),
      ];

  Future<void> refresh() async {
    state = state.copyWith(loading: true, errorMessage: '');

    final categoryResponse = await _repository.getCategoryList();
    final parsedCategories = _parseCategories(categoryResponse.data);
    final categories = parsedCategories.isEmpty
        ? _fallbackCategories
        : parsedCategories;
    final selectedId = _resolveSelectedCategoryId(categories);
    final categoryName = _resolveCategoryName(categories, selectedId);
    final files = await _fetchFiles(
      categoryId: selectedId,
      categoryName: categoryName,
    );

    state = state.copyWith(
      loading: false,
      categories: categories,
      selectedCategoryId: selectedId,
      folders: _buildFolders(categoryName),
      viewMode: CloudDriveViewMode.overview,
      currentFolderName: '',
      files: _sortFiles(files, state.sortType),
      selectedFileIds: const <int>[],
      errorMessage: '',
    );
  }

  Future<void> selectCategory(int categoryId) async {
    if (categoryId == state.selectedCategoryId) {
      return;
    }

    final categoryName = _resolveCategoryName(state.categories, categoryId);
    state = state.copyWith(
      loading: true,
      selectedCategoryId: categoryId,
      viewMode: CloudDriveViewMode.overview,
      currentFolderName: '',
      selectedFileIds: const <int>[],
    );
    final files = await _fetchFiles(
      categoryId: categoryId,
      categoryName: categoryName,
    );
    state = state.copyWith(
      loading: false,
      files: _sortFiles(files, state.sortType),
      folders: _buildFolders(categoryName),
    );
  }

  void openFolder(CloudFolderItem folder) {
    if (folder.isCreateShortcut) {
      return;
    }
    state = state.copyWith(
      viewMode: CloudDriveViewMode.files,
      currentFolderName: folder.title,
      selectedFileIds: const <int>[],
    );
  }

  void backToOverview() {
    state = state.copyWith(
      viewMode: CloudDriveViewMode.overview,
      currentFolderName: '',
      selectedFileIds: const <int>[],
    );
  }

  void setSortType(CloudDriveSortType sortType) {
    state = state.copyWith(
      sortType: sortType,
      files: _sortFiles(state.files, sortType),
    );
  }

  void toggleFileSelection(int fileId) {
    final selected = <int>[...state.selectedFileIds];
    if (selected.contains(fileId)) {
      selected.remove(fileId);
    } else {
      selected.add(fileId);
    }
    state = state.copyWith(selectedFileIds: selected);
  }

  void toggleSelectAllDisplayed(List<int> visibleIds) {
    final allSelected =
        visibleIds.isNotEmpty &&
        visibleIds.every(state.selectedFileIds.contains);
    state = state.copyWith(
      selectedFileIds: allSelected ? const <int>[] : visibleIds,
    );
  }

  void clearSelection() {
    if (state.selectedFileIds.isEmpty) {
      return;
    }
    state = state.copyWith(selectedFileIds: const <int>[]);
  }

  Future<String?> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '请输入分类名称';
    }

    if (_usingFallbackCategories) {
      final created = CloudCategoryItem(
        id: -DateTime.now().microsecondsSinceEpoch,
        name: trimmed,
        count: 0,
      );
      state = state.copyWith(
        categories: <CloudCategoryItem>[...state.categories, created],
      );
      return null;
    }

    state = state.copyWith(busy: true);
    final response = await _repository.addCategory(trimmed);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return response.msg.isEmpty ? '新增分类失败' : response.msg;
    }

    await refresh();
    return null;
  }

  Future<String?> deleteCategory(int id) async {
    if (id < 0) {
      final categories = state.categories
          .where((item) => item.id != id)
          .toList();
      final safeCategories = categories.isEmpty
          ? _fallbackCategories
          : categories;
      final nextId = _resolveSelectedCategoryId(safeCategories);
      state = state.copyWith(
        categories: safeCategories,
        selectedCategoryId: nextId,
        folders: _buildFolders(_resolveCategoryName(safeCategories, nextId)),
        viewMode: CloudDriveViewMode.overview,
        currentFolderName: '',
        selectedFileIds: const <int>[],
      );
      return null;
    }

    state = state.copyWith(busy: true);
    final response = await _repository.deleteCategory(id);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return response.msg.isEmpty ? '删除分类失败' : response.msg;
    }
    await refresh();
    return null;
  }

  void renameCategoryLocal(int id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final categories = state.categories.map((item) {
      if (item.id != id) {
        return item;
      }
      return CloudCategoryItem(id: item.id, name: trimmed, count: item.count);
    }).toList();
    state = state.copyWith(
      categories: categories,
      folders: _buildFolders(
        _resolveCategoryName(categories, state.selectedCategoryId),
      ),
    );
  }

  void duplicateCategoryLocal(int id) {
    final source = state.categories.where((item) => item.id == id).firstOrNull;
    if (source == null) {
      return;
    }
    final duplicated = CloudCategoryItem(
      id: -DateTime.now().microsecondsSinceEpoch,
      name: '${source.name} 副本',
      count: source.count,
    );
    state = state.copyWith(
      categories: <CloudCategoryItem>[...state.categories, duplicated],
    );
  }

  void createLocalFolder(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final folders = <CloudFolderItem>[
      CloudFolderItem(
        id: DateTime.now().microsecondsSinceEpoch,
        title: trimmed,
        sizeLabel: '0MB',
        dateLabel: '2026.04.16',
      ),
      ...state.folders,
    ];
    state = state.copyWith(folders: folders);
  }

  void renameFolderLocal(int folderId, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final folders = state.folders.map((item) {
      if (item.id != folderId) {
        return item;
      }
      return item.copyWith(title: trimmed);
    }).toList();
    final currentFolder = folders
        .where((item) => item.id == folderId)
        .firstOrNull;
    state = state.copyWith(
      folders: folders,
      currentFolderName: state.currentFolderName.isEmpty
          ? ''
          : currentFolder?.title ?? state.currentFolderName,
    );
  }

  void duplicateFolderLocal(int folderId) {
    final folder = state.folders
        .where((item) => item.id == folderId)
        .firstOrNull;
    if (folder == null) {
      return;
    }
    final duplicated = folder.copyWith(
      id: DateTime.now().microsecondsSinceEpoch,
      title: '${folder.title} 副本',
    );
    state = state.copyWith(
      folders: <CloudFolderItem>[duplicated, ...state.folders],
    );
  }

  void deleteFolderLocal(int folderId) {
    final removedFolder = state.folders
        .where((item) => item.id == folderId)
        .firstOrNull;
    final folders = state.folders.where((item) => item.id != folderId).toList();
    final isCurrentFolder =
        removedFolder != null &&
        removedFolder.title == state.currentFolderName &&
        state.isFolderView;
    state = state.copyWith(
      folders: folders,
      viewMode: isCurrentFolder ? CloudDriveViewMode.overview : state.viewMode,
      currentFolderName: isCurrentFolder ? '' : state.currentFolderName,
    );
  }

  Future<String?> addCourseware({
    required String title,
    required CloudFileType type,
    required String audioUrl,
    required String imageInput,
  }) async {
    if (state.selectedCategoryId == 0) {
      return '请先创建分类';
    }

    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      return '请输入资料标题';
    }

    final cleanAudio = audioUrl.trim();
    final images = _splitImages(imageInput);

    if (type == CloudFileType.audio && cleanAudio.isEmpty) {
      return '请填写音频文件链接';
    }
    if (type == CloudFileType.score && images.isEmpty) {
      return '请填写图片链接';
    }
    if (type == CloudFileType.courseware && cleanAudio.isEmpty) {
      return '请填写课件文件链接';
    }

    if (state.selectedCategoryId < 0) {
      final created = CloudFileItem(
        id: DateTime.now().microsecondsSinceEpoch,
        title: cleanTitle,
        type: type,
        audioUrl: cleanAudio,
        imageUrls: images,
        dateLabel: '04.16.2026',
        sizeLabel: type == CloudFileType.audio ? '18MB' : '10MB',
      );
      final files = _sortFiles(<CloudFileItem>[
        created,
        ...state.files,
      ], state.sortType);
      final categories = state.categories.map((item) {
        if (item.id != state.selectedCategoryId) {
          return item;
        }
        return CloudCategoryItem(
          id: item.id,
          name: item.name,
          count: item.count + 1,
        );
      }).toList();
      state = state.copyWith(files: files, categories: categories);
      return null;
    }

    state = state.copyWith(busy: true);
    final response = await _repository.addCourseware(
      categoryId: state.selectedCategoryId,
      title: cleanTitle,
      type: type.value,
      audioUrl: cleanAudio,
      imageJson: jsonEncode(images),
    );
    state = state.copyWith(busy: false);

    if (!response.isSuccess) {
      return response.msg.isEmpty ? '上传资料失败' : response.msg;
    }

    await _refreshFilesOnly();
    return null;
  }

  Future<String?> deleteCourseware(int id) async {
    if (id <= 0 || state.selectedCategoryId < 0) {
      final files = state.files.where((item) => item.id != id).toList();
      final selected = state.selectedFileIds
          .where((item) => item != id)
          .toList();
      final categories = state.categories.map((item) {
        if (item.id != state.selectedCategoryId) {
          return item;
        }
        return CloudCategoryItem(
          id: item.id,
          name: item.name,
          count: item.count > 0 ? item.count - 1 : 0,
        );
      }).toList();
      state = state.copyWith(
        files: files,
        selectedFileIds: selected,
        categories: categories,
      );
      return null;
    }

    state = state.copyWith(busy: true);
    final response = await _repository.deleteCourseware(id);
    state = state.copyWith(busy: false);

    if (!response.isSuccess) {
      return response.msg.isEmpty ? '删除资料失败' : response.msg;
    }

    await _refreshFilesOnly();
    return null;
  }

  Future<List<CloudShareClassItem>> fetchShareClasses() async {
    final response = await _repository.getClassList();
    if (!response.isSuccess || response.data is! List) {
      return _fallbackClasses;
    }

    final result = <CloudShareClassItem>[];
    for (final item in response.data as List) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final id = _toInt(item['id']);
      final name = item['name']?.toString() ?? '';
      if (id <= 0 || name.isEmpty) {
        continue;
      }
      result.add(CloudShareClassItem(id: id, name: name));
    }
    return result.isEmpty ? _fallbackClasses : result;
  }

  Future<String?> shareCourseware({
    required CloudFileItem file,
    required List<int> classIds,
  }) async {
    if (classIds.isEmpty) {
      return '请先选择要分享的班级';
    }

    if (file.id <= 0 || state.selectedCategoryId < 0) {
      return null;
    }

    state = state.copyWith(busy: true);
    for (final classId in classIds) {
      final response = await _repository.sendShareMessage(
        classId: classId,
        content: jsonEncode(file.toSharePayload()),
      );
      if (!response.isSuccess) {
        state = state.copyWith(busy: false);
        return response.msg.isEmpty ? '分享失败' : response.msg;
      }
    }
    state = state.copyWith(busy: false);
    return null;
  }

  void togglePlaying(int fileId) {
    final updated = state.files.map((item) {
      if (item.id == fileId) {
        return item.copyWith(isPlaying: !item.isPlaying);
      }
      return item.copyWith(isPlaying: false);
    }).toList();
    state = state.copyWith(files: updated);
  }

  List<String> _splitImages(String input) {
    return input
        .split(RegExp(r'[\n,，、\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  int _resolveSelectedCategoryId(List<CloudCategoryItem> categories) {
    if (categories.isEmpty) {
      return 0;
    }
    final current = state.selectedCategoryId;
    final exists = categories.any((e) => e.id == current);
    return exists ? current : categories.first.id;
  }

  Future<void> _refreshFilesOnly() async {
    final categoryResponse = await _repository.getCategoryList();
    final parsedCategories = _parseCategories(categoryResponse.data);
    final categories = parsedCategories.isEmpty
        ? _fallbackCategories
        : parsedCategories;
    final selectedId = _resolveSelectedCategoryId(categories);
    final categoryName = _resolveCategoryName(categories, selectedId);
    final files = await _fetchFiles(
      categoryId: selectedId,
      categoryName: categoryName,
    );
    state = state.copyWith(
      categories: categories,
      selectedCategoryId: selectedId,
      files: _sortFiles(files, state.sortType),
      folders: _buildFolders(categoryName),
      selectedFileIds: const <int>[],
      errorMessage: '',
    );
  }

  Future<List<CloudFileItem>> _fetchFiles({
    required int categoryId,
    required String categoryName,
  }) async {
    final fallbackFiles = _buildFallbackFiles(categoryName);
    if (categoryId <= 0) {
      return fallbackFiles;
    }

    final response = await _repository.getCoursewareList(categoryId);
    if (!response.isSuccess || response.data is! List) {
      return fallbackFiles;
    }

    final result = <CloudFileItem>[];
    for (final item in response.data as List) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      result.add(
        CloudFileItem(
          id: _toInt(item['id']),
          title: item['title']?.toString() ?? '',
          type: CloudFileType.fromValue(item['param1']),
          audioUrl: item['param2']?.toString() ?? '',
          imageUrls: _parseImageUrls(item['param3']),
          sizeLabel: _resolveSizeLabel(item),
          dateLabel: _resolveDateLabel(item),
        ),
      );
    }

    return result.isEmpty ? fallbackFiles : result;
  }

  List<CloudCategoryItem> _parseCategories(dynamic data) {
    if (data is! List) {
      return const <CloudCategoryItem>[];
    }

    final result = <CloudCategoryItem>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final id = _toInt(item['id']);
      final name = item['name']?.toString() ?? '';
      if (id <= 0 || name.isEmpty) {
        continue;
      }
      result.add(
        CloudCategoryItem(id: id, name: name, count: _toInt(item['count'])),
      );
    }

    return result;
  }

  List<String> _parseImageUrls(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }

    final text = value?.toString() ?? '';
    if (text.isEmpty || text == 'null') {
      return const <String>[];
    }

    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty && e != 'null')
            .toList();
      }
    } catch (_) {
      // Ignore invalid JSON and fallback to a single URL.
    }

    return <String>[text];
  }

  List<CloudFileItem> _sortFiles(
    List<CloudFileItem> files,
    CloudDriveSortType sortType,
  ) {
    final sorted = <CloudFileItem>[...files];
    switch (sortType) {
      case CloudDriveSortType.name:
        sorted.sort((a, b) => a.title.compareTo(b.title));
        break;
      case CloudDriveSortType.time:
        sorted.sort((a, b) => b.dateLabel.compareTo(a.dateLabel));
        break;
      case CloudDriveSortType.size:
        sorted.sort(
          (a, b) => _parseSizeNumber(
            b.sizeLabel,
          ).compareTo(_parseSizeNumber(a.sizeLabel)),
        );
        break;
      case CloudDriveSortType.type:
        sorted.sort((a, b) => a.type.value.compareTo(b.type.value));
        break;
    }
    return sorted;
  }

  List<CloudFolderItem> _buildFolders(String categoryName) {
    final titles = switch (categoryName) {
      '器乐教学' => <String>[
        '器乐基础训练',
        '艺考器乐教学第十课',
        '新建文件夹',
        '器乐学习资料汇总',
        '演奏技巧合集',
        '常用器乐伴奏',
        '新建文件夹',
        '备考资料归档',
      ],
      '我的谱例' => <String>[
        '谱例学习第三期汇总',
        '艺考器乐教学第十一课',
        '新建文件夹',
        '谱例学习第三期汇总',
        '浅唱谱例',
        '青川谱例',
        '新建文件夹',
        '孤城谱例',
      ],
      '钢琴谱例' => <String>[
        '钢琴基础练习',
        '车尔尼 599',
        '新建文件夹',
        '哈农练习',
        '拜厄教程',
        '视奏练习',
        '新建文件夹',
        '考级曲目',
      ],
      _ => <String>[
        '谱例学习第三期汇总',
        '艺考声乐教学第十课',
        '新建文件夹',
        '声乐课堂作业',
        '浅唱谱例',
        '青川谱例',
        '新建文件夹',
        '孤城谱例',
      ],
    };

    return List<CloudFolderItem>.generate(titles.length, (index) {
      final title = titles[index];
      return CloudFolderItem(
        id: index + 1,
        title: title,
        isCreateShortcut: title == '新建文件夹',
        sizeLabel: index.isEven ? '10MB' : '18MB',
        dateLabel: '2026.04.${(index + 7).toString().padLeft(2, '0')}',
      );
    });
  }

  List<CloudFileItem> _buildFallbackFiles(String categoryName) {
    switch (categoryName) {
      case '器乐教学':
        return const <CloudFileItem>[
          CloudFileItem(
            id: -201,
            title: '艺考器乐教学第十课',
            type: CloudFileType.courseware,
            audioUrl: 'https://example.com/instrument-course.pdf',
            imageUrls: <String>[],
            dateLabel: '04.07.2026',
            sizeLabel: '10MB',
          ),
          CloudFileItem(
            id: -202,
            title: '器乐备考示范图',
            type: CloudFileType.score,
            audioUrl: '',
            imageUrls: <String>[],
            dateLabel: '04.08.2026',
            sizeLabel: '6MB',
          ),
          CloudFileItem(
            id: -203,
            title: '器乐节奏训练音频',
            type: CloudFileType.audio,
            audioUrl: 'https://example.com/instrument-practice.wav',
            imageUrls: <String>[],
            dateLabel: '04.09.2026',
            sizeLabel: '18MB',
          ),
          CloudFileItem(
            id: -204,
            title: '乐器演奏技巧总结',
            type: CloudFileType.courseware,
            audioUrl: 'https://example.com/skills.pdf',
            imageUrls: <String>[],
            dateLabel: '04.10.2026',
            sizeLabel: '12MB',
          ),
        ];
      case '钢琴谱例':
        return const <CloudFileItem>[
          CloudFileItem(
            id: -301,
            title: '车尔尼 599',
            type: CloudFileType.score,
            audioUrl: '',
            imageUrls: <String>[],
            dateLabel: '04.07.2026',
            sizeLabel: '8MB',
          ),
          CloudFileItem(
            id: -302,
            title: '哈农练习',
            type: CloudFileType.score,
            audioUrl: '',
            imageUrls: <String>[],
            dateLabel: '04.08.2026',
            sizeLabel: '7MB',
          ),
          CloudFileItem(
            id: -303,
            title: '拜厄教程',
            type: CloudFileType.courseware,
            audioUrl: 'https://example.com/beyer.pdf',
            imageUrls: <String>[],
            dateLabel: '04.11.2026',
            sizeLabel: '11MB',
          ),
          CloudFileItem(
            id: -304,
            title: '钢琴示范音频',
            type: CloudFileType.audio,
            audioUrl: 'https://example.com/piano-demo.wav',
            imageUrls: <String>[],
            dateLabel: '04.12.2026',
            sizeLabel: '20MB',
          ),
        ];
      case '我的谱例':
        return const <CloudFileItem>[
          CloudFileItem(
            id: -101,
            title: '谱例学习第三期汇总',
            type: CloudFileType.courseware,
            audioUrl: 'https://example.com/score-summary.pdf',
            imageUrls: <String>[],
            dateLabel: '04.07.2026',
            sizeLabel: '10MB',
          ),
          CloudFileItem(
            id: -102,
            title: '浅唱谱例',
            type: CloudFileType.score,
            audioUrl: '',
            imageUrls: <String>[],
            dateLabel: '04.08.2026',
            sizeLabel: '7MB',
          ),
          CloudFileItem(
            id: -103,
            title: '青川谱例',
            type: CloudFileType.score,
            audioUrl: '',
            imageUrls: <String>[],
            dateLabel: '04.09.2026',
            sizeLabel: '7MB',
          ),
          CloudFileItem(
            id: -104,
            title: '孤城谱例',
            type: CloudFileType.score,
            audioUrl: '',
            imageUrls: <String>[],
            dateLabel: '04.10.2026',
            sizeLabel: '7MB',
          ),
        ];
      default:
        return const <CloudFileItem>[
          CloudFileItem(
            id: -1,
            title: '艺考声乐教学第十课',
            type: CloudFileType.courseware,
            audioUrl: 'https://example.com/vocal-class.pdf',
            imageUrls: <String>[],
            dateLabel: '04.07.2026',
            sizeLabel: '10MB',
          ),
          CloudFileItem(
            id: -2,
            title: '浅唱谱例',
            type: CloudFileType.score,
            audioUrl: '',
            imageUrls: <String>[],
            dateLabel: '04.08.2026',
            sizeLabel: '7MB',
          ),
          CloudFileItem(
            id: -3,
            title: '练耳示范音频',
            type: CloudFileType.audio,
            audioUrl: 'https://example.com/ear-training.wav',
            imageUrls: <String>[],
            dateLabel: '04.09.2026',
            sizeLabel: '18MB',
          ),
          CloudFileItem(
            id: -4,
            title: '声乐课程总结',
            type: CloudFileType.courseware,
            audioUrl: 'https://example.com/vocal-summary.pdf',
            imageUrls: <String>[],
            dateLabel: '04.10.2026',
            sizeLabel: '12MB',
          ),
        ];
    }
  }

  String _resolveCategoryName(List<CloudCategoryItem> categories, int id) {
    return categories.where((item) => item.id == id).firstOrNull?.name ??
        '声乐教学';
  }

  String _resolveSizeLabel(Map<String, dynamic> item) {
    final candidates = <dynamic>[
      item['sizeLabel'],
      item['size'],
      item['fileSize'],
      item['param4'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty && value != 'null') {
        return value;
      }
    }
    return '10MB';
  }

  String _resolveDateLabel(Map<String, dynamic> item) {
    final candidates = <dynamic>[
      item['createTime'],
      item['createDate'],
      item['updateTime'],
      item['param5'],
    ];
    for (final candidate in candidates) {
      final raw = candidate?.toString().trim() ?? '';
      if (raw.isEmpty || raw == 'null') {
        continue;
      }
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        final month = parsed.month.toString().padLeft(2, '0');
        final day = parsed.day.toString().padLeft(2, '0');
        return '$month.$day.${parsed.year}';
      }
      return raw;
    }
    return '04.07.2026';
  }

  double _parseSizeNumber(String value) {
    final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(value);
    return double.tryParse(match?.group(1) ?? '') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool get _usingFallbackCategories =>
      state.categories.isEmpty || state.categories.every((item) => item.id < 0);
}

extension _FirstWhereOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
