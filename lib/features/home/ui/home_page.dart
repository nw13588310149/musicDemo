import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../state/home_dashboard_controller.dart';
import '../state/home_dashboard_state.dart';
import '../../shell/ui/shell_layout.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeDashboardControllerProvider);
    final controller = ref.read(homeDashboardControllerProvider.notifier);

    return _HomePageView(
      state: state,
      onSetComingSoonVisible: controller.setComingSoonVisible,
    );
  }
}

class _HomePageView extends StatefulWidget {
  const _HomePageView({
    required this.state,
    required this.onSetComingSoonVisible,
  });

  final HomeDashboardState state;
  final ValueChanged<bool> onSetComingSoonVisible;

  @override
  State<_HomePageView> createState() => _HomePageViewState();
}

class _HomePageViewState extends State<_HomePageView> {
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  int _bannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _restartBannerAutoPlay();
  }

  @override
  void didUpdateWidget(covariant _HomePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _restartBannerAutoPlay();

    final total = _effectiveBannerImages(widget.state.bannerItems).length;
    if (total == 0) {
      _bannerIndex = 0;
      return;
    }
    if (_bannerIndex < total) {
      return;
    }
    _bannerIndex = total - 1;
    if (_bannerController.hasClients) {
      _bannerController.jumpToPage(_bannerIndex);
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return LayoutBuilder(
      builder: (context, constraints) {
        // ── 精确计算左右面板尺寸，使右侧底部与器乐卡底部齐平 ──────────
        const rightW = 307.0;
        const mainGap = 16.0;
        const actionH = 313.0;
        final leftW = constraints.maxWidth - rightW - mainGap;
        final bannerH = leftW * 190.0 / 647.0;
        final rightH = bannerH + mainGap + actionH;

        return Stack(
          children: [
            SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 主内容行：左侧内容 + 右侧课表通知 ─────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 左侧：Banner + 功能矩阵+声乐器乐
                        SizedBox(
                          width: leftW,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Banner：精确高度 = leftW * 190/647
                              SizedBox(
                                height: bannerH,
                                child: _buildBanner(state.bannerItems),
                              ),
                              const SizedBox(height: mainGap),
                              // 功能矩阵 + 声乐/器乐 横排，固定高度 313
                              SizedBox(
                                height: actionH,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _buildActionBoard(
                                        state.quickActions,
                                      ),
                                    ),
                                    const SizedBox(width: mainGap),
                                    const _VoiceInstrumentColumn(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: mainGap),
                        // 右侧：高度精确匹配左侧，使底部与器乐卡底部齐平
                        SizedBox(
                          width: rightW,
                          height: rightH,
                          child: _buildRightPanel(state),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildLatestHeader(),
                    const SizedBox(height: 10),
                    _buildNewsRow(state.newsItems),
                  ],
                ),
              ),
            ),
            if (state.loading)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.35),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            if (state.showComingSoon)
              _ComingSoonDialog(
                onClose: () => widget.onSetComingSoonVisible(false),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBanner(List<HomeBannerItem> bannerItems) {
    final images = _effectiveBannerImages(bannerItems);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: images.isEmpty
                ? _buildBannerFallbackBackground()
                : PageView.builder(
                    controller: _bannerController,
                    itemCount: images.length,
                    onPageChanged: (index) {
                      if (!mounted) return;
                      setState(() => _bannerIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final image = images[index];
                      if (!image.startsWith('http')) {
                        return Image.asset(
                          image,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        );
                      }
                      return Image.network(
                        image,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildBannerFallbackBackground(),
                      );
                    },
                  ),
          ),
          // 分页指示器
          Positioned(
            right: 36,
            bottom: 20,
            child: Row(
              children: List.generate(images.isEmpty ? 3 : images.length, (
                index,
              ) {
                final active = images.isEmpty
                    ? index == 0
                    : index == _bannerIndex;
                return Padding(
                  padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
                  child: _BannerIndicator(
                    width: active ? 21 : 4,
                    opacity: active ? 1 : 0.85,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _effectiveBannerImages(List<HomeBannerItem> banners) {
    return banners
        .map((item) => _normalizeImage(item.imageUrl))
        .where((url) => url.isNotEmpty)
        .toList();
  }

  String _normalizeImage(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return '';
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final sanitized = value.startsWith('/') ? value.substring(1) : value;
    return '${AppConstants.apiBaseUrl}$sanitized';
  }

  void _restartBannerAutoPlay() {
    _bannerTimer?.cancel();
    final total = _effectiveBannerImages(widget.state.bannerItems).length;
    if (total <= 1) {
      return;
    }
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_bannerController.hasClients) {
        return;
      }
      final next = (_bannerIndex + 1) % total;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _buildBannerFallbackBackground() {
    return Stack(
      children: [
        Container(color: const Color(0xFF2D1C77)),
        Positioned(
          left: -37,
          top: -119,
          child: AppAssetGraphic(
            AppAssets.homeV2BannerGlow,
            width: 263,
            height: 318,
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          right: 48.65,
          top: -30.94,
          child: AppAssetGraphic(
            AppAssets.homeV2BannerGuitar,
            width: 373.35,
            height: 250.87,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBoard(List<HomeQuickAction> quickActions) {
    final actions = _resolveQuickActions(quickActions);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: Colors.white,
        child: RepaintBoundary(
          child: GridView.builder(
            // SizedBox(height:313) 提供了有界高度，不需要 shrinkWrap
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisExtent: 70,
              mainAxisSpacing: 18,
              crossAxisSpacing: 0,
            ),
            itemBuilder: (context, index) {
              final action = actions[index];
              return _QuickActionItem(
                action: action,
                onTap: () => _onQuickActionTap(action),
              );
            },
          ),
        ),
      ),
    );
  }

  List<HomeQuickAction> _resolveQuickActions(List<HomeQuickAction> input) {
    if (input.isNotEmpty) return input.take(9).toList();
    return buildQuickActions(true);
  }

  Widget _buildRightPanel(HomeDashboardState state) {
    final notices = state.courseNotices.isEmpty
        ? buildDefaultCourseNotices()
        : state.courseNotices;
    // 始终展示完整 7 天
    final weekItems = state.weekItems;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '课表',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w500,
              fontFamily: 'PingFang SC',
            ),
          ),
          const SizedBox(height: 6),
          // 周一~周日，横向可滑动，无滚动条
          SizedBox(
            height: 88,
            child: ScrollConfiguration(
              behavior: const _NoScrollbarBehavior(),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(weekItems.length, (index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == weekItems.length - 1 ? 0 : 8,
                      ),
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(
                          context,
                          RoutePaths.smartCampus,
                        ),
                        child: _WeekCard(item: weekItems[index]),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '通知',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w500,
              fontFamily: 'PingFang SC',
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              physics: const ClampingScrollPhysics(),
              itemCount: notices.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, RoutePaths.smartCampus),
                  child: _CourseNoticeCard(notice: notices[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestHeader() {
    return ShellSectionTitleBar(
      title: '最新',
      onMoreTap: () => Navigator.pushNamed(context, RoutePaths.consultation),
    );
  }

  Widget _buildNewsRow(List<HomeNewsItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final news = items;

    // GridView shrinkWrap：4 列等分，多行可滚动（由外层 SingleChildScrollView 承载）
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 138,
      ),
      itemCount: news.length,
      itemBuilder: (context, index) {
        final item = news[index];
        return GestureDetector(
          onTap: () => Navigator.pushNamed(
            context,
            RoutePaths.consultationDetail,
            arguments: <String, dynamic>{'id': item.id},
          ),
          child: _NewsCard(item: item),
        );
      },
    );
  }

  void _onQuickActionTap(HomeQuickAction action) {
    Navigator.pushNamed(
      context,
      action.route,
      arguments: action.firstMenu == null
          ? null
          : <String, dynamic>{'firstMenu': action.firstMenu.toString()},
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({required this.action, required this.onTap});

  final HomeQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              action.icon,
              width: 44,
              height: 44,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 6),
            Text(
              action.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w500,
                fontFamily: 'PingFang SC',
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceInstrumentColumn extends StatelessWidget {
  const _VoiceInstrumentColumn();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 146,
      child: Column(
        children: [
          _VoiceCard(
            asset: AppAssets.homeShengyue,
            onTap: () => Navigator.pushNamed(context, RoutePaths.voice),
          ),
          const SizedBox(height: 19),
          _VoiceCard(
            asset: AppAssets.homeQiyue,
            onTap: () => Navigator.pushNamed(context, RoutePaths.instrumental),
          ),
        ],
      ),
    );
  }
}

/// 声乐/器乐卡片：直接使用完整背景图，146×147，圆角 16
class _VoiceCard extends StatelessWidget {
  const _VoiceCard({required this.asset, required this.onTap});

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          asset,
          width: 146,
          height: 147,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _BannerIndicator extends StatelessWidget {
  const _BannerIndicator({required this.width, this.opacity = 1});

  final double width;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

/// 隐藏滚动条的 ScrollBehavior
class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.item});

  final HomeWeekDayItem item;

  @override
  Widget build(BuildContext context) {
    final active = item.isToday;

    return Container(
      width: 64,
      height: 88,
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF8640FF), Color(0xFFB68EFF)],
              )
            : null,
        color: active ? null : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 6,
            child: Text(
              item.weekText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: active
                    ? const Color(0xFFBBB5F3)
                    : const Color(0xFFA9A9A9),
                fontFamily: 'PingFang SC',
                height: 1.43,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 27,
            child: Text(
              item.dayText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                color: active ? Colors.white : const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w500,
                height: 1.35,
                fontFamily: 'Manrope',
              ),
            ),
          ),
          Positioned(
            left: 6,
            top: 61,
            child: Container(
              width: 52,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? Colors.white : const Color(0xFFF1F2F7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${item.courseCount}节',
                style: TextStyle(
                  fontSize: 14,
                  color: active
                      ? const Color(0xFF8741FF)
                      : const Color(0xFFA9A9A9),
                  fontFamily: 'PingFang SC',
                  height: 1.43,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseNoticeCard extends StatelessWidget {
  const _CourseNoticeCard({required this.notice});

  final HomeCourseNotice notice;

  @override
  Widget build(BuildContext context) {
    final statusColor = notice.status == HomeCourseStatus.ended
        ? const Color(0xFFE6E9F1)
        : const Color(0xFFEAE5FF);
    final statusTextColor = notice.status == HomeCourseStatus.ended
        ? const Color(0xFFB6B5BB)
        : const Color(0xFF0B081A);
    final timeTextColor = notice.status == HomeCourseStatus.upcoming
        ? const Color(0xFF0B081A)
        : const Color(0xFF1A1A1A);
    final courseStyle = _courseStyle(notice.subjectName);

    return Container(
      width: double.infinity,
      height: 104,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 16,
            top: 16,
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 16,
                  color: timeTextColor,
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(text: '${notice.startTime} '),
                  const TextSpan(
                    text: '- ',
                    style: TextStyle(color: Color(0xFFB6B5BB)),
                  ),
                  TextSpan(text: notice.endTime),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 68,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Text(
                notice.statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: statusTextColor,
                  fontFamily: 'PingFang SC',
                  height: 1,
                ),
              ),
            ),
          ),
          // 科目标签
          Positioned(
            left: 116,
            top: 17,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: courseStyle.background,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                notice.subjectName,
                style: TextStyle(
                  fontSize: 12,
                  color: courseStyle.foreground,
                  fontFamily: 'PingFang SC',
                  height: 1,
                ),
              ),
            ),
          ),
          // 教师头像
          Positioned(
            left: 16,
            top: 50,
            child: _NoticeAvatar(primaryUrl: notice.teacherAvatar, size: 36),
          ),
          // 教师姓名 + 课时描述
          Positioned(
            left: 60,
            top: 51,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.teacherName,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    color: Color(0xFF0B081A),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'PingFang SC',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  notice.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB6B5BB),
                    fontFamily: 'PingFang SC',
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({Color background, Color foreground}) _courseStyle(String name) {
    if (name.contains('听')) {
      return (
        background: const Color(0xFFDFFCF0),
        foreground: const Color(0xFF0CAC40),
      );
    }
    if (name.contains('乐理')) {
      return (
        background: const Color(0xFFFEE4E8),
        foreground: const Color(0xFFFF386B),
      );
    }
    return (
      background: const Color(0xFFF1EEFF),
      foreground: const Color(0xFF8741FF),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});

  final HomeNewsItem item;

  @override
  Widget build(BuildContext context) {
    final tags = item.tags.take(3).toList();

    return RepaintBoundary(
      child: Container(
        height: 138,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            const Positioned(left: 16, top: 17.5, child: _NewsBadge()),
            Positioned(
              left: 55,
              top: 15,
              right: 14,
              child: Text(
                item.shortTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF0B081A),
                  fontWeight: FontWeight.w500,
                  fontFamily: 'PingFang SC',
                  height: 1.375,
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 44.5,
              right: 16,
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF788698),
                  fontFamily: 'PingFang SC',
                  height: 1.43,
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 72.5,
              right: 16,
              height: 18,
              child: Row(
                children: [
                  for (int i = 0; i < tags.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tags[i],
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF788698),
                          height: 1.2,
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 16,
              top: 102.5,
              child: Text(
                _formatTime(item.createTime),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF788698),
                  fontFamily: 'PingFang SC',
                  height: 1.36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '刚刚';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    final days = diff.inDays;
    if (days < 30) return '$days天前';
    if (days < 365) return '${(days / 30).floor()}月前';
    return '${(days / 365).floor()}年前';
  }
}

class _NewsBadge extends StatelessWidget {
  const _NewsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFA773FF),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white,
          height: 1,
          fontWeight: FontWeight.w500,
          fontFamily: 'Gilroy',
        ),
      ),
    );
  }
}

class _NoticeAvatar extends StatelessWidget {
  const _NoticeAvatar({required this.primaryUrl, required this.size});

  final String primaryUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: primaryUrl.isNotEmpty
            ? Image.network(
                primaryUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFEAE5FF),
    alignment: Alignment.center,
    child: const Icon(Icons.person, color: Color(0xFF8741FF), size: 20),
  );
}

class _ComingSoonDialog extends StatelessWidget {
  const _ComingSoonDialog({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                AppAssets.homeComingSoon,
                width: 520,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 15),
            GestureDetector(
              onTap: onClose,
              child: Image.asset(
                AppAssets.homeDialogClose,
                width: 40,
                height: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
