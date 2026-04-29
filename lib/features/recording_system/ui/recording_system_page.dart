import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/recording_system_controller.dart';
import '../state/recording_system_state.dart';

class RecordingSystemPage extends ConsumerWidget {
  const RecordingSystemPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingSystemControllerProvider);
    return switch (state.viewMode) {
      RecordingViewMode.list => _RecordingListView(state: state),
      RecordingViewMode.record => _RecordingEditorView(state: state),
      RecordingViewMode.preview => _RecordingPreviewView(state: state),
    };
  }
}

// ===========================================================================
// 列表页（一/二级）—— 与「我的云盘」一级页面保持一致的布局
// ===========================================================================

class _RecordingListView extends ConsumerStatefulWidget {
  const _RecordingListView({required this.state});

  final RecordingSystemState state;

  @override
  ConsumerState<_RecordingListView> createState() => _RecordingListViewState();
}

class _RecordingListViewState extends ConsumerState<_RecordingListView> {
  late final TextEditingController _searchController;
  String _keyword = '';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.searchQuery);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final value = _searchController.text;
    if (value == _keyword) {
      return;
    }
    setState(() => _keyword = value);
    ref
        .read(recordingSystemControllerProvider.notifier)
        .updateSearchQuery(value);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = ref.read(recordingSystemControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                Row(
                  children: [
                    Container(
                      width: ui(180),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(ui(16)),
                        ),
                        border: Border(
                          right: BorderSide(
                            color: const Color(0xFFF3F2F3),
                            width: ui(1),
                          ),
                        ),
                      ),
                      child: _RecordingSidebar(
                        state: state,
                        onSelectCategory: controller.selectCategory,
                        onAddCategory: _showAddCategoryDialog,
                        onCategoryAction: _handleCategoryAction,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(ui(16)),
                          ),
                        ),
                        child: _RecordingContentArea(
                          state: state,
                          keyword: _keyword,
                          searchController: _searchController,
                          sortAscending: _sortAscending,
                          onToggleSort: () =>
                              setState(() => _sortAscending = !_sortAscending),
                          onRefresh: controller.refresh,
                          onOpenItem: controller.openPreview,
                          onItemAction: _handleItemAction,
                          onCreate: controller.openNewRecording,
                        ),
                      ),
                    ),
                  ],
                ),
                if (state.busy)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.48),
                          borderRadius: BorderRadius.circular(ui(16)),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: ui(28),
                            height: ui(28),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final name = await showTextInputDialog(
      context: context,
      title: '添加分类',
      hintText: '请输入分类名称',
      confirmLabel: '确认',
    );
    if (name == null || name.isEmpty) {
      return;
    }
    final message = await ref
        .read(recordingSystemControllerProvider.notifier)
        .addCategory(name);
    if (!mounted) {
      return;
    }
    _showMessage(context, message ?? '分类已添加');
  }

  Future<void> _handleCategoryAction(
    RecordingCategoryItem item,
    _RecordingMenuAction action,
  ) async {
    switch (action) {
      case _RecordingMenuAction.rename:
        _showMessage(context, '分类重命名能力待接入');
        break;
      case _RecordingMenuAction.share:
        _showMessage(context, '分类分享能力待接入');
        break;
      case _RecordingMenuAction.copy:
        _showMessage(context, '分类复制能力待接入');
        break;
      case _RecordingMenuAction.delete:
        final confirmed = await showConfirmDialog(
          context: context,
          title: '删除分类',
          content: '删除"${item.name}"后，该分类下的录音会一并移除，确认继续吗？',
          confirmLabel: '删除',
        );
        if (!confirmed || !mounted) {
          return;
        }
        final message = await ref
            .read(recordingSystemControllerProvider.notifier)
            .deleteCategory(item.id);
        if (!mounted) {
          return;
        }
        _showMessage(context, message ?? '分类已删除');
        break;
    }
  }

  Future<void> _handleItemAction(
    RecordingEntry item,
    _RecordingItemAction action,
  ) async {
    final controller = ref.read(recordingSystemControllerProvider.notifier);
    switch (action) {
      case _RecordingItemAction.preview:
        await controller.openPreview(item);
        break;
      case _RecordingItemAction.share:
        await controller.openPreview(item);
        if (!mounted) {
          return;
        }
        final message = await controller.openShare();
        if (!mounted) {
          return;
        }
        if (message != null) {
          _showMessage(context, message);
        }
        break;
      case _RecordingItemAction.delete:
        final confirmed = await showConfirmDialog(
          context: context,
          title: '删除录音',
          content: '删除后不可恢复，确认删除"${item.name}"吗？',
          confirmLabel: '删除',
        );
        if (!confirmed || !mounted) {
          return;
        }
        final message = await controller.deleteRecording(item);
        if (!mounted) {
          return;
        }
        _showMessage(context, message ?? '录音已删除');
        break;
    }
  }
}

class _RecordingSidebar extends StatelessWidget {
  const _RecordingSidebar({
    required this.state,
    required this.onSelectCategory,
    required this.onAddCategory,
    required this.onCategoryAction,
  });

  final RecordingSystemState state;
  final ValueChanged<int> onSelectCategory;
  final VoidCallback onAddCategory;
  final Future<void> Function(
    RecordingCategoryItem item,
    _RecordingMenuAction action,
  )
  onCategoryAction;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(8), ui(8), ui(8), ui(10)),
      child: Column(
        children: [
          Expanded(
            child: state.loading && state.categories.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : ListView.separated(
                    itemCount: state.categories.length,
                    separatorBuilder: (_, _) => SizedBox(height: ui(8)),
                    itemBuilder: (context, index) {
                      final item = state.categories[index];
                      return _RecordingCategoryCard(
                        item: item,
                        selected: item.id == state.selectedCategoryId,
                        onTap: () => onSelectCategory(item.id),
                        onAction: (action) => onCategoryAction(item, action),
                      );
                    },
                  ),
          ),
          SizedBox(height: ui(12)),
          _AddCategoryCard(onTap: onAddCategory),
        ],
      ),
    );
  }
}

