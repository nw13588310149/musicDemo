// =============================================================================
// 班主任端「家校沟通」独立页面
//
// 入口：班主任 dashboard 快捷区「家校沟通」按钮 →
//      controller.openHomeSchoolCommunication() → mainView == homeSchool
//      + role == headTeacher → SmartCampusPage 路由到本视图。返回：
//      banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. banner（62 高, 紫白渐变 #F9EDFF→white, 圆角 16, 居中"家校沟通"
//      16/600 + 副标题 12/#B6B5BB「与本班学生家长就请假、成绩、心理等
//      进行文字沟通；可查看短信送达演示状态。消息以站内信为主，接入后
//      可同步微信/App推送。」）。
//   2. 提示文字 12/#B6B5BB「默认由家长在小程序审批后再由班主任审批；……」。
//   3. 3 张统计卡（100 高 + 196deg 渐变 + 右下 54×54 装饰渐变方块）：
//      A. 「未读消息」橙红渐变 #FFE2DC + 数字 32 Barlow
//      B. 「待回复」橙黄渐变 #FFF0DC + 同
//      C. 「会话总数」紫渐变 #E7DCFF + 同
//   4. Tabs row（44 高）：白底圆角 8 + 3 pills：全部 / 未读 / 待回复。
//      右侧搜索框 324×44「搜索姓名、学号、手机、宿舍、家长」。
//   5. 家长对话卡 3 列网格（315 宽 × 161 高，圆角 12）：
//      头像 40 + 学生姓名 14/500 + 学号 G3030201 12 #B6B5BB +
//      家长称谓 王丽（母亲）12 + 标签（心理关注 / 成绩 灰底 / 待回复
//      #DAD2FF/#8741FF）+ 灰底家长发言预览 + 时间戳 +「短信未送达」红字。
//      头像左上未读红徽章「10+」。
//   6. 点击卡片打开 _ChatDetailDialog：428×500 紫白渐变头 + 学生/家长
//      信息 + 老师/家长气泡 + 输入栏 + 退出链接。
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/home_school_chat_data.dart';
import '../data/teacher_repository.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kCardGreyBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextHintLight = Color(0xFFCECED1);
const Color _kTextPlaceholder = Color(0xFFD1D1D1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleSoftBg = Color(0xFFDAD2FF);
const Color _kBadgeRed = Color(0xFFF04545);

// —— 顶部 tab 枚举 ——————————————————————————————————————————————
enum _TopTab {
  all('全部', 'all'),
  unread('未读', 'unread'),
  pending('待回复', 'waitingReply');

  const _TopTab(this.label, this.apiTab);
  final String label;
  final String apiTab;
}

// —— 顶级视图 ——————————————————————————————————————————————————

class TeacherHomeSchoolView extends ConsumerStatefulWidget {
  const TeacherHomeSchoolView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<TeacherHomeSchoolView> createState() =>
      _TeacherHomeSchoolViewState();
}

class _TeacherHomeSchoolViewState extends ConsumerState<TeacherHomeSchoolView> {
  _TopTab _tab = _TopTab.all;
  String _query = '';
  String _debouncedKeyword = '';
  Timer? _searchDebounce;

  HomeSchoolChatStat _stat = HomeSchoolChatStat.zero;
  List<HomeSchoolConversation> _conversations = const [];
  bool _loading = false;
  String? _loadError;
  int _listToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_reloadAll());
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadStat() async {
    final resp = await ref.read(teacherRepositoryProvider).chatStat();
    if (!mounted) return;
    if (!resp.isSuccess) return;
    setState(() {
      _stat = parseHomeSchoolChatStat(resp.data);
    });
  }

  Future<void> _loadList() async {
    final token = ++_listToken;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final resp = await ref.read(teacherRepositoryProvider).chatConversationList(
          current: 1,
          size: 100,
          tab: _tab.apiTab,
          keyword: _debouncedKeyword,
        );
    if (!mounted || token != _listToken) return;

    if (!resp.isSuccess) {
      setState(() {
        _conversations = const [];
        _loading = false;
        _loadError = resp.displayMsg;
      });
      return;
    }

    setState(() {
      _conversations = parseHomeSchoolConversationList(resp.data);
      _loading = false;
      _loadError = null;
    });
  }

  Future<void> _reloadAll() async {
    await Future.wait([_loadStat(), _loadList()]);
  }

  void _onTabChanged(_TopTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    unawaited(_loadList());
  }

  void _onQueryChanged(String v) {
    setState(() => _query = v);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _debouncedKeyword = v.trim());
      unawaited(_loadList());
    });
  }

  void _openConversation(HomeSchoolConversation conv) {
    showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.80),
      builder: (dialogContext) => _ChatDetailDialog(
        conversation: conv,
        onSent: _reloadAll,
      ),
    ).then((_) {
      if (!mounted) return;
      unawaited(_reloadAll());
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      color: _kPageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: ui(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(onBack: widget.onBack),
            SizedBox(height: ui(16)),
            _StatsRow(
              unread: _stat.unreadCount,
              pending: _stat.waitingReplyCount,
              total: _stat.totalCount,
            ),
            SizedBox(height: ui(16)),
            _TabsAndSearchRow(
              current: _tab,
              query: _query,
              onTabChanged: _onTabChanged,
              onQueryChanged: _onQueryChanged,
            ),
            SizedBox(height: ui(16)),
            if (_loading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: ui(40)),
                child: Center(child: AppLoadingIndicator(size: ui(32))),
              )
            else if (_loadError != null)
              _ErrorHint(message: _loadError!, onRetry: _reloadAll)
            else if (_conversations.isEmpty)
              _EmptyHint(query: _query, tab: _tab)
            else
              _ConversationGrid(
                items: _conversations,
                onTap: _openConversation,
              ),
          ],
        ),
      ),
    );
  }
}

