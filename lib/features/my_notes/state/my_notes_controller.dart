import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../data/my_notes_repository.dart';
import 'my_notes_state.dart';

final myNotesControllerProvider =
    StateNotifierProvider.autoDispose<MyNotesController, MyNotesState>((ref) {
      final repository = ref.watch(myNotesRepositoryProvider);
      return MyNotesController(repository: repository);
    });

class MyNotesController extends StateNotifier<MyNotesState> {
  MyNotesController({required MyNotesRepository repository})
    : _repository = repository,
      super(const MyNotesState()) {
    unawaited(refresh());
  }

  final MyNotesRepository _repository;

  Future<void> refresh() async {
    try {
      state = state.copyWith(loading: true, clearError: true);

      final responses = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getCategories(),
        _repository.getNoteCount(),
      ]);

      final categories = _parseCategories(
        responses[0].data,
        totalCount: _toInt(responses[1].data),
      );
      final selectedCategoryId = _resolveInitialCategoryId(
        categories,
        state.selectedCategoryId,
      );
      final notesResponse = selectedCategoryId > 0
          ? await _repository
                .getNotes(categoryId: selectedCategoryId)
                .timeout(
                  const Duration(seconds: 8),
                  onTimeout: () =>
                      const ApiResponse(code: -1, msg: '加载笔记超时', data: null),
                )
          : const ApiResponse(code: 0, msg: '', data: <dynamic>[]);
      final notes = _parseNotes(notesResponse.data);