class _RecordingCategoryCard extends StatefulWidget {
  const _RecordingCategoryCard({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onAction,
  });

  final RecordingCategoryItem item;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<_RecordingMenuAction> onAction;

  @override
  State<_RecordingCategoryCard> createState() => _RecordingCategoryCardState();
}

class _RecordingCategoryCardState extends State<_RecordingCategoryCard> {
  final GlobalKey _menuTriggerKey = GlobalKey();

  Future<void> _openActionMenu() async {
    final action = await _showRecordingActionMenu(
      context: context,
      triggerKey: _menuTriggerKey,
    );
    if (action != null) {
      widget.onAction(action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final selected = widget.selected;
    final item = widget.item;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(ui(selected ? 8 : 16)),
      child: Container(
        height: ui(60),
        padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(8), ui(12)),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF4F4FF) : Colors.white,
          borderRadius: BorderRadius.circular(ui(selected ? 8 : 16)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: ui(36),
              height: ui(36),
              decoration: BoxDecoration(
                color: selected ? Colors.white : const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(ui(999)),
              ),
              child: Center(
                child: Image.asset(
                  AppAssets.cloudFolderIcon,
                  width: ui(18),
                  height: ui(16),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(width: ui(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: const Color(0xFF0B081A),
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w500,
                      height: 12 / 13,
                    ),
                  ),
                  SizedBox(height: ui(4)),
                  Text(
                    selected ? '已选中' : '点击查看',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(10),
                      color: selected
                          ? const Color(0xFF0B081A)
                          : const Color(0xFF7F7F7F),
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
                      height: 12 / 10,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              key: _menuTriggerKey,
              behavior: HitTestBehavior.opaque,
              onTap: _openActionMenu,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: ui(2)),
                child: Image.asset(
                  AppAssets.cloudActionMore,
                  width: ui(24),
                  height: ui(24),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCategoryCard extends StatelessWidget {
  const _AddCategoryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(16)),
      child: Container(
        height: ui(56),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F7FF),
          borderRadius: BorderRadius.circular(ui(16)),
          border: Border.all(color: const Color(0xFFEBE6FF), width: ui(1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              size: ui(18),
              color: const Color(0xFF8741FF),
            ),
            SizedBox(width: ui(6)),
            Text(
              '添加分类',
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFF8741FF),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 12 / 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingContentArea extends StatelessWidget {
  const _RecordingContentArea({
    required this.state,
    required this.keyword,
    required this.searchController,
    required this.sortAscending,
    required this.onToggleSort,
    required this.onRefresh,
    required this.onOpenItem,
    required this.onItemAction,
    required this.onCreate,
  });

  final RecordingSystemState state;
  final String keyword;
  final TextEditingController searchController;
  final bool sortAscending;
  final VoidCallback onToggleSort;
  final Future<void> Function() onRefresh;
  final ValueChanged<RecordingEntry> onOpenItem;
  final Future<void> Function(RecordingEntry item, _RecordingItemAction action)
  onItemAction;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final selectedCategoryName = state.categories
        .where((item) => item.id == state.selectedCategoryId)
        .map((item) => item.name)
        .firstOrNull;
    final headerName = selectedCategoryName ?? '我的录音';
    final visible = _sorted(_filter(state.items, keyword), sortAscending);

    return Padding(
      padding: EdgeInsets.fromLTRB(ui(30), ui(28), ui(20), ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headerName,
            style: TextStyle(
              fontSize: ui(15),
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
              height: 12 / 15,
            ),
          ),
          SizedBox(height: ui(16)),
          Row(
            children: [
              SizedBox(
                width: ui(324),
                child: _RecordingSearchField(controller: searchController),
              ),
              const Spacer(),
              _ToolbarChip(
                imageAsset: AppAssets.coursewareSort,
                label: sortAscending ? '正序' : '排序',
                onTap: onToggleSort,
              ),
              SizedBox(width: ui(12)),
              _ToolbarChip(
                imageAsset: AppAssets.coursewareRefresh,
                label: '刷新',
                onTap: () => onRefresh(),
              ),
            ],
          ),
          SizedBox(height: ui(16)),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: state.loading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : visible.isEmpty
                      ? const _RecordingEmpty()
                      : _RecordingFilesGrid(
                          items: visible,
                          onOpen: onOpenItem,
                          onAction: onItemAction,
                        ),
                ),
                Positioned(
                  right: 0,
                  bottom: ui(8),
                  child: _RecordingFab(label: '新建录音', onTap: onCreate),
                ),
              ],
            ),
          ),
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) ...[
            SizedBox(height: ui(10)),
            Text(
              state.errorMessage!,
              style: TextStyle(
                fontSize: ui(12),
                color: const Color(0xFFFF5681),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<RecordingEntry> _filter(List<RecordingEntry> items, String keyword) {
    final query = keyword.trim();
    if (query.isEmpty) {
      return items;
    }
    return items
        .where((item) => item.name.contains(query))
        .toList(growable: false);
  }

  List<RecordingEntry> _sorted(List<RecordingEntry> items, bool ascending) {
    final list = [...items];
    list.sort((left, right) {
      final byName = left.name.compareTo(right.name);
      return ascending ? byName : -byName;
    });
    return list;
  }
}

class _RecordingSearchField extends StatelessWidget {
  const _RecordingSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(40),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: '搜索录音名称',
          hintStyle: TextStyle(
            fontSize: ui(13),
            color: const Color(0xFFB6B5BB),
            fontFamily: 'PingFang SC',
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: ui(8)),
            child: Image.asset(
              AppAssets.cloudSearch,
              width: ui(16),
              height: ui(16),
              fit: BoxFit.contain,
            ),
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: ui(32),
            minHeight: ui(20),
          ),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: ui(12),
            vertical: ui(10),
          ),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide(
              color: const Color(0xFFF3F2F3),
              width: ui(1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide(
              color: const Color(0xFFD9C7FF),
              width: ui(1),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({
    required this.imageAsset,
    required this.label,
    required this.onTap,
  });

  final String imageAsset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              imageAsset,
              width: ui(18),
              height: ui(18),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(6)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 12 / 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingFilesGrid extends StatelessWidget {
  const _RecordingFilesGrid({
    required this.items,
    required this.onOpen,
    required this.onAction,
  });

  final List<RecordingEntry> items;
  final ValueChanged<RecordingEntry> onOpen;
  final Future<void> Function(RecordingEntry item, _RecordingItemAction action)
  onAction;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: ui(180),
        mainAxisSpacing: ui(20),
        crossAxisSpacing: ui(16),
        mainAxisExtent: ui(208),
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _RecordingFileCard(
          item: item,
          onTap: () => onOpen(item),
          onAction: (action) => onAction(item, action),
        );
      },
    );
  }
}

class _RecordingFileCard extends StatelessWidget {
  const _RecordingFileCard({
    required this.item,
    required this.onTap,
    required this.onAction,
  });

  final RecordingEntry item;
  final VoidCallback onTap;
  final ValueChanged<_RecordingItemAction> onAction;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(12)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(12)),
            border: Border.all(color: const Color(0xFFF5F6FA), width: ui(1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Center(
                      child: Image.asset(
                        AppAssets.soundFilePlaceholder,
                        width: ui(96),
                        height: ui(96),
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      top: ui(8),
                      right: ui(8),
                      child: PopupMenuButton<_RecordingItemAction>(
                        padding: EdgeInsets.zero,
                        iconSize: ui(20),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ui(12)),
                        ),
                        onSelected: onAction,
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: _RecordingItemAction.preview,
                            child: Text('查看'),
                          ),
                          PopupMenuItem(
                            value: _RecordingItemAction.share,
                            child: Text('分享'),
                          ),
                          PopupMenuItem(
                            value: _RecordingItemAction.delete,
                            child: Text('删除'),
                          ),
                        ],
                        child: SizedBox(
                          width: ui(24),
                          height: ui(24),
                          child: Image.asset(
                            AppAssets.cloudActionMore,
                            width: ui(24),
                            height: ui(24),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: ui(58),
                color: const Color(0xFFF5F6FA),
                padding: EdgeInsets.fromLTRB(ui(12), ui(8), ui(12), ui(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(13),
                        color: const Color(0xFF0B081A),
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w500,
                        height: 12 / 13,
                      ),
                    ),
                    SizedBox(height: ui(4)),
                    Text(
                      item.durationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(11),
                        color: const Color(0xFF7F7F7F),
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w400,
                        height: 12 / 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingFab extends StatelessWidget {
  const _RecordingFab({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x33AD80FF),
            blurRadius: ui(20),
            offset: Offset(0, ui(10)),
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFF8B5CFF),
        borderRadius: BorderRadius.circular(ui(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ui(16)),
          child: Container(
            height: ui(48),
            padding: EdgeInsets.symmetric(horizontal: ui(18)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  AppAssets.soundFabIcon,
                  width: ui(20),
                  height: ui(20),
                  fit: BoxFit.contain,
                  color: Colors.white,
                ),
                SizedBox(width: ui(8)),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingEmpty extends StatelessWidget {
  const _RecordingEmpty();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            AppAssets.soundFilePlaceholder,
            width: ui(120),
            height: ui(120),
            fit: BoxFit.contain,
          ),
          SizedBox(height: ui(12)),
          Text(
            '还没有录音作品',
            style: TextStyle(
              fontSize: ui(15),
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: ui(6)),
          Text(
            '点击右下角"新建录音"，开始记录你的声音吧',
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFF98A0B3),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 三级页面：录音编辑 / 播放试听（按 Figma 设计）
// ===========================================================================

class _RecordingEditorView extends ConsumerWidget {
  const _RecordingEditorView({required this.state});

  final RecordingSystemState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(recordingSystemControllerProvider.notifier);
    final phase = state.recordingPhase;
    final canFinish = state.elapsedMs >= 5000;

    return _RecordingStage(
      title: '音频录制',
      onBack: controller.backToList,
      headerActions: const [],
      body: _RecordingStageBody(
        bars: state.liveWaveform.isEmpty
            ? _buildFallbackBars(120, seed: 9)
            : _stretchBars(state.liveWaveform, 120),
        progressRatio: 1,
        durationMs: math.max(state.elapsedMs, 8000),
        elapsedClock: _formatClock(state.elapsedMs),
        progressClock: _formatSecondsClock(state.elapsedMs),
        totalClock: _formatSecondsClock(math.max(state.elapsedMs, 8000)),
        leftPill: _DarkRecordingPill(
          icon: phase == RecordingPhase.recording
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          tone: phase == RecordingPhase.recording
              ? _PillTone.danger
              : _PillTone.normal,
          onTap: () async {
            final message = switch (phase) {
              RecordingPhase.idle => await controller.startRecording(),
              RecordingPhase.recording => await controller.pauseRecording(),
              RecordingPhase.paused => await controller.resumeRecording(),
            };
            if (message != null && context.mounted) {
              _showMessage(context, message);
            }
          },
        ),
        rightPill: _DarkRecordingPill(
          label: '完成',
          onTap: canFinish
              ? () async {
                  final message = await controller.finishRecording();
                  if (message != null && context.mounted) {
                    _showMessage(context, message);
                  }
                }
              : null,
        ),
        bottomTip: '录制不能低于5秒',
        errorMessage: state.errorMessage,
      ),
    );
  }
}

class _RecordingPreviewView extends ConsumerWidget {
  const _RecordingPreviewView({required this.state});

  final RecordingSystemState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(recordingSystemControllerProvider.notifier);
    final item = state.previewItem;
    final isDraft = item?.isLocalDraft ?? false;
    final bars = item == null
        ? _buildFallbackBars(120, seed: 4)
        : _stretchBars(item.waveform, 120);
    final totalMs = state.previewDurationMs > 0
        ? state.previewDurationMs
        : _parseDurationLabel(item?.durationLabel ?? '00:00.00');
    final progressRatio = totalMs <= 0
        ? 0.0
        : (state.previewPositionMs / totalMs).clamp(0.0, 1.0);
    final clampedTotalMs = math.max(totalMs, 8000);

    return _RecordingStage(
      title: '音频录制',
      onBack: controller.backToList,
      headerActions: isDraft
          ? [
              _LightHeaderButton(
                icon: Icons.save_outlined,
                label: '保存',
                onTap: controller.reopenSaveDialog,
              ),
            ]
          : [
              _LightHeaderButton(
                icon: Icons.share_outlined,
                label: '分享',
                onTap: () async {
                  final message = await controller.openShare();
                  if (message != null && context.mounted) {
                    _showMessage(context, message);
                  }
                },
              ),
              _LightHeaderButton(
                icon: Icons.delete_outline_rounded,
                label: '删除',
                onTap: () async {
                  if (item == null) {
                    return;
                  }
                  final confirmed = await showConfirmDialog(
                    context: context,
                    title: '删除录音',
                    content: '删除后不可恢复，确认删除"${item.name}"吗？',
                    confirmLabel: '删除',
                  );
                  if (!confirmed || !context.mounted) {
                    return;
                  }
                  final message = await controller.deleteRecording(item);
                  if (message != null && context.mounted) {
                    _showMessage(context, message);
                  }
                },
              ),
            ],
      body: _RecordingStageBody(
        bars: bars,
        progressRatio: progressRatio,
        durationMs: clampedTotalMs,
        elapsedClock: _formatClock(state.previewPositionMs),
        progressClock: _formatSecondsClock(state.previewPositionMs),
        totalClock: _formatSecondsClock(clampedTotalMs),
        leftPill: _DarkRecordingPill(
          icon: state.previewPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          onTap: controller.togglePreviewPlayback,
        ),
        rightPill: _DarkRecordingPill(
          label: '${state.previewPlaybackRate}x',
          onTap: controller.togglePlaybackRate,
        ),
        bottomTip: isDraft ? '可先试听，再保存到分类中' : '支持分享、删除和倍速试听',
        errorMessage: state.errorMessage,
      ),
    );
  }
}

class _RecordingStage extends ConsumerStatefulWidget {
  const _RecordingStage({
    required this.title,
    required this.onBack,
    required this.headerActions,
    required this.body,
  });

  final String title;
  final Future<void> Function() onBack;
  final List<Widget> headerActions;
  final Widget body;

  @override
  ConsumerState<_RecordingStage> createState() => _RecordingStageState();
}

class _RecordingStageState extends ConsumerState<_RecordingStage> {
  BuildContext? _saveDialogContext;
  BuildContext? _shareDialogContext;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final state = ref.read(recordingSystemControllerProvider);
      if (state.showSaveDialog) {
        _openSaveDialog();
      }
      if (state.showShareDialog) {
        _openShareDialog();
      }
    });
  }

  @override
  void dispose() {
    if (_saveDialogContext != null) {
      Navigator.of(_saveDialogContext!).pop();
      _saveDialogContext = null;
    }
    if (_shareDialogContext != null) {
      Navigator.of(_shareDialogContext!).pop();
      _shareDialogContext = null;
    }
    super.dispose();
  }

  Future<void> _openSaveDialog() async {
    if (_saveDialogContext != null) {
      return;
    }
    await showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      barrierDismissible: false,
      builder: (dialogCtx) {
        _saveDialogContext = dialogCtx;
        return const _SaveRecordingDialog();
      },
    );
    _saveDialogContext = null;
    if (!mounted) {
      return;
    }
    if (ref.read(recordingSystemControllerProvider).showSaveDialog) {
      ref.read(recordingSystemControllerProvider.notifier).closeSaveDialog();
    }
  }

  Future<void> _openShareDialog() async {
    if (_shareDialogContext != null) {
      return;
    }
    await showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      barrierDismissible: false,
      builder: (dialogCtx) {
        _shareDialogContext = dialogCtx;
        return const _ShareRecordingDialog();
      },
    );
    _shareDialogContext = null;
    if (!mounted) {
      return;
    }
    if (ref.read(recordingSystemControllerProvider).showShareDialog) {
      ref.read(recordingSystemControllerProvider.notifier).closeShareDialog();
    }
  }

  void _closeSaveDialog() {
    final ctx = _saveDialogContext;
    if (ctx == null) {
      return;
    }
    _saveDialogContext = null;
    Navigator.of(ctx).pop();
  }

  void _closeShareDialog() {
    final ctx = _shareDialogContext;
    if (ctx == null) {
      return;
    }
    _shareDialogContext = null;
    Navigator.of(ctx).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RecordingSystemState>(recordingSystemControllerProvider, (
      prev,
      next,
    ) {
      final prevSave = prev?.showSaveDialog ?? false;
      final prevShare = prev?.showShareDialog ?? false;
      if (prevSave != next.showSaveDialog) {
        if (next.showSaveDialog) {
          _openSaveDialog();
        } else {
          _closeSaveDialog();
        }
      }
      if (prevShare != next.showShareDialog) {
        if (next.showShareDialog) {
          _openShareDialog();
        } else {
          _closeShareDialog();
        }
      }
    });
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.fromLTRB(ui(20), ui(16), ui(20), ui(20)),
      child: Column(
        children: [
          SizedBox(
            height: ui(40),
            child: Row(
              children: [
                InkWell(
                  onTap: () => widget.onBack(),
                  borderRadius: BorderRadius.circular(ui(8)),
                  child: Container(
                    width: ui(32),
                    height: ui(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(8)),
                      border: Border.all(
                        color: const Color(0xFFF3F2F3),
                        width: ui(1),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: ui(14),
                      color: const Color(0xFF1C274C),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: ui(16),
                        color: const Color(0xFF0B081A),
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (widget.headerActions.isEmpty)
                  SizedBox(width: ui(32))
                else
                  Wrap(spacing: ui(10), children: widget.headerActions),
              ],
            ),
          ),
          SizedBox(height: ui(20)),
          Expanded(child: widget.body),
        ],
      ),
    );
  }
}

class _LightHeaderButton extends StatelessWidget {
  const _LightHeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(34),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Colors.white, Color(0xFFE6E6E6)],
          ),
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFD7D7D7), width: ui(2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0x44FFFFFF),
              blurRadius: ui(2.4),
              offset: Offset(ui(1), ui(3)),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: ui(16), color: const Color(0xFF8741FF)),
            SizedBox(width: ui(5)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(14),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingStageBody extends StatelessWidget {
  const _RecordingStageBody({
    required this.bars,
    required this.progressRatio,
    required this.durationMs,
    required this.elapsedClock,
    required this.progressClock,
    required this.totalClock,
    required this.leftPill,
    required this.rightPill,
    required this.bottomTip,
    required this.errorMessage,
  });

  final List<double> bars;
  final double progressRatio;
  final int durationMs;
  final String elapsedClock;
  final String progressClock;
  final String totalClock;
  final Widget leftPill;
  final Widget rightPill;
  final String bottomTip;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorMessage != null && errorMessage!.isNotEmpty) ...[
          _ErrorBanner(message: errorMessage!),
          SizedBox(height: ui(12)),
        ],
        _DarkWavePanel(
          bars: bars,
          progressRatio: progressRatio,
          durationMs: durationMs,
        ),
        SizedBox(height: ui(18)),
        _DarkScrubberPanel(
          progressRatio: progressRatio,
          startLabel: progressClock,
          endLabel: totalClock,
        ),
        SizedBox(height: ui(28)),
        Center(child: _GraniteTimerCapsule(label: elapsedClock)),
        SizedBox(height: ui(8)),
        Center(
          child: Text(
            bottomTip,
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFFB6B5BB),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: ui(20)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [leftPill, rightPill],
          ),
        ),
        SizedBox(height: ui(8)),
      ],
    );
  }
}

class _DarkWavePanel extends StatelessWidget {
  const _DarkWavePanel({
    required this.bars,
    required this.progressRatio,
    required this.durationMs,
  });

  final List<double> bars;
  final double progressRatio;
  final int durationMs;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(180),
      padding: EdgeInsets.all(ui(3)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(20)),
        border: Border.all(color: const Color(0xFFC3C3C3), width: ui(3)),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF353535), Color(0xFF141414)],
          ),
          borderRadius: BorderRadius.circular(ui(16)),
          border: Border.all(color: const Color(0xFF161616), width: ui(6)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ui(10)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DarkWavePainter(
                        bars: bars,
                        playedRatio: progressRatio,
                      ),
                    ),
                  ),
                  _Cursor(
                    width: constraints.maxWidth,
                    progressRatio: progressRatio,
                  ),
                  Positioned(
                    left: ui(12),
                    right: ui(12),
                    bottom: ui(8),
                    child: _TimeScale(durationMs: durationMs),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Cursor extends StatelessWidget {
  const _Cursor({required this.width, required this.progressRatio});

  final double width;
  final double progressRatio;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final clampedRatio = progressRatio.clamp(0.0, 1.0);
    final cursorX = (width - ui(8)) * clampedRatio;
    return Positioned(
      left: cursorX + ui(2),
      top: ui(8),
      bottom: ui(28),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: ui(2),
            decoration: BoxDecoration(
              color: const Color(0xFFA773FF),
              borderRadius: BorderRadius.circular(ui(1)),
            ),
          ),
          Positioned(
            left: -ui(4),
            top: -ui(4),
            child: Container(
              width: ui(10),
              height: ui(10),
              decoration: const BoxDecoration(
                color: Color(0xFFA773FF),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -ui(4),
            bottom: -ui(4),
            child: Container(
              width: ui(10),
              height: ui(10),
              decoration: const BoxDecoration(
                color: Color(0xFFA773FF),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkScrubberPanel extends StatelessWidget {
  const _DarkScrubberPanel({
    required this.progressRatio,
    required this.startLabel,
    required this.endLabel,
  });

  final double progressRatio;
  final String startLabel;
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(64),
      padding: EdgeInsets.all(ui(3)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(20)),
        border: Border.all(color: const Color(0xFFC3C3C3), width: ui(3)),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF353535), Color(0xFF141414)],
          ),
          borderRadius: BorderRadius.circular(ui(14)),
          border: Border.all(color: const Color(0xFF161616), width: ui(4)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned(
                  left: ui(8),
                  top: ui(6),
                  bottom: ui(6),
                  width: math.max(
                    ui(8),
                    (constraints.maxWidth - ui(16)) *
                        progressRatio.clamp(0.0, 1.0),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Color(0xFFA773FF), Color(0xFF7422FF)],
                      ),
                      borderRadius: BorderRadius.circular(ui(6)),
                    ),
                  ),
                ),
                Positioned(
                  left: ui(10),
                  bottom: ui(2),
                  child: Text(
                    startLabel,
                    style: TextStyle(
                      fontSize: ui(11),
                      color: const Color(0xFF747474),
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Positioned(
                  right: ui(10),
                  bottom: ui(2),
                  child: Text(
                    endLabel,
                    style: TextStyle(
                      fontSize: ui(11),
                      color: const Color(0xFF747474),
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DarkWavePainter extends CustomPainter {
  const _DarkWavePainter({required this.bars, required this.playedRatio});

  final List<double> bars;
  final double playedRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x883E3E3E)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height * 0.18),
      Offset(size.width, size.height * 0.18),
      grid,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.78),
      Offset(size.width, size.height * 0.78),
      grid,
    );
    final spacing = size.width / math.max(bars.length, 1);
    final played = Paint()
      ..color = const Color(0xFFA676FF)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    final idle = Paint()
      ..color = const Color(0xFFE6E6E6)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    for (var i = 0; i < bars.length; i++) {
      final x = spacing * i + spacing / 2;
      final amp = bars[i].clamp(0.05, 1.0);
      final h = amp * size.height * 0.55;
      final cy = size.height * 0.46;
      final paint = i / math.max(bars.length - 1, 1) <= playedRatio
          ? played
          : idle;
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DarkWavePainter oldDelegate) {
    return oldDelegate.bars != bars || oldDelegate.playedRatio != playedRatio;
  }
}

class _TimeScale extends StatelessWidget {
  const _TimeScale({required this.durationMs});

  final int durationMs;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final totalSeconds = math.max(1, durationMs ~/ 1000);
    const divisions = 9;
    return SizedBox(
      height: ui(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List<Widget>.generate(divisions, (index) {
          final seconds = ((totalSeconds / (divisions - 1)) * index).round();
          return Text(
            '0:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: ui(11),
              color: const Color(0xFF747474),
              fontFamily: 'Montserrat',
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
            ),
          );
        }),
      ),
    );
  }
}

class _GraniteTimerCapsule extends StatelessWidget {
  const _GraniteTimerCapsule({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(300),
      height: ui(60),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF111111), Color(0xFF39283D)],
        ),
        border: Border.all(color: const Color(0xFFC3C3C3), width: ui(3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x44000000),
            blurRadius: ui(4.7),
            offset: Offset(ui(4.7), ui(4.7)),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(28),
          color: const Color(0xFFABA1B7),
          fontFamily: 'Barlow',
          fontWeight: FontWeight.w600,
          height: 1.0,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

enum _PillTone { normal, danger }

class _DarkRecordingPill extends StatelessWidget {
  const _DarkRecordingPill({
    this.label,
    this.icon,
    this.tone = _PillTone.normal,
    this.onTap,
  }) : assert(label != null || icon != null);

  final String? label;
  final IconData? icon;
  final _PillTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(12)),
        child: Container(
          width: ui(108),
          height: ui(56),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Colors.white, Color(0xFFE6E6E6)],
            ),
            borderRadius: BorderRadius.circular(ui(12)),
            border: Border.all(color: const Color(0xFFD7D7D7), width: ui(3)),
            boxShadow: [
              BoxShadow(
                color: const Color(0x55FFFFFF),
                blurRadius: ui(2.4),
                offset: Offset(ui(1), ui(3)),
              ),
            ],
          ),
          child: _buildContent(context, ui),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, double Function(num) ui) {
    if (label != null) {
      return Text(
        label!,
        style: TextStyle(
          fontSize: ui(16),
          color: const Color(0xFF0B081A),
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
      );
    }
    final color = tone == _PillTone.danger
        ? const Color(0xFFFF323C)
        : const Color(0xFF0B081A);
    if (tone == _PillTone.danger) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(5),
            height: ui(20),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(ui(1)),
            ),
          ),
          SizedBox(width: ui(4)),
          Container(
            width: ui(5),
            height: ui(20),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(ui(1)),
            ),
          ),
        ],
      );
    }
    return Icon(icon, size: ui(22), color: color);
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(10)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: const Color(0xFFFFD7D7)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: ui(18),
            color: const Color(0xFFE85454),
          ),
          SizedBox(width: ui(8)),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFFAA3E3E),
                fontFamily: 'PingFang SC',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 保存录音文件 弹窗 / 分享弹窗