// —— Banner ————————————————————————————————————————————————————————

class _Banner extends StatelessWidget {
  const _Banner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        image: DecorationImage(
          image: AssetImage(AppAssets.xiaoquanHeaderBg),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(12),
            top: ui(15),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(ui(8)),
              child: Container(
                width: ui(32),
                height: ui(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: _kBorderSoft, width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: ui(20),
                  color: const Color(0xFF1C274C),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(56)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '家校沟通',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.2,
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

// —— 3 张统计卡 ————————————————————————————————————————————————

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.unread,
    required this.pending,
    required this.total,
  });

  final int unread;
  final int pending;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: '未读消息',
            value: unread,
            gradient: const [Color(0xFFFFE2DC), Colors.white],
            blobColor: const Color(0xFFFF9985),
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            title: '待回复',
            value: pending,
            gradient: const [Color(0xFFFFF0DC), Colors.white],
            blobColor: const Color(0xFFFFD79F),
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            title: '会话总数',
            value: total,
            gradient: const [Color(0xFFE7DCFF), Colors.white],
            blobColor: const Color(0xFFD4BEFF),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.gradient,
    required this.blobColor,
  });

  final String title;
  final int value;
  final List<Color> gradient;
  final Color blobColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(0.5, -0.95),
          end: const Alignment(-0.5, 0.95),
          stops: const [0.0, 0.73],
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(16),
            top: ui(16),
            right: ui(76),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
          ),
          Positioned(
            left: ui(16),
            top: ui(40),
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: ui(32),
                color: _kTextDark,
                fontFamily: 'Barlow',
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
            ),
          ),
          // 右下角装饰渐变方块（演示用纯色圆角）
          Positioned(
            right: ui(16),
            bottom: ui(8),
            child: Container(
              width: ui(54),
              height: ui(54),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    blobColor.withValues(alpha: 0.35),
                    blobColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(ui(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// —— Tabs + 搜索 ————————————————————————————————————————————————

class _TabsAndSearchRow extends StatelessWidget {
  const _TabsAndSearchRow({
    required this.current,
    required this.query,
    required this.onTabChanged,
    required this.onQueryChanged,
  });

  final _TopTab current;
  final String query;
  final ValueChanged<_TopTab> onTabChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(ui(4)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: _kBorderSoft, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in _TopTab.values) ...[
                _TabPill(
                  label: t.label,
                  active: current == t,
                  onTap: () => onTabChanged(t),
                ),
                if (t != _TopTab.values.last) SizedBox(width: ui(8)),
              ],
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: ui(324),
          child: _SearchBox(value: query, onChanged: onQueryChanged),
        ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
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
      borderRadius: BorderRadius.circular(ui(6)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(8)),
        decoration: BoxDecoration(
          color: active ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _SearchBox extends StatefulWidget {
  const _SearchBox({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _SearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(
        offset: widget.value.length,
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
    return Container(
      height: ui(44),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        children: [
          AppAssetGraphic(
            AppAssets.shellV2Search,
            width: ui(16),
            height: ui(16),
            fit: BoxFit.contain,
          ),
          SizedBox(width: ui(8)),
          Expanded(
            child: AppTextField(
              controller: _controller,
              onChanged: widget.onChanged,
              cursorColor: _kPurple,
              cursorWidth: 1.5,
              cursorHeight: ui(16),
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
              decoration: InputDecoration(
                hintText: '搜索姓名、学号、手机、家长',
                hintStyle: TextStyle(
                  fontSize: ui(14),
                  color: _kTextPlaceholder,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// —— 空状态 / 错误 ——————————————————————————————————————————————

class _ErrorHint extends StatelessWidget {
  const _ErrorHint({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(32), horizontal: ui(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
          SizedBox(height: ui(12)),
          InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(ui(6)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(6)),
              child: Text(
                '重试',
                style: TextStyle(
                  fontSize: ui(13),
                  color: _kPurple,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// —— 空状态 ————————————————————————————————————————————————————

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.query, required this.tab});

  final String query;
  final _TopTab tab;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(40)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Center(
        child: Text(
          query.isNotEmpty ? '未找到匹配的对话' : '当前 ${tab.label} 没有对话',
          style: TextStyle(
            fontSize: ui(13),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

// —— 卡片网格 ——————————————————————————————————————————————————

class _ConversationGrid extends StatelessWidget {
  const _ConversationGrid({required this.items, required this.onTap});

  final List<HomeSchoolConversation> items;
  final ValueChanged<HomeSchoolConversation> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, c) {
        const cols = 3;
        const gap = 12.0;
        final scaledGap = ui(gap);
        final w = c.maxWidth;
        final cardW = (w - scaledGap * (cols - 1)) / cols;
        return Wrap(
          spacing: scaledGap,
          runSpacing: scaledGap,
          children: [
            for (final conv in items)
              SizedBox(
                width: cardW,
                child: _ConversationCard(
                  conversation: conv,
                  onTap: () => onTap(conv),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.conversation, required this.onTap});

  final HomeSchoolConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(ui(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(ui(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部：头像 + 姓名/学号 + 标签
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AvatarWithBadge(
                    studentName: conversation.studentName,
                    unreadCount: conversation.unreadCount,
                  ),
                  SizedBox(width: ui(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                conversation.studentName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: ui(14),
                                  color: _kTextDark,
                                  fontFamily: 'PingFang SC',
                                  fontWeight: AppFont.w500,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            SizedBox(width: ui(8)),
                            Expanded(
                              child: _TagsRow(
                                tags: conversation.tags,
                                replyPending: conversation.replyPending,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ui(6)),
                        Text(
                          '${conversation.parentName}（${conversation.parentRelation}）',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextDark,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: ui(5)),
                        Text(
                          conversation.studentNo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextHint,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(10)),
              // 消息预览灰底块
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: ui(8),
                  vertical: ui(8),
                ),
                decoration: BoxDecoration(
                  color: _kCardGreyBg,
                  borderRadius: BorderRadius.circular(ui(8)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${conversation.lastSpeaker}：',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.4,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        conversation.lastMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextSecondary,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w400,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ui(8)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      conversation.timeText,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.2,
                      ),
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

class _AvatarWithBadge extends StatelessWidget {
  const _AvatarWithBadge({
    required this.studentName,
    required this.unreadCount,
  });

  final String studentName;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final initial = studentName.isNotEmpty ? studentName.characters.first : '?';
    return SizedBox(
      width: ui(46),
      height: ui(40),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: ui(40),
            height: ui(40),
            decoration: BoxDecoration(
              color: const Color(0xFFEFE5FF),
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                fontSize: ui(16),
                color: _kPurple,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
                height: 1.0,
              ),
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              left: ui(22),
              top: -ui(3),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: ui(4)),
                constraints: BoxConstraints(minWidth: ui(22)),
                height: ui(14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kBadgeRed,
                  borderRadius: BorderRadius.circular(ui(20)),
                ),
                child: Text(
                  unreadCount > 9 ? '10+' : '$unreadCount',
                  style: TextStyle(
                    fontSize: ui(10),
                    color: Colors.white,
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TagsRow extends StatelessWidget {
  const _TagsRow({required this.tags, required this.replyPending});

  final List<String> tags;
  final bool replyPending;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (final t in tags) ...[_TagPill.grey(t), SizedBox(width: ui(4))],
          if (replyPending) const _TagPill.purple('待回复'),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill.grey(this.label) : isPurple = false;
  const _TagPill.purple(this.label) : isPurple = true;

  final String label;
  final bool isPurple;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bg = isPurple ? _kPurpleSoftBg : _kCardGreyBg;
    final fg = isPurple ? _kPurple : _kTextSecondary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(12),
          color: fg,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

// =============================================================================
// 对话详情弹窗：428×500，紫白渐变头 + 学生 / 家长信息 + 老师/家长气泡 +
// 输入栏 + 退出。
// =============================================================================

class _ChatDetailDialog extends ConsumerStatefulWidget {
  const _ChatDetailDialog({
    required this.conversation,
    required this.onSent,
  });

  final HomeSchoolConversation conversation;
  final Future<void> Function() onSent;

  @override
  ConsumerState<_ChatDetailDialog> createState() => _ChatDetailDialogState();
}

class _ChatDetailDialogState extends ConsumerState<_ChatDetailDialog> {
  List<HomeSchoolChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  final _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadMessages());
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    final resp = await ref.read(teacherRepositoryProvider).chatMessageList(
          conversationId: widget.conversation.id,
          current: 1,
          size: 200,
        );
    if (!mounted) return;
    if (!resp.isSuccess) {
      setState(() => _loading = false);
      AppToast.show(context, resp.displayMsg);
      return;
    }
    final parsed = parseHomeSchoolChatMessageList(resp.data);
    setState(() {
      _messages = parsed.reversed.toList();
      _loading = false;
    });
  }

  Future<void> _onSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final resp = await ref.read(teacherRepositoryProvider).chatSend(
          studentId: widget.conversation.studentId,
          parentId: widget.conversation.parentId,
          content: text,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!resp.isSuccess) {
      AppToast.show(context, resp.displayMsg);
      return;
    }
    _inputController.clear();
    await _loadMessages();
    await widget.onSent();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: ui(428),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogHeader(conversation: widget.conversation),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(ui(24), ui(8), ui(24), ui(0)),
                  child: _loading
                      ? Center(child: AppLoadingIndicator(size: ui(28)))
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final m in _messages) ...[
                                _ChatBubble(message: m),
                                SizedBox(height: ui(8)),
                              ],
                            ],
                          ),
                        ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(ui(24), ui(12), ui(24), ui(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _InputBar(
                      controller: _inputController,
                      onSend: _onSend,
                      sending: _sending,
                    ),
                    SizedBox(height: ui(12)),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(ui(8)),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: ui(12),
                          vertical: ui(6),
                        ),
                        child: Text(
                          '退出',
                          style: TextStyle(
                            fontSize: ui(16),
                            color: _kTextDark,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.2,
                          ),
                        ),
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

// 头部紫白渐变 + 学生姓名/学号 + 家长头像 + 家长称谓
class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.conversation});

  final HomeSchoolConversation conversation;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final initial = conversation.studentName.isNotEmpty
        ? conversation.studentName.characters.first
        : '?';
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD8CCFF), Colors.white],
        ),
      ),
      padding: EdgeInsets.fromLTRB(ui(24), ui(28), ui(24), ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: ui(56),
                height: ui(56),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: ui(22),
                    color: _kPurple,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 1.0,
                  ),
                ),
              ),
              SizedBox(width: ui(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.studentName,
                      style: TextStyle(
                        fontSize: ui(16),
                        color: Colors.black,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: ui(4)),
                    Text(
                      conversation.studentNo,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          Row(
            children: [
              Container(
                width: ui(40),
                height: ui(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.person_rounded,
                  size: ui(24),
                  color: _kTextSecondary,
                ),
              ),
              SizedBox(width: ui(8)),
              Text(
                '${conversation.parentRelation}-${conversation.parentName}',
                style: TextStyle(
                  fontSize: ui(16),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 20 / 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final HomeSchoolChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final fromTeacher = message.fromTeacher;
    return Align(
      alignment: fromTeacher ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: ui(332)),
        child: Column(
          crossAxisAlignment: fromTeacher
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ui(12),
                vertical: ui(8),
              ),
              decoration: BoxDecoration(
                color: fromTeacher ? _kPurple : _kCardGreyBg,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: ui(13),
                  color: fromTeacher ? Colors.white : _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 24 / 13,
                ),
              ),
            ),
            SizedBox(height: ui(4)),
            Text(
              message.timeText,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextHintLight,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    this.sending = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(52),
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: _kCardGreyBg,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorderSoft, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppTextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              cursorColor: _kPurple,
              cursorWidth: 1.5,
              cursorHeight: ui(15),
              style: TextStyle(
                fontSize: ui(13),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 24 / 13,
              ),
              decoration: InputDecoration(
                hintText: '请输入文字',
                hintStyle: TextStyle(
                  fontSize: ui(13),
                  color: _kTextHintLight,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 24 / 13,
                ),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          SizedBox(width: ui(8)),
          // 发送按钮（紫色 pill）
          InkWell(
            onTap: sending ? null : onSend,
            borderRadius: BorderRadius.circular(ui(6)),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ui(16),
                vertical: ui(6),
              ),
              decoration: BoxDecoration(
                color: sending ? _kPurple.withValues(alpha: 0.5) : _kPurple,
                borderRadius: BorderRadius.circular(ui(6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sending ? '发送中' : '发送',
                    style: TextStyle(
                      fontSize: ui(13),
                      color: Colors.white,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(width: ui(4)),
                  Icon(Icons.send_rounded, size: ui(14), color: Colors.white),
                ],
              ),
            ),
          ),
          SizedBox(width: ui(6)),
          _IconBtn(icon: Icons.image_outlined, onTap: () {}),
          SizedBox(width: ui(4)),
          _IconBtn(icon: Icons.attach_file_rounded, onTap: () {}),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        width: ui(36),
        height: ui(36),
        decoration: BoxDecoration(
          color: _kCardGreyBg,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: ui(18), color: _kTextDark),
      ),
    );
  }
}
