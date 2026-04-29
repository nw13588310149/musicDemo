import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/my_notes_controller.dart';
import '../state/my_notes_state.dart';

class MyNotesPage extends ConsumerStatefulWidget {
  const MyNotesPage({super.key});

  @override
  ConsumerState<MyNotesPage> createState() => _MyNotesPageState();
}

class _MyNotesPageState extends ConsumerState<MyNotesPage> {
  final GlobalKey _canvasBoundaryKey = GlobalKey();
  List<Offset> _activeStroke = const <Offset>[];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myNotesControllerProvider);
    return switch (state.view) {
      MyNotesView.list => _NotesListView(
        state: state,
        onCreate: _handleCreate,
        onAddCategory: _showAddCategoryDialog,
        onDeleteCategory: _deleteCategory,
        onDeleteNote: _deleteNote,
      ),
      MyNotesView.template => _NoteTemplateView(
        selectedType: state.paperType,
        onBack: _backToList,
        onSelected: (type) {
          ref.read(myNotesControllerProvider.notifier).chooseTemplate(type);
        },
      ),
      MyNotesView.editor => _NoteEditorView(
        boundaryKey: _canvasBoundaryKey,
        state: state,
        activeStroke: _activeStroke,
        onBack: _backToList,
        onColorSelected: (color) {
          ref.read(myNotesControllerProvider.notifier).setSelectedColor(color);
        },
        onStrokeWidthChanged: (value) {
          ref.read(myNotesControllerProvider.notifier).setStrokeWidth(value);
        },
        onUndo: () {
          ref.read(myNotesControllerProvider.notifier).undoStroke();
        },
        onClear: () {
          ref.read(myNotesControllerProvider.notifier).clearCanvas();
        },
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        onSave: _saveEditorImage,
      ),
    };
  }

  Future<void> _handleCreate() async {
    final message = ref
        .read(myNotesControllerProvider.notifier)
        .beginCreateNote();
    if (message != null && mounted) {
      _showMessage(message);
    }
  }

  void _backToList() {
    setState(() => _activeStroke = const <Offset>[]);
    ref.read(myNotesControllerProvider.notifier).backToList();
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建分类'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入笔记分类名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (!mounted || result == null) {
      return;
    }
    final message = await ref
        .read(myNotesControllerProvider.notifier)
        .addCategory(result);
    if (message != null && mounted) {
      _showMessage(message);
    }
  }

  Future<void> _deleteCategory(NoteCategoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('删除“${item.name}”后，该分类下的笔记也会一并移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final message = await ref
        .read(myNotesControllerProvider.notifier)
        .deleteCategory(item.id);
    if (message != null && mounted) {
      _showMessage(message);
    }
  }

  Future<void> _deleteNote(NoteEntry item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确定删除“${item.title}”吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final message = await ref
        .read(myNotesControllerProvider.notifier)
        .deleteNote(item.id);
    if (message != null && mounted) {
      _showMessage(message);
    }
  }

  void _handlePanStart(DragStartDetails details) {
    setState(() => _activeStroke = <Offset>[details.localPosition]);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _activeStroke = <Offset>[..._activeStroke, details.localPosition];
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_activeStroke.length >= 2) {
      ref.read(myNotesControllerProvider.notifier).addStroke(_activeStroke);
    }
    setState(() => _activeStroke = const <Offset>[]);
  }

  Future<void> _saveEditorImage() async {
    try {
      final boundary =
          _canvasBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        _showMessage('画布还未准备好，请稍后重试');
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      final image = await boundary.toImage(pixelRatio: 2.2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showMessage('笔记导出失败，请稍后重试');
        return;
      }
      final bytes = byteData.buffer.asUint8List();
      final message = await ref
          .read(myNotesControllerProvider.notifier)
          .saveCurrentNote(bytes);
      if (message != null && mounted) {
        _showMessage(message);
        return;
      }
      if (mounted) {
        _showMessage('笔记已保存');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('保存失败，请稍后重试');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NotesListView extends ConsumerWidget {
  const _NotesListView({
    required this.state,
    required this.onCreate,
    required this.onAddCategory,
    required this.onDeleteCategory,
    required this.onDeleteNote,
  });

  final MyNotesState state;
  final Future<void> Function() onCreate;
  final Future<void> Function() onAddCategory;
  final Future<void> Function(NoteCategoryItem item) onDeleteCategory;
  final Future<void> Function(NoteEntry item) onDeleteNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final controller = ref.read(myNotesControllerProvider.notifier);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: ui(158),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(16)),
          ),
          padding: EdgeInsets.fromLTRB(ui(12), ui(16), ui(12), ui(16)),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    '笔记',
                    style: TextStyle(
                      fontSize: ui(20),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF16141F),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(8),
                      vertical: ui(4),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4FB),
                      borderRadius: BorderRadius.circular(ui(999)),
                    ),
                    child: Text(
                      '${state.categories.firstOrNull?.count ?? 0}',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: const Color(0xFF7C8093),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(18)),
              Expanded(
                child: ListView.separated(
                  itemCount: state.categories.length,
                  separatorBuilder: (context, index) => SizedBox(height: ui(8)),
                  itemBuilder: (context, index) {
                    final item = state.categories[index];
                    final active = item.id == state.selectedCategoryId;
                    return InkWell(
                      borderRadius: BorderRadius.circular(ui(12)),
                      onTap: () => controller.selectCategory(item.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: EdgeInsets.symmetric(
                          horizontal: ui(10),
                          vertical: ui(10),
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFF151320)
                              : const Color(0xFFF7F8FE),
                          borderRadius: BorderRadius.circular(ui(12)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: ui(14),
                                  color: active
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (item.id > 0)
                              InkWell(
                                onTap: () => onDeleteCategory(item),
                                borderRadius: BorderRadius.circular(ui(8)),
                                child: Padding(
                                  padding: EdgeInsets.all(ui(4)),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    size: ui(18),
                                    color: active
                                        ? Colors.white.withValues(alpha: 0.78)
                                        : const Color(0xFF9BA3B7),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: ui(14)),
              SizedBox(
                width: double.infinity,
                height: ui(42),
                child: OutlinedButton.icon(
                  onPressed: onAddCategory,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('笔记分类'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B63FF),
                    side: const BorderSide(color: Color(0xFFE1E7F5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ui(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: ui(16)),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(16)),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        ui(18),
                        ui(18),
                        ui(18),
                        ui(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const ClampingScrollPhysics(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final filter
                                      in MyNotesFilter.values) ...[
                                    _FilterChip(
                                      label: filter.label,
                                      active: state.activeFilter == filter,
                                      onTap: () =>
                                          controller.selectFilter(filter),
                                    ),
                                    SizedBox(width: ui(10)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: ui(12)),
                          _PrimaryActionButton(
                            label: '新建笔记',
                            icon: Icons.add_rounded,
                            onPressed: onCreate,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: state.loading
                          ? const Center(child: CircularProgressIndicator())
                          : state.visibleNotes.isEmpty
                          ? _EmptyPanel(
                              title: '还没有笔记',
                              subtitle: '先创建一条新的笔记，我们再继续完善内容。',
                              onPressed: onCreate,
                            )
                          : Padding(
                              padding: EdgeInsets.fromLTRB(
                                ui(18),
                                0,
                                ui(18),
                                ui(18),
                              ),
                              child: GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: ui(220),
                                      mainAxisSpacing: ui(14),
                                      crossAxisSpacing: ui(14),
                                      childAspectRatio: 0.78,
                                    ),
                                itemCount: state.visibleNotes.length,
                                itemBuilder: (context, index) {
                                  final item = state.visibleNotes[index];
                                  return _NoteCard(
                                    item: item,
                                    onOpen: () {
                                      controller.openExistingNote(item);
                                    },
                                    onDelete: () => onDeleteNote(item),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
                if (state.busy)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x22000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteTemplateView extends StatelessWidget {
  const _NoteTemplateView({
    required this.selectedType,
    required this.onBack,
    required this.onSelected,
  });

  final NotePaperType selectedType;
  final VoidCallback onBack;
  final ValueChanged<NotePaperType> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.fromLTRB(ui(22), ui(20), ui(22), ui(22)),
      child: Column(
        children: [
          SizedBox(
            height: ui(44),
            child: Row(
              children: [
                _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
                const Spacer(),
                Text(
                  '请选择您的笔记样式',
                  style: TextStyle(
                    fontSize: ui(20),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF121212),
                  ),
                ),
                const Spacer(),
                SizedBox(width: ui(44)),
              ],
            ),
          ),
          SizedBox(height: ui(30)),
          Expanded(
            child: Row(
              children: NotePaperType.values.map((type) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: ui(10)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(ui(18)),
                      onTap: () => onSelected(type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: EdgeInsets.all(ui(18)),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FE),
                          borderRadius: BorderRadius.circular(ui(18)),
                          border: Border.all(
                            color: selectedType == type
                                ? const Color(0xFF8B5CFF)
                                : const Color(0xFFE8ECF7),
                            width: selectedType == type ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(ui(14)),
                                ),
                                child: CustomPaint(
                                  painter: _NotePaperPainter(type: type),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                            SizedBox(height: ui(16)),
                            Text(
                              type.label,
                              style: TextStyle(
                                fontSize: ui(18),
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF171A20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteEditorView extends StatelessWidget {
  const _NoteEditorView({
    required this.boundaryKey,
    required this.state,
    required this.activeStroke,
    required this.onBack,
    required this.onColorSelected,
    required this.onStrokeWidthChanged,
    required this.onUndo,
    required this.onClear,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onSave,
  });

  final GlobalKey boundaryKey;
  final MyNotesState state;
  final List<Offset> activeStroke;
  final VoidCallback onBack;
  final ValueChanged<Color> onColorSelected;
  final ValueChanged<double> onStrokeWidthChanged;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.fromLTRB(ui(18), ui(16), ui(18), ui(18)),
      child: Column(
        children: [
          SizedBox(
            height: ui(44),
            child: Row(
              children: [
                _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
                const Spacer(),
                Text(
                  state.draftTitle,
                  style: TextStyle(
                    fontSize: ui(20),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF16141F),
                  ),
                ),
                const Spacer(),
                _SecondaryActionButton(
                  label: '保存',
                  icon: Icons.save_outlined,
                  busy: state.busy,
                  onPressed: state.busy ? null : onSave,
                ),
              ],
            ),
          ),
          SizedBox(height: ui(16)),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(ui(18)),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(color: Colors.white),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              painter: _NotePaperPainter(type: state.paperType),
                            ),
                            _buildOptionalRemoteImage(
                              state.editorBackgroundImageUrl,
                              fit: BoxFit.cover,
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: onPanStart,
                              onPanUpdate: onPanUpdate,
                              onPanEnd: onPanEnd,
                              child: CustomPaint(
                                painter: _StrokePainter(
                                  strokes: state.strokes,
                                  activeStroke: activeStroke,
                                  activeColor: state.selectedColor,
                                  activeWidth: state.strokeWidth,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: ui(0),
                  right: ui(0),
                  bottom: ui(22),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ui(16),
                        vertical: ui(10),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(ui(16)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x14000000),
                            blurRadius: ui(18),
                            offset: Offset(0, ui(8)),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: state.strokes.isEmpty ? null : onUndo,
                            icon: const Icon(Icons.undo_rounded),
                          ),
                          Container(
                            width: 1,
                            height: ui(22),
                            color: const Color(0xFFEAEAF2),
                          ),
                          SizedBox(width: ui(12)),
                          ..._editorColors.map((color) {
                            final active = color == state.selectedColor;
                            return GestureDetector(
                              onTap: () => onColorSelected(color),
                              child: Container(
                                width: ui(22),
                                height: ui(22),
                                margin: EdgeInsets.only(right: ui(10)),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: active
                                        ? const Color(0xFF16141F)
                                        : Colors.white,
                                    width: active ? 2 : 1,
                                  ),
                                ),
                              ),
                            );
                          }),
                          SizedBox(width: ui(4)),
                          Container(
                            width: ui(44),
                            height: ui(34),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F7FB),
                              borderRadius: BorderRadius.circular(ui(10)),
                            ),
                            child: Text(
                              '${state.strokeWidth.round()}',
                              style: TextStyle(
                                fontSize: ui(14),
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2A2A2A),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: ui(110),
                            child: Slider(
                              value: state.strokeWidth,
                              min: 2,
                              max: 32,
                              activeColor: const Color(0xFF8B5CFF),
                              inactiveColor: const Color(0xFFE8EAF4),
                              onChanged: onStrokeWidthChanged,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: ui(22),
                            color: const Color(0xFFEAEAF2),
                          ),
                          SizedBox(width: ui(8)),
                          TextButton.icon(
                            onPressed: onClear,
                            icon: const Icon(Icons.auto_fix_off_outlined),
                            label: const Text('清空画布'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF1F1A32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(10)),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF151320) : const Color(0xFFF4F6FD),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : const Color(0xFF6D7386),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.item,
    required this.onOpen,
    required this.onDelete,
  });

  final NoteEntry item;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: const Color(0xFFF8FAFF),
      borderRadius: BorderRadius.circular(ui(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(ui(16)),
        onTap: onOpen,
        child: Padding(
          padding: EdgeInsets.all(ui(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ui(14)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: const BoxDecoration(color: Colors.white),
                        child: CustomPaint(
                          painter: _NotePaperPainter(type: item.paperType),
                        ),
                      ),
                      _buildOptionalRemoteImage(
                        item.imageUrl,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        right: ui(8),
                        top: ui(8),
                        child: GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            width: ui(28),
                            height: ui(28),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: ui(18),
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: ui(12)),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(15),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF16141F),
                ),
              ),
              SizedBox(height: ui(4)),
              Text(
                item.dateLabel,
                style: TextStyle(
                  fontSize: ui(12),
                  color: const Color(0xFF8F96A9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(92),
            height: ui(92),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4FB),
              borderRadius: BorderRadius.circular(ui(24)),
            ),
            child: Icon(
              Icons.sticky_note_2_outlined,
              size: ui(46),
              color: const Color(0xFF8B5CFF),
            ),
          ),
          SizedBox(height: ui(18)),
          Text(
            title,
            style: TextStyle(
              fontSize: ui(22),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF171A20),
            ),
          ),
          SizedBox(height: ui(8)),
          Text(
            subtitle,
            style: TextStyle(fontSize: ui(14), color: const Color(0xFF8A91A5)),
          ),
          SizedBox(height: ui(18)),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add_rounded),
            label: const Text('新建笔记'),
          ),
        ],
      ),
    );
  }
}

Widget _buildOptionalRemoteImage(String? rawUrl, {BoxFit fit = BoxFit.cover}) {
  final resolvedUrl = _resolveRemoteUrl(rawUrl);
  if (resolvedUrl == null) {
    return const SizedBox.shrink();
  }
  return Image.network(
    resolvedUrl,
    fit: fit,
    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    loadingBuilder: (context, child, loadingProgress) => child,
  );
}

String? _resolveRemoteUrl(String? rawUrl) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty || value.toLowerCase() == 'string') {
    return null;
  }

  if (value.startsWith('//')) {
    return 'https:$value';
  }

  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) {
    return value;
  }

  if (value.startsWith('/')) {
    return Uri.parse(AppConstants.apiBaseUrl).resolve(value).toString();
  }

  return null;
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        width: ui(40),
        height: ui(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: const Color(0xFFE7EAF4)),
        ),
        child: Icon(icon, size: ui(22), color: const Color(0xFF19152A)),
      ),
    );
  }
}

/// 主操作按钮（紫色实心，例如"新建笔记"）。
///
/// 不使用 Material 的 [FilledButton.icon]，因为它内部 `_InputPadding`
/// + `tapTargetSize` 在无界宽度场景下会把 `minimumSize` 解析成 Infinity，
/// 触发 layout 错误（`additionalConstraints: BoxConstraints(w=Infinity, ...)`，
/// size MISSING）。这里用 InkWell + Container 自己拼，水波/形状/手势都保留。
class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: const Color(0xFF8B5CFF),
      borderRadius: BorderRadius.circular(ui(12)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(ui(12)),
        child: Container(
          height: ui(40),
          padding: EdgeInsets.symmetric(horizontal: ui(16)),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: ui(18), color: Colors.white),
              SizedBox(width: ui(6)),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: ui(14),
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 次操作按钮（白底带描边，例如笔记详情右上角的"保存"）。
class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final foreground = onPressed == null
        ? const Color(0xFFB9BCCB)
        : const Color(0xFF1B1730);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(ui(12)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(ui(12)),
        child: Container(
          height: ui(40),
          padding: EdgeInsets.symmetric(horizontal: ui(16)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ui(12)),
            border: Border.all(color: const Color(0xFFE6EAF5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: ui(16),
                  height: ui(16),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, size: ui(18), color: foreground),
              SizedBox(width: ui(6)),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: ui(14),
                  fontWeight: FontWeight.w500,
                  color: foreground,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  const _StrokePainter({
    required this.strokes,
    required this.activeStroke,
    required this.activeColor,
    required this.activeWidth,
  });

  final List<NoteStroke> strokes;
  final List<Offset> activeStroke;
  final Color activeColor;
  final double activeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.width);
    }
    if (activeStroke.length >= 2) {
      _drawStroke(canvas, activeStroke, activeColor, activeWidth);
    }
  }

  void _drawStroke(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double width,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final midPoint = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(
        previous.dx,
        previous.dy,
        midPoint.dx,
        midPoint.dy,
      );
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.activeWidth != activeWidth;
  }
}

class _NotePaperPainter extends CustomPainter {
  const _NotePaperPainter({required this.type});

  final NotePaperType type;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD6DCE9)
      ..strokeWidth = 1;

    switch (type) {
      case NotePaperType.blank:
        _drawDots(canvas, size, paint);
        break;
      case NotePaperType.notebook:
        _drawNotebook(canvas, size, paint);
        break;
      case NotePaperType.staff:
        _drawStaff(canvas, size, paint);
        break;
    }
  }

  void _drawDots(Canvas canvas, Size size, Paint paint) {
    final dotPaint = Paint()..color = const Color(0xFFE9EDF7);
    for (double y = 26; y < size.height; y += 28) {
      for (double x = 20; x < size.width; x += 24) {
        canvas.drawCircle(Offset(x, y), 1, dotPaint);
      }
    }
  }

  void _drawNotebook(Canvas canvas, Size size, Paint paint) {
    for (double y = 42; y < size.height; y += 34) {
      canvas.drawLine(Offset(24, y), Offset(size.width - 24, y), paint);
    }
  }

  void _drawStaff(Canvas canvas, Size size, Paint paint) {
    double startY = 36;
    while (startY < size.height - 20) {
      for (var i = 0; i < 5; i++) {
        final y = startY + i * 9;
        canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), paint);
      }
      startY += 66;
    }
  }

  @override
  bool shouldRepaint(covariant _NotePaperPainter oldDelegate) {
    return oldDelegate.type != type;
  }
}

const List<Color> _editorColors = <Color>[
  Color(0xFF2A2A2A),
  Color(0xFFFF5A36),
  Color(0xFFFFA040),
  Color(0xFF5CCB6A),
  Color(0xFF4B9EF8),
  Color(0xFF8B5CFF),
];

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