// ===========================================================================

class _SaveRecordingDialog extends ConsumerWidget {
  const _SaveRecordingDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingSystemControllerProvider);
    final controller = ref.read(recordingSystemControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;
    const labels = <String>['原声', '考场', '录音棚', '音乐厅'];
    const thumbs = <String>[
      AppAssets.soundEffectOriginal,
      AppAssets.soundEffectExamHall,
      AppAssets.soundEffectStudio,
      AppAssets.soundEffectConcert,
    ];

    return Material(
      color: const Color(0xCC000000),
      child: Center(
        child: Container(
          width: ui(428),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ui(24)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFFD2C6FF), Colors.white, Colors.white],
              stops: <double>[0, 0.33, 1],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(ui(24), ui(36), ui(24), ui(28)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    '保存录音文件',
                    style: TextStyle(
                      fontSize: ui(22),
                      color: const Color(0xFF0B081A),
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                  ),
                ),
                SizedBox(height: ui(28)),
                Text(
                  '您可选择喜欢的音效',
                  style: TextStyle(
                    fontSize: ui(14),
                    color: const Color(0xFF0B081A),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                    height: 20 / 14,
                  ),
                ),
                SizedBox(height: ui(12)),
                Row(
                  children: List<Widget>.generate(labels.length, (index) {
                    final active = state.selectedEffectIndex == index;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index == labels.length - 1 ? 0 : ui(12),
                        ),
                        child: _EffectThumb(
                          imageAsset: thumbs[index],
                          active: active,
                          onTap: () => controller.selectEffect(index),
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: ui(8)),
                Row(
                  children: List<Widget>.generate(labels.length, (index) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index == labels.length - 1 ? 0 : ui(12),
                        ),
                        child: Text(
                          labels[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: ui(14),
                            color: const Color(0xFF0B081A),
                            fontFamily: 'PingFang SC',
                            fontWeight: FontWeight.w400,
                            height: 20 / 14,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: ui(20)),
                Text(
                  '请选择文件夹',
                  style: TextStyle(
                    fontSize: ui(14),
                    color: const Color(0xFF0B081A),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                    height: 20 / 14,
                  ),
                ),
                SizedBox(height: ui(8)),
                _CategoryDropdown(
                  categories: state.categories,
                  selectedId: state.selectedSaveCategoryId,
                  onChanged: controller.updateSelectedSaveCategory,
                ),
                SizedBox(height: ui(16)),
                Text(
                  '作品名称',
                  style: TextStyle(
                    fontSize: ui(14),
                    color: const Color(0xFF0B081A),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                    height: 20 / 14,
                  ),
                ),
                SizedBox(height: ui(8)),
                _SaveTitleField(
                  initialValue: state.pendingTitle,
                  onChanged: controller.updatePendingTitle,
                ),
                SizedBox(height: ui(24)),
                Row(
                  children: [
                    Expanded(
                      child: _DialogActionButton(
                        label: '取消',
                        primary: false,
                        onTap: controller.closeSaveDialog,
                      ),
                    ),
                    SizedBox(width: ui(16)),
                    Expanded(
                      child: _DialogActionButton(
                        label: '确认',
                        primary: true,
                        onTap: () async {
                          final message = await controller
                              .saveCurrentRecording();
                          if (context.mounted) {
                            _showMessage(context, message ?? '录音已保存');
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EffectThumb extends StatelessWidget {
  const _EffectThumb({
    required this.imageAsset,
    required this.active,
    required this.onTap,
  });

  final String imageAsset;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B081A),
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(
              color: active ? const Color(0xFF8741FF) : const Color(0xFFF5F6FA),
              width: ui(active ? 3 : 1),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(imageAsset, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
  });

  final List<RecordingCategoryItem> categories;
  final int selectedId;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(48),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value:
              selectedId > 0 && categories.any((item) => item.id == selectedId)
              ? selectedId
              : null,
          hint: Text(
            '请选择',
            style: TextStyle(
              fontSize: ui(14),
              color: const Color(0xFFCECED1),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
              height: 20 / 14,
            ),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: ui(20),
            color: const Color(0xFF0B081A),
          ),
          items: categories
              .map(
                (item) => DropdownMenuItem<int>(
                  value: item.id,
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: ui(14),
                      color: const Color(0xFF0B081A),
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}

class _SaveTitleField extends StatefulWidget {
  const _SaveTitleField({required this.initialValue, required this.onChanged});

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_SaveTitleField> createState() => _SaveTitleFieldState();
}

class _SaveTitleFieldState extends State<_SaveTitleField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _SaveTitleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.initialValue,
        selection: TextSelection.collapsed(offset: widget.initialValue.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(48),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: TextStyle(
          fontSize: ui(14),
          color: const Color(0xFF0B081A),
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: '请输入文件名称',
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: const Color(0xFFCECED1),
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
            height: 20 / 14,
          ),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: ui(16),
            vertical: ui(14),
          ),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(8)),
            borderSide: BorderSide(
              color: const Color(0xFFF3F2F3),
              width: ui(1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(8)),
            borderSide: BorderSide(
              color: const Color(0xFFD9C7FF),
              width: ui(1),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(45),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
                )
              : null,
          color: primary ? null : Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: primary
              ? null
              : Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
          boxShadow: [
            BoxShadow(
              color: primary
                  ? const Color(0x59AD80FF)
                  : const Color(0x59B5B5B5),
              blurRadius: ui(20),
              offset: Offset(0, ui(16)),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(16),
            color: primary ? Colors.white : const Color(0xFF0B081A),
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
            height: 12 / 16,
          ),
        ),
      ),
    );
  }
}

class _ShareRecordingDialog extends ConsumerWidget {
  const _ShareRecordingDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingSystemControllerProvider);
    final controller = ref.read(recordingSystemControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;

    return Material(
      color: const Color(0xCC000000),
      child: Center(
        child: Container(
          width: ui(420),
          padding: EdgeInsets.fromLTRB(ui(24), ui(24), ui(24), ui(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '分享到班级',
                    style: TextStyle(
                      fontSize: ui(18),
                      color: const Color(0xFF0B081A),
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: controller.closeShareDialog,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              SizedBox(height: ui(8)),
              Text(
                '选择需要分享的班级后，系统会逐个发送录音作品。',
                style: TextStyle(
                  fontSize: ui(13),
                  color: const Color(0xFF7C8496),
                  fontFamily: 'PingFang SC',
                ),
              ),
              SizedBox(height: ui(18)),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: ui(280)),
                child: state.shareClasses.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: ui(24)),
                          child: Text(
                            '暂无可分享的班级',
                            style: TextStyle(
                              fontSize: ui(14),
                              color: const Color(0xFF99A0B0),
                              fontFamily: 'PingFang SC',
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: state.shareClasses.length,
                        separatorBuilder: (_, _) => SizedBox(height: ui(8)),
                        itemBuilder: (context, index) {
                          final item = state.shareClasses[index];
                          return InkWell(
                            onTap: () => controller.toggleShareClass(item.id),
                            borderRadius: BorderRadius.circular(ui(14)),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ui(14),
                                vertical: ui(12),
                              ),
                              decoration: BoxDecoration(
                                color: item.selected
                                    ? const Color(0xFFF3EEFF)
                                    : const Color(0xFFF8FAFF),
                                borderRadius: BorderRadius.circular(ui(14)),
                                border: Border.all(
                                  color: item.selected
                                      ? const Color(0xFFB18BFF)
                                      : const Color(0xFFE7EBF5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item.selected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: item.selected
                                        ? const Color(0xFF8B5CFF)
                                        : const Color(0xFFB5BDCF),
                                  ),
                                  SizedBox(width: ui(10)),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: TextStyle(
                                        fontSize: ui(14),
                                        color: const Color(0xFF0B081A),
                                        fontFamily: 'PingFang SC',
                                        fontWeight: FontWeight.w500,
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
              SizedBox(height: ui(20)),
              Row(
                children: [
                  Expanded(
                    child: _DialogActionButton(
                      label: '取消',
                      primary: false,
                      onTap: controller.closeShareDialog,
                    ),
                  ),
                  SizedBox(width: ui(16)),
                  Expanded(
                    child: _DialogActionButton(
                      label: '确认分享',
                      primary: true,
                      onTap: () async {
                        final message = await controller.sendShare();
                        if (context.mounted) {
                          _showMessage(context, message ?? '分享成功');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// 分类右上角 ··· 弹出菜单
// ===========================================================================

enum _RecordingMenuAction { rename, share, copy, delete }

enum _RecordingItemAction { preview, share, delete }

Future<_RecordingMenuAction?> _showRecordingActionMenu({
  required BuildContext context,
  required GlobalKey triggerKey,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final triggerBox =
      triggerKey.currentContext?.findRenderObject() as RenderBox?;
  final overlayBox = overlay.context.findRenderObject() as RenderBox;
  if (triggerBox == null) {
    return null;
  }
  final triggerSize = triggerBox.size;
  final triggerCenter = triggerBox.localToGlobal(
    triggerSize.center(Offset.zero),
    ancestor: overlayBox,
  );
  final ui = DashboardScaleScope.of(context).ui;
  final menuWidth = ui(180);
  final menuHeight = ui(206);
  final overlaySize = overlayBox.size;
  var dx = triggerCenter.dx - ui(8);
  var dy = triggerCenter.dy - ui(6);
  if (dx + menuWidth > overlaySize.width - ui(8)) {
    dx = overlaySize.width - menuWidth - ui(8);
  }
  if (dy + menuHeight > overlaySize.height - ui(8)) {
    dy = overlaySize.height - menuHeight - ui(8);
  }
  return showMenu<_RecordingMenuAction>(
    context: context,
    position: RelativeRect.fromLTRB(dx, dy, dx + menuWidth, dy + menuHeight),
    color: Colors.transparent,
    elevation: 0,
    items: [
      PopupMenuItem<_RecordingMenuAction>(
        padding: EdgeInsets.zero,
        enabled: false,
        child: _RecordingActionMenuPanel(
          width: menuWidth,
          onSelect: (action) =>
              Navigator.of(context, rootNavigator: true).pop(action),
        ),
      ),
    ],
  );
}

class _RecordingActionMenuPanel extends StatelessWidget {
  const _RecordingActionMenuPanel({
    required this.width,
    required this.onSelect,
  });

  final double width;
  final ValueChanged<_RecordingMenuAction> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: ui(24),
            offset: Offset(0, ui(8)),
          ),
          BoxShadow(
            color: const Color(0x09000000),
            blurRadius: ui(4),
            offset: Offset(0, ui(2)),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MenuRow(
            icon: Icons.drive_file_rename_outline_rounded,
            label: '重命名',
            onTap: () => onSelect(_RecordingMenuAction.rename),
          ),
          _MenuRow(
            icon: Icons.share_outlined,
            label: '分享',
            onTap: () => onSelect(_RecordingMenuAction.share),
          ),
          _MenuRow(
            icon: Icons.copy_rounded,
            label: '复制',
            onTap: () => onSelect(_RecordingMenuAction.copy),
          ),
          Divider(
            height: ui(1),
            thickness: ui(1),
            color: const Color(0xFFF5F6FA),
          ),
          _MenuRow(
            icon: Icons.delete_outline_rounded,
            label: '删除',
            danger: true,
            onTap: () => onSelect(_RecordingMenuAction.delete),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final color = danger ? const Color(0xFFFF323C) : const Color(0xFF0B081A);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(12)),
        child: Row(
          children: [
            Icon(icon, size: ui(18), color: color),
            SizedBox(width: ui(10)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(14),
                color: color,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 工具方法
// ===========================================================================

List<double> _stretchBars(List<double> source, int targetLength) {
  if (source.isEmpty) {
    return _buildFallbackBars(targetLength, seed: 3);
  }
  if (source.length == targetLength) {
    return source;
  }
  return List<double>.generate(targetLength, (index) {
    final mapped = (index / targetLength) * source.length;
    final sourceIndex = mapped.floor().clamp(0, source.length - 1);
    return source[sourceIndex].clamp(0.05, 1.0).toDouble();
  });
}

List<double> _buildFallbackBars(int count, {required int seed}) {
  final random = math.Random(seed);
  return List<double>.generate(
    count,
    (index) => 0.12 + random.nextDouble() * (index % 7 == 0 ? 0.65 : 0.34),
  );
}

int _parseDurationLabel(String raw) {
  final cleaned = raw.trim();
  if (cleaned.isEmpty) {
    return 0;
  }
  final dot = RegExp(r'^(\d+):(\d+)\.(\d+)$').firstMatch(cleaned);
  if (dot != null) {
    final minutes = int.tryParse(dot.group(1)!) ?? 0;
    final seconds = int.tryParse(dot.group(2)!) ?? 0;
    final centiseconds = int.tryParse(dot.group(3)!) ?? 0;
    return minutes * 60000 + seconds * 1000 + centiseconds * 10;
  }
  final parts = cleaned.split(':');
  if (parts.length == 3) {
    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    final centiseconds = int.tryParse(parts[2]) ?? 0;
    return minutes * 60000 + seconds * 1000 + centiseconds * 10;
  }
  if (parts.length == 2) {
    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    return minutes * 60000 + seconds * 1000;
  }
  return 0;
}

String _formatClock(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  final centiseconds = ((milliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
  return '$minutes:$seconds:$centiseconds';
}

String _formatSecondsClock(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(1, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

extension _ListFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
