import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/dictation_controller.dart';
import '../state/dictation_state.dart';

class DictationPage extends ConsumerWidget {
  const DictationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = _parseArgs(ModalRoute.of(context)?.settings.arguments);
    final state = ref.watch(dictationControllerProvider(args));
    final controller = ref.read(dictationControllerProvider(args).notifier);
    final ui = DashboardScaleScope.of(context).ui;

    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(16)),
      child: ColoredBox(
        color: Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: ui(180),
              child: _SidebarPanel(
                state: state,
                onSelectMenu: controller.selectMenu,
              ),
            ),
            Expanded(
              child: _ContentPanel(
                state: state,
                onSelectChild: controller.selectChild,
                onRefresh: controller.refreshLessons,
              ),
            ),
          ],
        ),
      ),
    );
  }

  DictationPageArgs _parseArgs(dynamic raw) {
    if (raw is DictationPageArgs) {
      return raw;
    }
    if (raw is Map) {
      return DictationPageArgs(
        // 与 1.0 `!history.state.school` 语义一致：任何 truthy 值（true / 非零 id /
        // 非空字符串）都视为 school 模式，让二级页走 schoolTextbookList 接口。
        schoolMode: _isTruthy(raw['schoolMode']) || _isTruthy(raw['school']),
        initialFirstMenuId: raw['firstMenu']?.toString(),
        initialSecondMenuId: raw['secondMenu']?.toString(),
      );
    }
    return const DictationPageArgs(initialFirstMenuId: '8');
  }
}

/// 仿 JS `!!value` 语义：null/false/0/空串视为假，其他视为真。
bool _isTruthy(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    if (value.isEmpty) return false;
    final lower = value.toLowerCase();
    return lower != '0' && lower != 'false';
  }
  return true;
}

class _SidebarPanel extends StatelessWidget {
  const _SidebarPanel({required this.state, required this.onSelectMenu});

  final DictationState state;
  final ValueChanged<String> onSelectMenu;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFF3F2F3), width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(ui(8), ui(20), ui(8), ui(8)),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        itemCount: state.menus.length,
        separatorBuilder: (_, index) => SizedBox(height: ui(8)),
        itemBuilder: (context, index) {
          final menu = state.menus[index];
          final active = menu.id == state.selectedMenuId;
          return _SidebarTile(
            title: menu.name,
            active: active,
            onTap: () => onSelectMenu(menu.id),
          );
        },
      ),
    );
  }
}

class _ContentPanel extends StatelessWidget {
  const _ContentPanel({
    required this.state,
    required this.onSelectChild,
    required this.onRefresh,
  });