      state = state.copyWith(
        loading: false,
        categories: categories,
        selectedCategoryId: selectedCategoryId,
        notes: notes,
        errorMessage: notesResponse.isSuccess
            ? null
            : _fallbackMessage(notesResponse.msg, '加载笔记失败'),
      );
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '加载笔记失败，请稍后重试');
    }
  }

  Future<void> selectCategory(int categoryId) async {
    if (categoryId == state.selectedCategoryId &&
        state.view == MyNotesView.list) {
      return;
    }

    try {
      state = state.copyWith(
        selectedCategoryId: categoryId,
        loading: true,
        view: MyNotesView.list,
        clearError: true,
      );

      final response = categoryId > 0
          ? await _repository
                .getNotes(categoryId: categoryId)
                .timeout(
                  const Duration(seconds: 8),
                  onTimeout: () =>
                      const ApiResponse(code: -1, msg: '加载笔记超时', data: null),
                )
          : const ApiResponse(code: 0, msg: '', data: <dynamic>[]);
      state = state.copyWith(
        loading: false,
        notes: _parseNotes(response.data),
        errorMessage: response.isSuccess
            ? null
            : _fallbackMessage(response.msg, '加载笔记失败'),
        clearEditingNote: true,
        clearEditorBackgroundImageUrl: true,
        strokes: const <NoteStroke>[],
      );
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '加载笔记失败，请稍后重试');
    }
  }

  void selectFilter(MyNotesFilter filter) {
    if (filter == state.activeFilter) {
      return;
    }
    state = state.copyWith(activeFilter: filter);
  }

  Future<String?> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '请输入笔记分类名称';
    }

    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.addCategory(trimmed);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, '新增分类失败');
    }
    await refresh();
    return null;
  }

  Future<String?> deleteCategory(int id) async {
    if (id <= 0) {
      return '默认分类不能删除';
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.deleteCategory(id);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, '删除分类失败');
    }
    await refresh();
    return null;
  }

  Future<String?> deleteNote(int id) async {
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.deleteNote(id);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _fallbackMessage(response.msg, '删除笔记失败');
    }
    await selectCategory(state.selectedCategoryId);
    return null;
  }

  String? beginCreateNote() {
    if (_writeCategoryId <= 0) {
      return '请先新增笔记分类';
    }
    state = state.copyWith(
      view: MyNotesView.template,
      draftTitle: '笔记名称',
      paperType: NotePaperType.blank,
      strokes: const <NoteStroke>[],
      clearEditingNote: true,
      clearEditorBackgroundImageUrl: true,
      clearError: true,
    );
    return null;
  }

  void backToList() {
    state = state.copyWith(
      view: MyNotesView.list,
      strokes: const <NoteStroke>[],
      clearEditingNote: true,
      clearEditorBackgroundImageUrl: true,
      clearError: true,
    );
  }

  void chooseTemplate(NotePaperType type) {
    state = state.copyWith(
      view: MyNotesView.editor,
      paperType: type,
      draftTitle: state.draftTitle.isEmpty ? '笔记名称' : state.draftTitle,
      strokes: const <NoteStroke>[],
      clearEditingNote: true,
      clearEditorBackgroundImageUrl: true,
    );
  }

  void openExistingNote(NoteEntry note) {
    state = state.copyWith(
      view: MyNotesView.editor,
      draftTitle: note.title,
      paperType: note.paperType,
      editingNote: note,
      editorBackgroundImageUrl: note.imageUrl.isEmpty ? null : note.imageUrl,
      strokes: const <NoteStroke>[],
      clearError: true,
    );
  }

  void updateDraftTitle(String title) {
    state = state.copyWith(draftTitle: title);
  }

  void setSelectedColor(Color color) {
    state = state.copyWith(selectedColor: color);
  }

  void setStrokeWidth(double width) {
    state = state.copyWith(strokeWidth: width.clamp(2, 32));
  }

  void addStroke(List<Offset> points) {
    if (points.length < 2) {
      return;
    }
    state = state.copyWith(
      strokes: <NoteStroke>[
        ...state.strokes,
        NoteStroke(
          color: state.selectedColor,
          width: state.strokeWidth,
          points: points,
        ),
      ],
    );
  }

  void undoStroke() {
    if (state.strokes.isEmpty) {
      return;
    }
    state = state.copyWith(
      strokes: state.strokes.sublist(0, state.strokes.length - 1),
    );
  }

  void clearCanvas() {
    if (state.strokes.isEmpty) {
      return;
    }
    state = state.copyWith(strokes: const <NoteStroke>[]);
  }

  Future<String?> saveCurrentNote(Uint8List bytes) async {
    final categoryId = _writeCategoryId;
    if (categoryId <= 0) {
      return '请先新增笔记分类';
    }

    state = state.copyWith(busy: true, clearError: true);
    final uploadResponse = await _repository.uploadNoteImage(
      bytes: bytes,
      filename: 'note_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    if (!uploadResponse.isSuccess) {
      state = state.copyWith(busy: false);
      return _fallbackMessage(uploadResponse.msg, '上传笔记失败');
    }

    final imageUrl = uploadResponse.data?.toString() ?? '';
    if (imageUrl.isEmpty) {
      state = state.copyWith(busy: false);
      return '上传结果异常，请稍后重试';
    }

    final saveResponse = await _repository.saveNote(
      categoryId: categoryId,
      paperType: state.paperType.value,
      title: state.draftTitle.trim().isEmpty
          ? '笔记名称'
          : state.draftTitle.trim(),
      imageUrl: imageUrl,
    );
    if (!saveResponse.isSuccess) {
      state = state.copyWith(busy: false);
      return _fallbackMessage(saveResponse.msg, '保存笔记失败');
    }

    final editingId = state.editingNote?.id ?? 0;
    if (editingId > 0) {
      unawaited(_repository.deleteNote(editingId));
    }

    state = state.copyWith(busy: false);
    await selectCategory(state.selectedCategoryId);
    return null;
  }

  int get _writeCategoryId {
    if (state.selectedCategoryId > 0) {
      return state.selectedCategoryId;
    }
    final fallback = state.categories.where((item) => item.id > 0).firstOrNull;
    return fallback?.id ?? 0;
  }

  List<NoteCategoryItem> _parseCategories(
    dynamic data, {
    required int totalCount,
  }) {
    final result = <NoteCategoryItem>[
      NoteCategoryItem(id: 0, name: '笔记', count: totalCount),
    ];
    if (data is! List) {
      return result;
    }
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final id = _toInt(item['id']);
      final name = item['name']?.toString().trim() ?? '';
      if (id <= 0 || name.isEmpty) {
        continue;
      }
      result.add(
        NoteCategoryItem(id: id, name: name, count: _toInt(item['count'])),
      );
    }
    return result;
  }

  int _resolveInitialCategoryId(
    List<NoteCategoryItem> categories,
    int currentId,
  ) {
    final positiveCategories = categories.where((item) => item.id > 0).toList();
    if (positiveCategories.isEmpty) {
      return 0;
    }
    if (positiveCategories.any((item) => item.id == currentId)) {
      return currentId;
    }
    return positiveCategories.first.id;
  }

  List<NoteEntry> _parseNotes(dynamic data) {
    if (data is! List) {
      return const <NoteEntry>[];
    }
    final result = <NoteEntry>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      result.add(
        NoteEntry(
          id: _toInt(item['id']),
          categoryId: _toInt(item['categoryId']),
          title: item['title']?.toString().trim().isNotEmpty == true
              ? item['title'].toString().trim()
              : '未命名笔记',
          imageUrl: item['param1']?.toString() ?? '',
          createdAt: _parseDate(item['createTime']),
          paperType: NotePaperType.fromValue(item['paperType']),
          isFavorite: _toBool(item['favorite']) || _toBool(item['isFavorite']),
        ),
      );
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  DateTime _parseDate(dynamic value) {
    final raw = value?.toString() ?? '';
    return DateTime.tryParse(raw) ?? DateTime.now();
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = value?.toString().toLowerCase() ?? '';
    return text == 'true' || text == '1';
  }

  String _fallbackMessage(String raw, String fallback) {
    return raw.trim().isEmpty ? fallback : raw.trim();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
