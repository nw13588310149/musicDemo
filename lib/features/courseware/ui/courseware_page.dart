import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/cloud_drive_controller.dart';
import '../state/cloud_drive_state.dart';

class MyCloudDrivePage extends ConsumerStatefulWidget {
  const MyCloudDrivePage({super.key});

  @override
  ConsumerState<MyCloudDrivePage> createState() => _MyCloudDrivePageState();
}

class _MyCloudDrivePageState extends ConsumerState<MyCloudDrivePage> {
  late final TextEditingController _searchController;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final value = _searchController.text.trim();
    if (value == _keyword) {
      return;
    }
    setState(() {
      _keyword = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cloudDriveControllerProvider);
    final controller = ref.read(cloudDriveControllerProvider.notifier);
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;

        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: contentWidth,
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
                      child: _CloudSidebar(
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
                        child: _CloudContentArea(
                          state: state,
                          keyword: _keyword,
                          searchController: _searchController,
                          onRefresh: controller.refresh,
                          onSortChanged: controller.setSortType,
                          onBackToOverview: controller.backToOverview,
                          onOpenFolder: controller.openFolder,
                          onCreateFolder: _showCreateFolderDialog,
                          onFolderAction: _handleFolderAction,
                          onFileAction: _handleFileAction,
                          onToggleSelectAll: controller.toggleSelectAllDisplayed,
                          onToggleFileSelection: controller.toggleFileSelection,
                          onUpload: _showUploadDialog,
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
        .read(cloudDriveControllerProvider.notifier)
        .addCategory(name);
    if (!mounted) {
      return;
    }
    _showMessage(message ?? '分类已添加');
  }

  Future<void> _showCreateFolderDialog() async {
    final name = await showTextInputDialog(
      context: context,
      title: '新建文件夹',
      hintText: '请输入文件夹名称',
      confirmLabel: '创建',
    );
    if (name == null || name.isEmpty) {
      return;
    }
    ref.read(cloudDriveControllerProvider.notifier).createLocalFolder(name);
    _showMessage('文件夹已创建');
  }

  Future<void> _handleCategoryAction(
    CloudCategoryItem item,
    _CloudMenuAction action,
  ) async {
    final controller = ref.read(cloudDriveControllerProvider.notifier);
    switch (action) {
      case _CloudMenuAction.rename:
        final nextName = await showTextInputDialog(
          context: context,
          title: '重命名分类',
          hintText: '请输入新的分类名称',
          initialValue: item.name,
          confirmLabel: '保存',
        );
        if (nextName == null || nextName.isEmpty) {
          return;
        }
        controller.renameCategoryLocal(item.id, nextName);
        _showMessage('分类名称已更新');
        break;
      case _CloudMenuAction.share:
        _showMessage('分类分享能力待接入');
        break;
      case _CloudMenuAction.copy:
        controller.duplicateCategoryLocal(item.id);
        _showMessage('已复制分类');
        break;
      case _CloudMenuAction.delete:
        final confirmed = await showConfirmDialog(
          context: context,
          title: '删除分类',
          content: '删除后将移除该分类下的视图内容，确认继续吗？',
          confirmLabel: '删除',
        );
        if (!confirmed) {
          return;
        }
        final message = await controller.deleteCategory(item.id);
        if (!mounted) {
          return;
        }
        _showMessage(message ?? '分类已删除');
        break;
    }
  }

  Future<void> _handleFolderAction(
    CloudFolderItem item,
    _CloudMenuAction action,
  ) async {
    final controller = ref.read(cloudDriveControllerProvider.notifier);
    switch (action) {
      case _CloudMenuAction.rename:
        final nextName = await showTextInputDialog(
          context: context,
          title: '重命名文件夹',
          hintText: '请输入新的文件夹名称',
          initialValue: item.title,
          confirmLabel: '保存',
        );
        if (nextName == null || nextName.isEmpty) {
          return;
        }
        controller.renameFolderLocal(item.id, nextName);
        _showMessage('文件夹名称已更新');
        break;
      case _CloudMenuAction.share:
        _showMessage('文件夹分享能力待接入');
        break;
      case _CloudMenuAction.copy:
        controller.duplicateFolderLocal(item.id);
        _showMessage('已复制文件夹');
        break;
      case _CloudMenuAction.delete:
        final confirmed = await showConfirmDialog(
          context: context,
          title: '删除文件夹',
          content: '删除后不可恢复，确认删除这个文件夹吗？',
          confirmLabel: '删除',
        );
        if (!confirmed) {
          return;
        }
        controller.deleteFolderLocal(item.id);
        _showMessage('文件夹已删除');
        break;
    }
  }

  Future<void> _handleFileAction(
    CloudFileItem item,
    _CloudFileAction action,
  ) async {
    final controller = ref.read(cloudDriveControllerProvider.notifier);
    switch (action) {
      case _CloudFileAction.preview:
        await _showPreviewDialog(item);
        break;
      case _CloudFileAction.share:
        final classes = await controller.fetchShareClasses();
        if (!mounted) {
          return;
        }
        if (classes.isEmpty) {
          _showMessage('暂无可分享的班级');
          return;
        }
        final selectedIds = await _showShareDialog(classes);
        if (selectedIds.isEmpty) {
          return;
        }
        final message = await controller.shareCourseware(
          file: item,
          classIds: selectedIds,
        );
        if (!mounted) {
          return;
        }
        _showMessage(message ?? '资料已分享');
        break;
      case _CloudFileAction.delete:
        final confirmed = await showConfirmDialog(
          context: context,
          title: '删除资料',
          content: '删除后不可恢复，确认删除“${item.title}”吗？',
          confirmLabel: '删除',
        );
        if (!confirmed) {
          return;
        }
        final message = await controller.deleteCourseware(item.id);
        if (!mounted) {
          return;
        }
        _showMessage(message ?? '资料已删除');
        break;
      case _CloudFileAction.play:
        controller.togglePlaying(item.id);
        break;
    }
  }

  Future<void> _showUploadDialog() async {
    final controller = ref.read(cloudDriveControllerProvider.notifier);
    final titleController = TextEditingController();
    var kind = CloudUploadKind.image;
    var uploadedUrl = '';

    await showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setDialogState) {
            final ui = DashboardScaleScope.of(innerContext).ui;
            final uploadLabel = switch (kind) {
              CloudUploadKind.image => '图片',
              CloudUploadKind.score => '谱例',
              CloudUploadKind.courseware => '文件',
            };
            final uploadHint = switch (kind) {
              CloudUploadKind.image => '请输入图片链接',
              CloudUploadKind.score => '请输入谱例文件链接',
              CloudUploadKind.courseware => '请输入课件文件链接',
            };
            final uploadIcon = kind == CloudUploadKind.image
                ? AppAssets.coursewareUploadImage
                : AppAssets.coursewareUploadFile;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: ui(32),
                vertical: ui(24),
              ),
              child: Container(
                width: ui(420),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0xFFD2C6FF),
                      Colors.white,
                      Colors.white,
                    ],
                    stops: <double>[0, 0.21, 1],
                  ),
                  borderRadius: BorderRadius.circular(ui(24)),
                ),
                child: Stack(
                  children: [
                    // 顶部装饰大图：宽度铺满，居中
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: Image.asset(
                        AppAssets.coursewareUploadHeader,
                        fit: BoxFit.fitWidth,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        ui(20),
                        ui(22),
                        ui(20),
                        ui(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              '上传课件',
                              style: TextStyle(
                                fontSize: ui(18),
                                color: const Color(0xFF0B081A),
                                fontFamily: 'PingFang SC',
                                fontWeight: FontWeight.w600,
                                height: 1.0,
                              ),
                            ),
                          ),
                          SizedBox(height: ui(30)),
                          Text(
                            '课件标题',
                            style: TextStyle(
                              fontSize: ui(14),
                              color: const Color(0xFF0B081A),
                              fontFamily: 'PingFang SC',
                              fontWeight: FontWeight.w500,
                              height: 12 / 14,
                            ),
                          ),
                          SizedBox(height: ui(10)),
                          SizedBox(
                            height: ui(45),
                            child: TextField(
                              controller: titleController,
                              style: TextStyle(
                                fontSize: ui(14),
                                color: const Color(0xFF0B081A),
                                fontFamily: 'PingFang SC',
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: InputDecoration(
                                hintText: '请输入课件标题',
                                hintStyle: TextStyle(
                                  fontSize: ui(14),
                                  color: const Color(0xFFB6B5BB),
                                  fontFamily: 'PingFang SC',
                                  fontWeight: FontWeight.w400,
                                  height: 12 / 14,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: ui(13),
                                  vertical: ui(12),
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
                          ),
                          SizedBox(height: ui(18)),
                          Text(
                            '选择分类',
                            style: TextStyle(
                              fontSize: ui(14),
                              color: const Color(0xFF0B081A),
                              fontFamily: 'PingFang SC',
                              fontWeight: FontWeight.w500,
                              height: 12 / 14,
                            ),
                          ),
                          SizedBox(height: ui(12)),
                          Row(
                            children: CloudUploadKind.values.map((item) {
                              final selected = item == kind;
                              final label = switch (item) {
                                CloudUploadKind.image => '图片',
                                CloudUploadKind.score => '谱例',
                                CloudUploadKind.courseware => '课件',
                              };
                              return Padding(
                                padding: EdgeInsets.only(
                                  right: item == CloudUploadKind.courseware
                                      ? 0
                                      : ui(13),
                                ),
                                child: _UploadKindOption(
                                  label: label,
                                  selected: selected,
                                  onTap: () => setDialogState(() {
                                    kind = item;
                                    uploadedUrl = '';
                                  }),
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: ui(18)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '上传文件',
                                style: TextStyle(
                                  fontSize: ui(14),
                                  color: const Color(0xFF0B081A),
                                  fontFamily: 'PingFang SC',
                                  fontWeight: FontWeight.w500,
                                  height: 1.0,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '*支持 PDF/Word/图片/HTML，图片支持15M以内',
                                style: TextStyle(
                                  fontSize: ui(12),
                                  color: const Color(0xFFCECED1),
                                  fontFamily: 'PingFang SC',
                                  fontWeight: FontWeight.w400,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: ui(10)),
                          InkWell(
                            onTap: () async {
                              final value = await showTextInputDialog(
                                context: innerContext,
                                title: '上传$uploadLabel',
                                hintText: uploadHint,
                                confirmLabel: '确认',
                                initialValue: uploadedUrl,
                              );
                              if (value == null || value.isEmpty) {
                                return;
                              }
                              setDialogState(() => uploadedUrl = value);
                            },
                            borderRadius: BorderRadius.circular(ui(12)),
                            child: Container(
                              width: double.infinity,
                              height: ui(140),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F4FF),
                                borderRadius: BorderRadius.circular(ui(12)),
                                border: Border.all(
                                  color: const Color(0xFFF3F2F3),
                                  width: ui(1),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    uploadIcon,
                                    width: ui(56),
                                    height: ui(56),
                                    fit: BoxFit.contain,
                                  ),
                                  SizedBox(height: ui(8)),
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: ui(14),
                                        fontFamily: 'PingFang SC',
                                        fontWeight: FontWeight.w400,
                                        height: 1.0,
                                      ),
                                      children: <InlineSpan>[
                                        const TextSpan(
                                          text: '点击将',
                                          style: TextStyle(
                                            color: Color(0xFFB6B5BB),
                                          ),
                                        ),
                                        TextSpan(
                                          text: uploadLabel,
                                          style: const TextStyle(
                                            color: Color(0xFF0B081A),
                                          ),
                                        ),
                                        const TextSpan(
                                          text: '在此处上传',
                                          style: TextStyle(
                                            color: Color(0xFFB6B5BB),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (uploadedUrl.isNotEmpty) ...[
                                    SizedBox(height: ui(8)),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: ui(14),
                                      ),
                                      child: Text(
                                        uploadedUrl,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: ui(11),
                                          color: const Color(0xFF8F86A8),
                                          fontFamily: 'PingFang SC',
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: ui(20)),
                          AppDialogActionBar(
                            onCancel: () => Navigator.of(dialogContext).pop(),
                            onConfirm: () async {
                              // 在 await 之前缓存 Navigator，避免 lint 警告
                              final dialogNavigator = Navigator.of(
                                dialogContext,
                              );
                              final message = await controller.addCourseware(
                                title: titleController.text,
                                type: kind == CloudUploadKind.courseware
                                    ? CloudFileType.courseware
                                    : CloudFileType.score,
                                audioUrl: kind == CloudUploadKind.image
                                    ? ''
                                    : uploadedUrl,
                                imageInput: kind == CloudUploadKind.image
                                    ? uploadedUrl
                                    : '',
                              );
                              if (!mounted) {
                                return;
                              }
                              if (message != null) {
                                _showMessage(message);
                                return;
                              }
                              dialogNavigator.pop();
                              _showMessage('资料已上传');
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
  }

  Future<void> _showPreviewDialog(CloudFileItem item) async {
    await showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (dialogContext) {
        final ui = DashboardScaleScope.of(dialogContext).ui;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: ui(32),
            vertical: ui(24),
          ),
          child: Container(
            width: ui(360),
            padding: EdgeInsets.fromLTRB(ui(24), ui(24), ui(24), ui(20)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(24)),
              border: Border.all(color: const Color(0xFFF3F2F3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '资料预览',
                      style: TextStyle(
                        fontSize: ui(20),
                        color: const Color(0xFF1A1A1A),
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.type.label,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: const Color(0xFF8741FF),
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ui(18)),
                Center(
                  child: SizedBox(
                    width: ui(150),
                    height: ui(112),
                    child: _FileArtwork(item: item, compact: false),
                  ),
                ),
                SizedBox(height: ui(18)),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: ui(18),
                    height: 1.3,
                    color: const Color(0xFF1A1A1A),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: ui(12)),
                _InfoRow(label: '文件大小', value: item.sizeLabel),
                _InfoRow(label: '上传时间', value: item.dateLabel),
                if (item.audioUrl.isNotEmpty)
                  _InfoRow(label: '资料链接', value: item.audioUrl),
                SizedBox(height: ui(18)),
                SizedBox(
                  width: double.infinity,
                  child: _DialogActionButton(
                    label: '关闭',
                    foregroundColor: Colors.white,
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
                    ),
                    onTap: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<int>> _showShareDialog(List<CloudShareClassItem> classes) async {
    final selected = <int>{};
    final result = await showScaledDialog<List<int>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setDialogState) {
            final ui = DashboardScaleScope.of(innerContext).ui;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: ui(32),
                vertical: ui(24),
              ),
              child: Container(
                width: ui(360),
                padding: EdgeInsets.fromLTRB(ui(24), ui(24), ui(24), ui(20)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(24)),
                  border: Border.all(color: const Color(0xFFF3F2F3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '分享至班级',
                      style: TextStyle(
                        fontSize: ui(20),
                        color: const Color(0xFF1A1A1A),
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: ui(16)),
                    Container(
                      constraints: BoxConstraints(maxHeight: ui(260)),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FD),
                        borderRadius: BorderRadius.circular(ui(16)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.all(ui(12)),
                        itemCount: classes.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: ui(8)),
                        itemBuilder: (context, index) {
                          final item = classes[index];
                          final isSelected = selected.contains(item.id);
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  selected.remove(item.id);
                                } else {
                                  selected.add(item.id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(ui(12)),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ui(12),
                                vertical: ui(12),
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFF4F0FF)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(ui(12)),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFB68EFF)
                                      : const Color(0xFFE8ECF5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _SelectionBox(selected: isSelected),
                                  SizedBox(width: ui(10)),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: TextStyle(
                                        fontSize: ui(14),
                                        color: const Color(0xFF1A1A1A),
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
                    SizedBox(height: ui(18)),
                    Row(
                      children: [
                        Expanded(
                          child: _DialogActionButton(
                            label: '取消',
                            foregroundColor: const Color(0xFF788698),
                            backgroundColor: const Color(0xFFF5F6FA),
                            onTap: () =>
                                Navigator.of(dialogContext).pop(const <int>[]),
                          ),
                        ),
                        SizedBox(width: ui(12)),
                        Expanded(
                          child: _DialogActionButton(
                            label: '确认分享',
                            foregroundColor: Colors.white,
                            gradient: const LinearGradient(
                              colors: <Color>[
                                Color(0xFFB68EFF),
                                Color(0xFF8640FF),
                              ],
                            ),
                            onTap: () => Navigator.of(
                              dialogContext,
                            ).pop(selected.toList()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    return result ?? const <int>[];
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

class _CloudSidebar extends StatelessWidget {
  const _CloudSidebar({
    required this.state,
    required this.onSelectCategory,
    required this.onAddCategory,
    required this.onCategoryAction,
  });

  final CloudDriveState state;
  final ValueChanged<int> onSelectCategory;
  final VoidCallback onAddCategory;
  final Future<void> Function(CloudCategoryItem item, _CloudMenuAction action)
  onCategoryAction;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final totalFiles = state.categories.fold<int>(0, (sum, item) => sum + item.count);
    final usedPercent = totalFiles == 0 ? 32 : totalFiles.clamp(12, 85);

    return Padding(
      padding: EdgeInsets.fromLTRB(ui(8), ui(8), ui(8), ui(10)),
      child: Column(
        children: [
          Expanded(
            child: state.loading && state.categories.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : ListView.separated(
                    itemCount: state.categories.length,
                    separatorBuilder: (context, index) =>
                        SizedBox(height: ui(8)),
                    itemBuilder: (context, index) {
                      final item = state.categories[index];
                      return _CategoryCard(
                        item: item,
                        selected: item.id == state.selectedCategoryId,
                        onTap: () => onSelectCategory(item.id),
                        onAction: (action) => onCategoryAction(item, action),
                      );
                    },
                  ),
          ),
          SizedBox(height: ui(12)),
          _StorageUsageCard(percent: usedPercent.toDouble()),
          SizedBox(height: ui(12)),
          _AddCategoryCard(onTap: onAddCategory),
        ],
      ),
    );
  }
}

class _CloudContentArea extends StatelessWidget {
  const _CloudContentArea({
    required this.state,
    required this.keyword,
    required this.searchController,
    required this.onRefresh,
    required this.onSortChanged,
    required this.onBackToOverview,
    required this.onOpenFolder,
    required this.onCreateFolder,
    required this.onFolderAction,
    required this.onFileAction,
    required this.onToggleSelectAll,
    required this.onToggleFileSelection,
    required this.onUpload,
  });

  final CloudDriveState state;
  final String keyword;
  final TextEditingController searchController;
  final Future<void> Function() onRefresh;
  final ValueChanged<CloudDriveSortType> onSortChanged;
  final VoidCallback onBackToOverview;
  final ValueChanged<CloudFolderItem> onOpenFolder;
  final VoidCallback onCreateFolder;
  final Future<void> Function(CloudFolderItem item, _CloudMenuAction action)
  onFolderAction;
  final Future<void> Function(CloudFileItem item, _CloudFileAction action)
  onFileAction;
  final ValueChanged<List<int>> onToggleSelectAll;
  final ValueChanged<int> onToggleFileSelection;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final selectedCategoryName = state.selectedCategory?.name ?? '声乐教学';
    final visibleFolders = state.folders
        .where((item) => keyword.isEmpty || item.title.contains(keyword))
        .toList();
    final visibleFiles = state.files
        .where((item) => keyword.isEmpty || item.title.contains(keyword))
        .toList();
    final visibleFileIds = visibleFiles.map((item) => item.id).toList();
    final selectedCount = state.selectedFileIds.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(ui(30), ui(28), ui(20), ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.isFolderView)
            _FolderBreadcrumb(
              items: <String>[
                '我的云盘',
                selectedCategoryName,
                state.currentFolderName,
              ],
              // 第 0 / 1 级（"我的云盘" 与 当前分类名）都回到该分类的
              // 文件夹列表（退出文件夹详情视图）。第 2 级是当前所在文件夹，
              // _FolderBreadcrumb 内部已自动屏蔽末位条目的点击。
              onItemTap: (_) => onBackToOverview(),
            )
          else
            Text(
              selectedCategoryName,
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
                child: _CloudSearchField(controller: searchController),
              ),
              const Spacer(),
              _ToolbarActionButton(
                icon: Icons.swap_vert_rounded,
                imageAsset: AppAssets.coursewareSort,
                label: '排序',
                onTap: () => onSortChanged(state.sortType),
              ),
              SizedBox(width: ui(12)),
              _ToolbarActionButton(
                icon: Icons.refresh_rounded,
                imageAsset: AppAssets.coursewareRefresh,
                label: '刷新',
                onTap: () => onRefresh(),
              ),
            ],
          ),
          SizedBox(height: ui(14)),
          if (state.isFolderView) ...[
            _SelectionInfoBar(
              selectedCount: selectedCount,
              totalCount: visibleFiles.length,
              allSelected:
                  visibleFileIds.isNotEmpty &&
                  visibleFileIds.every(state.selectedFileIds.contains),
              onToggleAll: () => onToggleSelectAll(visibleFileIds),
            ),
          ],
          SizedBox(height: ui(16)),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: state.loading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : state.isFolderView
                      ? _CloudFilesGrid(
                          items: visibleFiles,
                          onAction: onFileAction,
                        )
                      : _CloudFoldersGrid(
                          items: visibleFolders,
                          onOpenFolder: (folder) {
                            if (folder.isCreateShortcut) {
                              onCreateFolder();
                              return;
                            }
                            onOpenFolder(folder);
                          },
                        ),
                ),
                Positioned(
                  right: 0,
                  bottom: ui(8),
                  child: _FloatingCreateButton(
                    label: state.isFolderView ? '上传资料' : '新建文件夹',
                    iconAsset: state.isFolderView
                        ? AppAssets.coursewareUploadFab
                        : AppAssets.coursewareNewFolder,
                    onTap: state.isFolderView ? onUpload : onCreateFolder,
                  ),
                ),
              ],
            ),
          ),
          if (state.errorMessage.isNotEmpty) ...[
            SizedBox(height: ui(10)),
            Text(
              state.errorMessage,
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
}

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onAction,
  });

  final CloudCategoryItem item;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<_CloudMenuAction> onAction;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  final GlobalKey _menuTriggerKey = GlobalKey();

  Future<void> _openActionMenu() async {
    final action = await _showCloudActionMenu(
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
                    selected
                        ? '已存储${item.count}个文件'
                        : '已存储 ${item.count} 个文件',
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

class _StorageUsageCard extends StatelessWidget {
  const _StorageUsageCard({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final safePercent = percent.clamp(0, 100);
    return Container(
      padding: EdgeInsets.fromLTRB(ui(9), ui(8), ui(9), ui(8)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '云盘存储',
                style: TextStyle(
                  fontSize: ui(11),
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w500,
                  height: 12 / 11,
                ),
              ),
              SizedBox(width: ui(8)),
              Text(
                '168GB可用/512GB',
                style: TextStyle(
                  fontSize: ui(10),
                  color: const Color(0xFFB6B5BB),
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w400,
                  height: 12 / 10,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(8)),
          ClipRRect(
            borderRadius: BorderRadius.circular(ui(23)),
            child: SizedBox(
              height: ui(4),
              child: Stack(
                children: [
                  Container(color: const Color(0xFFF0EBFA)),
                  FractionallySizedBox(
                    widthFactor: safePercent / 100,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[Color(0xFFD4BFFF), Color(0xFFB184FF)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      borderRadius: BorderRadius.circular(ui(8)),
      child: Ink(
        height: ui(60),
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui(8)),
          color: const Color(0xFFF5F6FA),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              AppAssets.cloudAddCategory,
              width: ui(18),
              height: ui(18),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(6)),
            Text(
              '添加分类',
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

class _FolderBreadcrumb extends StatelessWidget {
  const _FolderBreadcrumb({
    required this.items,
    required this.onItemTap,
  });

  /// 自顶向下的层级文本，例如 ["我的云盘", "声乐教学", "谱例学习第三期汇总"]。
  final List<String> items;

  /// 点击非末位条目时回调，传入被点击条目的索引。
  /// 当 itemIndex 与 [items].length-1 相等时不会触发（即"当前所在层级"不可点）。
  final ValueChanged<int> onItemTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: ui(6),
      runSpacing: ui(6),
      children: List<Widget>.generate(items.length * 2 - 1, (index) {
        if (index.isOdd) {
          return Icon(
            Icons.chevron_right_rounded,
            size: ui(14),
            color: const Color(0xFFB6B5BB),
          );
        }
        final itemIndex = index ~/ 2;
        final label = items[itemIndex];
        final isLast = itemIndex == items.length - 1;
        final text = Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: isLast ? const Color(0xFF1A1A1A) : const Color(0xFF788698),
            fontFamily: 'PingFang SC',
            fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
          ),
        );
        if (isLast) {
          return text;
        }
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onItemTap(itemIndex),
            child: text,
          ),
        );
      }),
    );
  }
}

class _CloudSearchField extends StatelessWidget {
  const _CloudSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(40),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: '传统音乐',
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: const Color(0xFFD1D1D1),
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: ui(16), right: ui(10)),
            child: Image.asset(
              AppAssets.cloudSearch,
              width: ui(18),
              height: ui(18),
              fit: BoxFit.contain,
            ),
          ),
          prefixIconConstraints: BoxConstraints(minWidth: ui(44)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide(color: const Color(0xFFF3F2F3), width: ui(1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide(color: const Color(0xFFF3F2F3), width: ui(1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide(color: const Color(0xFFE3E3E3), width: ui(1)),
          ),
        ),
      ),
    );
  }
}

class _ToolbarActionButton extends StatelessWidget {
  const _ToolbarActionButton({
    required this.icon,
    required this.onTap,
    this.imageAsset,
    this.label,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? imageAsset;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        width: label == null ? ui(40) : null,
        height: ui(40),
        padding: label == null
            ? EdgeInsets.zero
            : EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
        ),
        child: label == null
            ? (imageAsset != null
                  ? Image.asset(
                      imageAsset!,
                      width: ui(16),
                      height: ui(16),
                      fit: BoxFit.contain,
                    )
                  : Icon(icon, size: ui(20), color: const Color(0xFF1A1A1A)))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (imageAsset != null)
                    Image.asset(
                      imageAsset!,
                      width: ui(16),
                      height: ui(16),
                      fit: BoxFit.contain,
                    )
                  else
                    Icon(icon, size: ui(16), color: const Color(0xFF1A1A1A)),
                  SizedBox(width: ui(4)),
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: const Color(0xFF1A1A1A),
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

class _SelectionInfoBar extends StatelessWidget {
  const _SelectionInfoBar({
    required this.selectedCount,
    required this.totalCount,
    required this.allSelected,
    required this.onToggleAll,
  });

  final int selectedCount;
  final int totalCount;
  final bool allSelected;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggleAll,
            child: Container(
              width: ui(12),
              height: ui(12),
              decoration: BoxDecoration(
                color: allSelected ? const Color(0xFF8741FF) : Colors.white,
                borderRadius: BorderRadius.circular(ui(1)),
                border: Border.all(color: const Color(0xFFD9D9D9), width: ui(1)),
              ),
            ),
          ),
          SizedBox(width: ui(10)),
          Text(
            '全选',
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFFB6B5BB),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '已全部加载',
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFFB6B5BB),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: ui(6)),
          Text(
            '$totalCount',
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFF0B081A),
              fontFamily: 'Barlow',
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: ui(6)),
          Text(
            '项',
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFFB6B5BB),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudFoldersGrid extends StatelessWidget {
  const _CloudFoldersGrid({
    required this.items,
    required this.onOpenFolder,
  });

  final List<CloudFolderItem> items;
  final ValueChanged<CloudFolderItem> onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (items.isEmpty) {
      return const _EmptyCloudState(message: '当前分类下还没有文件夹');
    }
    return GridView.builder(
      padding: EdgeInsets.only(bottom: ui(78)),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: ui(176),
        mainAxisSpacing: ui(16),
        crossAxisSpacing: ui(16),
        childAspectRatio: 0.95,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return RepaintBoundary(
          child: _FolderCard(
            item: item,
            onTap: () => onOpenFolder(item),
          ),
        );
      },
    );
  }
}

class _CloudFilesGrid extends StatelessWidget {
  const _CloudFilesGrid({
    required this.items,
    required this.onAction,
  });

  final List<CloudFileItem> items;
  final Future<void> Function(CloudFileItem item, _CloudFileAction action)
  onAction;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (items.isEmpty) {
      return const _EmptyCloudState(message: '当前文件夹下还没有资料');
    }
    return GridView.builder(
      padding: EdgeInsets.only(bottom: ui(78)),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: ui(176),
        mainAxisSpacing: ui(16),
        crossAxisSpacing: ui(16),
        childAspectRatio: 0.9,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return RepaintBoundary(
          child: _FileCard(
            item: item,
            onAction: (action) => onAction(item, action),
          ),
        );
      },
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.item,
    required this.onTap,
  });

  final CloudFolderItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isCreate = item.isCreateShortcut || item.title.contains('新建文件夹');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ui(14)),
              child: Stack(
                children: [
                  Positioned.fill(child: _FolderArtwork(item: item)),
                  Positioned(
                    left: ui(10),
                    bottom: ui(28),
                    child: Text(
                      isCreate ? '' : item.dateLabel,
                      style: TextStyle(
                        fontSize: ui(11),
                        color: const Color(0xFF9C91BE),
                        fontFamily: 'Barlow',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Positioned(
                    left: ui(10),
                    bottom: ui(8),
                    child: Text(
                      isCreate ? '点击创建新的资料目录' : item.sizeLabel,
                      style: TextStyle(
                        fontSize: ui(11),
                        color: const Color(0xFF7F70A8),
                        fontFamily: 'Barlow',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: ui(10)),
          Center(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ui(15),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.item,
    required this.onAction,
  });

  final CloudFileItem item;
  final ValueChanged<_CloudFileAction> onAction;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final visual = _resolveFileVisual(item);
    return Container(
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
                // 中央：88×88 文件类型图标
                Center(
                  child: Image.asset(
                    visual.iconAsset,
                    width: ui(88),
                    height: ui(88),
                    fit: BoxFit.contain,
                  ),
                ),
                // 左上角：选择小方框
                Positioned(
                  left: ui(10),
                  top: ui(13),
                  child: Container(
                    width: ui(12),
                    height: ui(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(1)),
                      border: Border.all(
                        color: const Color(0xFFD9D9D9),
                        width: ui(1),
                      ),
                    ),
                  ),
                ),
                // 右上角：类型徽标 + 操作菜单
                Positioned(
                  top: ui(8),
                  right: ui(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ui(6),
                          vertical: ui(3),
                        ),
                        decoration: BoxDecoration(
                          color: visual.badgeBg,
                          borderRadius: BorderRadius.circular(ui(4)),
                        ),
                        child: Text(
                          visual.badgeLabel,
                          style: TextStyle(
                            fontSize: ui(10),
                            color: visual.badgeColor,
                            fontFamily: 'PingFang SC',
                            fontWeight: FontWeight.w500,
                            height: 11.43 / 9.52,
                          ),
                        ),
                      ),
                      PopupMenuButton<_CloudFileAction>(
                        padding: EdgeInsets.zero,
                        iconSize: ui(20),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ui(12)),
                        ),
                        onSelected: onAction,
                        itemBuilder: (context) {
                          final actions = <_CloudFileAction>[
                            _CloudFileAction.preview,
                            if (item.type == CloudFileType.audio)
                              _CloudFileAction.play,
                            _CloudFileAction.share,
                            _CloudFileAction.delete,
                          ];
                          return actions
                              .map(
                                (action) => PopupMenuItem<_CloudFileAction>(
                                  value: action,
                                  child: Text(action.label(item.isPlaying)),
                                ),
                              )
                              .toList();
                        },
                        child: SizedBox(
                          width: ui(20),
                          height: ui(20),
                          child: Image.asset(
                            AppAssets.cloudActionMore,
                            width: ui(20),
                            height: ui(20),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 音频类型：右上角浮动播放按钮
                if (item.type == CloudFileType.audio)
                  Positioned(
                    bottom: ui(10),
                    right: ui(10),
                    child: GestureDetector(
                      onTap: () => onAction(_CloudFileAction.play),
                      child: Container(
                        width: ui(28),
                        height: ui(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0x14000000),
                              blurRadius: ui(8),
                              offset: Offset(0, ui(2)),
                            ),
                          ],
                        ),
                        child: Icon(
                          item.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: ui(18),
                          color: const Color(0xFF18C9A5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 底部 58px 信息条 (#F5F6FA)
          Container(
            height: ui(58),
            color: const Color(0xFFF5F6FA),
            padding: EdgeInsets.fromLTRB(ui(12), ui(8), ui(12), ui(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
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
                SizedBox(height: ui(8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.sizeLabel,
                      style: TextStyle(
                        fontSize: ui(10),
                        color: const Color(0xFFB6B5BB),
                        fontFamily: 'Barlow',
                        fontWeight: FontWeight.w500,
                        height: 12 / 10,
                      ),
                    ),
                    Text(
                      item.dateLabel,
                      style: TextStyle(
                        fontSize: ui(10),
                        color: const Color(0xFFB6B5BB),
                        fontFamily: 'Barlow',
                        fontWeight: FontWeight.w500,
                        height: 12 / 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingCreateButton extends StatelessWidget {
  const _FloatingCreateButton({
    required this.label,
    required this.iconAsset,
    required this.onTap,
  });

  final String label;
  final String iconAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(40),
        padding: EdgeInsets.symmetric(horizontal: ui(13), vertical: ui(8)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
          boxShadow: [
            BoxShadow(
              color: const Color(0x59B5B5B5),
              blurRadius: ui(20),
              offset: Offset(0, ui(16)),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              iconAsset,
              width: ui(20),
              height: ui(20),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(8)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(16),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 12 / 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionBox extends StatelessWidget {
  const _SelectionBox({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(18),
      height: ui(18),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF8741FF) : Colors.white,
        borderRadius: BorderRadius.circular(ui(5)),
        border: Border.all(
          color: selected ? const Color(0xFF8741FF) : const Color(0xFFD7DBE5),
          width: ui(1.2),
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: ui(12), color: Colors.white)
          : null,
    );
  }
}

class _FolderArtwork extends StatelessWidget {
  const _FolderArtwork({required this.item});

  final CloudFolderItem item;

  @override
  Widget build(BuildContext context) {
    final asset = item.isCreateShortcut || item.title.contains('新建文件夹')
        ? AppAssets.cloudFolderEmptyBg
        : AppAssets.cloudFolderFilledBg;
    return Image.asset(asset, fit: BoxFit.fill);
  }
}

class _FileArtwork extends StatelessWidget {
  const _FileArtwork({required this.item, this.compact = true});

  final CloudFileItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final style = _fileStyle(item.type);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[style.backgroundStart, style.backgroundEnd],
        ),
        borderRadius: BorderRadius.circular(ui(compact ? 16 : 22)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -ui(10),
            bottom: -ui(8),
            child: Container(
              width: ui(compact ? 60 : 78),
              height: ui(compact ? 60 : 78),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ),
          ),
          Center(
            child: Container(
              width: ui(compact ? 58 : 74),
              height: ui(compact ? 58 : 74),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(ui(compact ? 20 : 24)),
                boxShadow: [
                  BoxShadow(
                    color: style.accent.withValues(alpha: 0.18),
                    blurRadius: ui(20),
                    offset: Offset(0, ui(10)),
                  ),
                ],
              ),
              child: Icon(
                style.icon,
                size: ui(compact ? 28 : 34),
                color: style.accent,
              ),
            ),
          ),
          if (item.type == CloudFileType.audio)
            Positioned(
              right: ui(10),
              top: ui(10),
              child: Container(
                width: ui(compact ? 28 : 32),
                height: ui(compact ? 28 : 32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(ui(999)),
                ),
                child: Icon(
                  item.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: ui(compact ? 16 : 18),
                  color: style.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyCloudState extends StatelessWidget {
  const _EmptyCloudState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(72),
            height: ui(72),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(ui(24)),
            ),
            child: Icon(
              Icons.cloud_queue_rounded,
              size: ui(34),
              color: const Color(0xFFB6B5BB),
            ),
          ),
          SizedBox(height: ui(14)),
          Text(
            message,
            style: TextStyle(
              fontSize: ui(14),
              color: const Color(0xFF788698),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadKindOption extends StatelessWidget {
  const _UploadKindOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(18),
            height: ui(18),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? const Color(0xFFA773FF)
                    : const Color(0xFFCECED1),
                width: ui(1),
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: ui(9),
                      height: ui(9),
                      decoration: const BoxDecoration(
                        color: Color(0xFFA773FF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          SizedBox(width: ui(5)),
          Text(
            label,
            style: TextStyle(
              fontSize: ui(14),
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
              height: 12 / 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({
    required this.label,
    required this.foregroundColor,
    required this.onTap,
    this.backgroundColor,
    this.gradient,
  });

  final String label;
  final Color foregroundColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(14)),
      child: Ink(
        height: ui(44),
        decoration: BoxDecoration(
          color: gradient == null ? backgroundColor ?? Colors.white : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(ui(14)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(14),
              color: foregroundColor,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.only(bottom: ui(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ui(62),
            child: Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: const Color(0xFFB6B5BB),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: ui(12),
                color: const Color(0xFF1A1A1A),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _CloudMenuAction { rename, share, copy, delete }

/// 显示左侧分类卡的省略号操作菜单。
///
/// [triggerKey] 必须挂在触发该菜单的 Widget（通常是省略号图标）上，
/// 用于计算菜单的锚点位置（出现在按钮下方、右边缘对齐）。
///
/// 返回 `null` 表示用户点击了空白区域关闭菜单，未选择任何操作。
Future<_CloudMenuAction?> _showCloudActionMenu({
  required BuildContext context,
  required GlobalKey triggerKey,
}) {
  // 解析触发器在屏幕上的几何位置
  final triggerCtx = triggerKey.currentContext;
  if (triggerCtx == null) {
    return Future<_CloudMenuAction?>.value(null);
  }
  final renderBox = triggerCtx.findRenderObject() as RenderBox;
  final overlayBox = Overlay.of(
    context,
    rootOverlay: true,
  ).context.findRenderObject() as RenderBox;

  final origin = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final size = renderBox.size;
  final scale = DashboardScaleScope.of(context);
  final menuWidth = scale.ui(142);
  // 大约预估菜单总高度（8 + 36*3 + 2 + 1 + 3 + 36 + 8 = 166），仅用于
  // 在底部空间不够时把菜单上挪，渲染时仍按内容自适应。
  final approxMenuHeight = scale.ui(166);

  // 让"点击点"(省略号图标的中心) ≈ 弹窗的左上角。
  // 即菜单从触发按钮中心位置向右下方展开。
  var left = origin.dx + size.width / 2;
  var top = origin.dy + size.height / 2;

  // 右侧空间不够：把菜单整体平移到按钮左侧（保持垂直锚点不变）
  if (left + menuWidth > overlayBox.size.width - scale.ui(8)) {
    left = origin.dx + size.width / 2 - menuWidth;
  }
  // 极端情况下两侧都摆不下，兜底：贴左 8px
  if (left < scale.ui(8)) {
    left = scale.ui(8);
  }
  // 底部空间不够：把菜单上挪
  if (top + approxMenuHeight > overlayBox.size.height - scale.ui(8)) {
    top = overlayBox.size.height - approxMenuHeight - scale.ui(8);
  }
  if (top < scale.ui(8)) {
    top = scale.ui(8);
  }

  return showMenu<_CloudMenuAction>(
    context: context,
    elevation: 0,
    color: Colors.transparent,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    constraints: BoxConstraints.tightFor(width: menuWidth),
    position: RelativeRect.fromLTRB(
      left,
      top,
      overlayBox.size.width - left - menuWidth,
      overlayBox.size.height - top,
    ),
    items: <PopupMenuEntry<_CloudMenuAction>>[
      PopupMenuItem<_CloudMenuAction>(
        enabled: false,
        padding: EdgeInsets.zero,
        child: DashboardScaleScope(
          data: scale,
          child: Builder(
            builder: (panelCtx) => _CloudActionMenuPanel(
              onSelected: (action) => Navigator.of(panelCtx).pop(action),
            ),
          ),
        ),
      ),
    ],
  );
}

/// 142px 宽的操作菜单面板：白底 / 12 圆角 / 1.11px 浅边框 / 三段式柔和投影。
class _CloudActionMenuPanel extends StatelessWidget {
  const _CloudActionMenuPanel({required this.onSelected});

  final ValueChanged<_CloudMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(142),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1.11)),
        boxShadow: [
          // 0px 0px 1px rgba(11,8,26,0.02)
          BoxShadow(
            color: const Color(0x050B081A),
            blurRadius: ui(1),
          ),
          // 0px 12px 40px rgba(11,8,26,0.06)
          BoxShadow(
            color: const Color(0x0F0B081A),
            blurRadius: ui(40),
            offset: Offset(0, ui(12)),
          ),
          // 0px 12px 24px -16px rgba(11,8,26,0.02)
          BoxShadow(
            color: const Color(0x050B081A),
            blurRadius: ui(24),
            offset: Offset(0, ui(12)),
            spreadRadius: ui(-16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: ui(8)),
          _CloudActionMenuRow(
            label: '重命名',
            icon: AppAssets.coursewareActionRename,
            onTap: () => onSelected(_CloudMenuAction.rename),
          ),
          _CloudActionMenuRow(
            label: '分享',
            icon: AppAssets.coursewareActionShare,
            onTap: () => onSelected(_CloudMenuAction.share),
          ),
          _CloudActionMenuRow(
            label: '复制',
            icon: AppAssets.coursewareActionCopy,
            onTap: () => onSelected(_CloudMenuAction.copy),
          ),
          SizedBox(height: ui(2)),
          Container(
            margin: EdgeInsets.symmetric(horizontal: ui(8)),
            height: ui(1),
            color: const Color(0xFFF3F4F6),
          ),
          SizedBox(height: ui(3)),
          _CloudActionMenuRow(
            label: '删除',
            icon: AppAssets.coursewareActionDelete,
            danger: true,
            onTap: () => onSelected(_CloudMenuAction.delete),
          ),
          SizedBox(height: ui(8)),
        ],
      ),
    );
  }
}

class _CloudActionMenuRow extends StatelessWidget {
  const _CloudActionMenuRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final String icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: ui(36),
        child: Row(
          children: [
            SizedBox(width: ui(14)),
            Image.asset(
              icon,
              width: ui(20),
              height: ui(20),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(10)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(13),
                color: danger
                    ? const Color(0xFFFF323C)
                    : const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w400,
                height: 20 / 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CloudFileAction { preview, play, share, delete }

extension _CloudFileActionLabel on _CloudFileAction {
  String label(bool isPlaying) {
    return switch (this) {
      _CloudFileAction.preview => '预览',
      _CloudFileAction.play => isPlaying ? '暂停播放' : '播放音频',
      _CloudFileAction.share => '分享',
      _CloudFileAction.delete => '删除',
    };
  }
}

class _CloudFileVisualStyle {
  const _CloudFileVisualStyle({
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.badgeBackground,
    required this.accent,
    required this.icon,
  });

  final Color backgroundStart;
  final Color backgroundEnd;
  final Color badgeBackground;
  final Color accent;
  final IconData icon;
}

_CloudFileVisualStyle _fileStyle(CloudFileType type) {
  return switch (type) {
    CloudFileType.audio => const _CloudFileVisualStyle(
      backgroundStart: Color(0xFFE9FBF5),
      backgroundEnd: Color(0xFFD8FFF2),
      badgeBackground: Color(0xFFE7FFF5),
      accent: Color(0xFF18C9A5),
      icon: Icons.headphones_rounded,
    ),
    CloudFileType.score => const _CloudFileVisualStyle(
      backgroundStart: Color(0xFFF0EBFF),
      backgroundEnd: Color(0xFFE3DAFF),
      badgeBackground: Color(0xFFF1EBFF),
      accent: Color(0xFF8B66F8),
      icon: Icons.music_note_rounded,
    ),
    CloudFileType.courseware => const _CloudFileVisualStyle(
      backgroundStart: Color(0xFFFFF4E6),
      backgroundEnd: Color(0xFFFFECD2),
      badgeBackground: Color(0xFFFFF4E8),
      accent: Color(0xFFFFAA21),
      icon: Icons.insert_drive_file_rounded,
    ),
  };
}

/// 文件卡片的视觉数据：图标资源 + 类型徽标背景/文字色 + 徽标文案。
/// 由文件后缀名 + [CloudFileType] 共同决定。
class _FileVisual {
  const _FileVisual({
    required this.iconAsset,
    required this.badgeLabel,
    required this.badgeBg,
    required this.badgeColor,
  });

  final String iconAsset;
  final String badgeLabel;
  final Color badgeBg;
  final Color badgeColor;
}

const _FileVisual _kBadgeKj = _FileVisual(
  iconAsset: AppAssets.coursewareFileTypeKj,
  badgeLabel: '课件',
  badgeBg: Color(0xFFDFFCF0),
  badgeColor: Color(0xFF0CAC40),
);
const _FileVisual _kBadgeAudio = _FileVisual(
  iconAsset: AppAssets.coursewareFileTypeKj,
  badgeLabel: '音频',
  badgeBg: Color(0xFFDFFCF0),
  badgeColor: Color(0xFF0CAC40),
);
const _FileVisual _kBadgeImage = _FileVisual(
  iconAsset: AppAssets.coursewareFileTypeImage,
  badgeLabel: '图片',
  badgeBg: Color(0x0D8741FF),
  badgeColor: Color(0xFF8741FF),
);
const _FileVisual _kBadgePdf = _FileVisual(
  iconAsset: AppAssets.coursewareFileTypePdf,
  badgeLabel: '文件',
  badgeBg: Color(0xFFFEE4E8),
  badgeColor: Color(0xFFFF386B),
);
const _FileVisual _kBadgeDoc = _FileVisual(
  iconAsset: AppAssets.coursewareFileTypeDoc,
  badgeLabel: '文档',
  badgeBg: Color(0xFFE6F2FF),
  badgeColor: Color(0xFF1E73FF),
);

bool _hasExt(String url, List<String> exts) {
  final lower = url.toLowerCase();
  for (final ext in exts) {
    if (lower.endsWith('.$ext')) return true;
  }
  return false;
}

_FileVisual _resolveFileVisual(CloudFileItem item) {
  // 选取最具代表性的 url 用于嗅探后缀。
  String url = item.audioUrl;
  if (url.isEmpty && item.imageUrls.isNotEmpty) {
    url = item.imageUrls.first;
  }

  if (_hasExt(url, ['pdf'])) return _kBadgePdf;
  if (_hasExt(url, ['doc', 'docx', 'txt', 'rtf'])) return _kBadgeDoc;
  if (_hasExt(url, ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg'])) {
    return _kBadgeImage;
  }
  if (_hasExt(url, ['mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg'])) {
    return _kBadgeAudio;
  }
  // 没有从 url 推断出类型时回退到 CloudFileType。
  return switch (item.type) {
    CloudFileType.audio => item.imageUrls.isNotEmpty ? _kBadgeImage : _kBadgeAudio,
    CloudFileType.score => item.imageUrls.isNotEmpty ? _kBadgeImage : _kBadgeKj,
    CloudFileType.courseware => _kBadgeKj,
  };
}