  final DictationState state;
  final ValueChanged<String?> onSelectChild;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasChildren = state.selectedChildren.isNotEmpty;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasChildren)
            Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(20), ui(20), ui(4)),
              child: _ChildSegmented(
                items: state.selectedChildren,
                selectedId: state.selectedChildId,
                onSelect: onSelectChild,
              ),
            ),
          Expanded(
            child: state.loading && state.lessonGroups.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : state.lessonGroups.isEmpty
                ? _EmptyState(
                    message: state.errorMessage.isEmpty
                        ? '暂无课程'
                        : state.errorMessage,
                    onRefresh: onRefresh,
                  )
                : Padding(
                    padding: EdgeInsets.symmetric(vertical: ui(12)),
                    child: RefreshIndicator(
                      onRefresh: onRefresh,
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          ui(20),
                          hasChildren ? ui(4) : ui(12),
                          ui(20),
                          ui(16),
                        ),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: state.lessonGroups.length,
                        separatorBuilder: (_, index) =>
                            SizedBox(height: ui(16)),
                        itemBuilder: (context, index) {
                          final group = state.lessonGroups[index];
                          return _LessonSection(
                            title: group.title,
                            lessons: group.lessons,
                            onOpenLesson: (lesson) {
                              final blockMessage = _blockingMessage(
                                state,
                                lesson,
                              );
                              if (blockMessage != null) {
                                AppToast.show(context, blockMessage);
                                return;
                              }
                              Navigator.pushNamed(
                                context,
                                RoutePaths.musicPlay,
                                arguments: <String, dynamic>{'id': lesson.id},
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String? _blockingMessage(DictationState state, DictationLesson lesson) {
    if (!lesson.vip) {
      return null;
    }
    final expire = state.vipExpireDate;
    if (expire == null) {
      return '您还未开通会员';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final vipDay = DateTime(expire.year, expire.month, expire.day);
    if (vipDay.isBefore(today)) {
      return '您的会员已过期，请续费';
    }
    return null;
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.title,
    required this.active,
    required this.onTap,
  });

  final String title;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final radius = active ? ui(8) : ui(16);

    return Material(
      color: active ? const Color(0xFFF4F4FF) : Colors.white,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          height: ui(60),
          padding: EdgeInsets.symmetric(horizontal: ui(14)),
          child: Row(
            children: [
              SizedBox(
                width: ui(36),
                height: ui(36),
                child: Image.asset(
                  AppAssets.homeDictationNavIcon,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: ui(10)),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: ui(13),
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF0B081A),
                    fontFamily: 'PingFang SC',
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildSegmented extends StatelessWidget {
  const _ChildSegmented({
    required this.items,
    required this.selectedId,
    required this.onSelect,
  });

  final List<DictationMenuChild> items;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Container(
          padding: EdgeInsets.all(ui(4)),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) SizedBox(width: ui(8)),
                _ChildSegmentedItem(
                  label: items[i].name,
                  active: items[i].id == selectedId,
                  onTap: () => onSelect(items[i].id),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildSegmentedItem extends StatelessWidget {
  const _ChildSegmentedItem({
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(8)),
        decoration: active
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(6)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x59B5B5B5),
                    blurRadius: 20,
                    offset: Offset(0, 0),
                  ),
                ],
              )
            : BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
        alignment: Alignment.center,
        child: Opacity(
          opacity: active ? 1.0 : 0.7,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
            style: TextStyle(
              fontSize: ui(14),
              color: active ? const Color(0xFF0B081A) : const Color(0xFF6D6B75),
              fontWeight: FontWeight.w500,
              fontFamily: 'PingFang SC',
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonSection extends StatelessWidget {
  const _LessonSection({
    required this.title,
    required this.lessons,
    required this.onOpenLesson,
  });

  final String title;
  final List<DictationLesson> lessons;
  final ValueChanged<DictationLesson> onOpenLesson;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(left: ui(2), bottom: ui(10)),
            child: Text(
              title,
              style: TextStyle(
                fontSize: ui(14),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF171A20),
                fontFamily: 'PingFang SC',
              ),
            ),
          ),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lessons.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: ui(260),
            mainAxisExtent: ui(100),
            crossAxisSpacing: ui(16),
            mainAxisSpacing: ui(16),
          ),
          itemBuilder: (context, index) {
            final lesson = lessons[index];
            return _LessonCard(
              lesson: lesson,
              onTap: () => onOpenLesson(lesson),
            );
          },
        ),
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson, required this.onTap});

  final DictationLesson lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Container(
      padding: EdgeInsets.all(ui(10)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LessonArtwork(title: lesson.title),
          SizedBox(width: ui(8)),
          Expanded(
            child: SizedBox(
              height: ui(80),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    right: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(13),
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF0B081A),
                            fontFamily: 'PingFang SC',
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: ui(6)),
                        Text(
                          lesson.subtitle.isEmpty
                              ? '标准音上下行二度'
                              : lesson.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(11),
                            color: const Color(0xFFB6B5BB),
                            fontFamily: 'PingFang SC',
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: onTap,
                      child: Container(
                        width: ui(65),
                        height: ui(28),
                        decoration: BoxDecoration(
                          color: const Color(0xFF292151),
                          borderRadius: BorderRadius.circular(ui(8)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '去学习',
                          style: TextStyle(
                            fontSize: ui(11),
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'PingFang SC',
                            height: 12 / 11,
                          ),
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

class _LessonArtwork extends StatelessWidget {
  const _LessonArtwork({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(8)),
      child: SizedBox(
        width: ui(60),
        height: ui(80),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                AppAssets.homeDictationBookCover,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: ui(10),
              child: Text(
                '听选\n${_artLabel(title)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui(12),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFB16AFF),
                  fontFamily: 'Alimama ShuHeiTi',
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _artLabel(String title) {
    if (title.contains('音组')) return '音组';
    if (title.contains('音程')) return '音程';
    if (title.contains('和弦')) return '和弦';
    if (title.contains('节奏')) return '节奏';
    if (title.contains('旋律')) return '旋律';
    return '单音';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.onRefresh});

  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: ui(48),
            color: const Color(0xFFC5C7D0),
          ),
          SizedBox(height: ui(12)),
          Text(
            message,
            style: TextStyle(
              fontSize: ui(14),
              color: const Color(0xFF8E90A0),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(12)),
          OutlinedButton(
            onPressed: () => onRefresh(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF292151),
              side: const BorderSide(color: Color(0xFFE0E3F0)),
            ),
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
  }
}
