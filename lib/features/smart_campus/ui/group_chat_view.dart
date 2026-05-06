// =============================================================================
// 智慧校园「群聊」独立页面（学生 / 教师 / 班主任 共用）
//
// 入口：所有角色 dashboard 快捷区「群聊」按钮 → controller.openGroupChat()
//      → mainView == groupChat → SmartCampusPage 路由到本视图。
//      返回：左侧会话栏顶部「返回」icon → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部辅助 row（位于聊天主区上方）：抽屉按钮 + 「任课老师」下拉 +
//      「管理群聊」下拉（仅视觉，未挂业务逻辑）。
//   2. 双栏聊天主区（高 ~648）：
//      左 280 会话栏（白底圆左角）：
//          · 14px 16 「会话」标题
//          · 264×40 灰底搜索框（占位"传统音乐"，仅视觉）
//          · 多条会话 cell（36 头像 + 群名 + 摘要 + 时间 + 红色未读徽章 +
//            免打扰图标），当前会话灰色高亮 #F5F6FA。
//      右 ~690 聊天主区（白底圆右角）：
//          · 顶部 68 高 gradient header：返回箭头 + 群名 + 32 人小字 +
//            右侧 抽屉/详情图标；底色为 270deg `#C0D2F1→#E8C8F9`，
//            并叠加 `#F9EEFF→#F9EEFF` 与左侧白色淡出，整体看起来像
//            浅紫白渐变。
//          · 内嵌灰底圆角内容板（#F5F6FA padding 16）承载消息流：
//            ① 顶部紫色公告条（铃铛 + 公告内容 + 「编辑公告」 + 更新时间）
//            ② 中部消息 LIST（ListView）：
//               - 系统提示：「入群通知 李老师邀请了 教务处-王教务、赵宇 加入群聊」
//                          「群公告 李老师发布了最新群公告」
//               - 日期分隔："4月13日"
//               - 文本气泡（白底）：陈老师 — 招生简章已挂网
//               - 文件气泡：上海音乐学院2026本科招生简章.pdf 3.32M（蓝渐变 + 红 PDF 角标）
//               - 语音气泡：紫播放按钮 + 灰色波形 + 28s
//               - 当前正在播放的语音：紫色波形（已播放部分）+ 灰色（未播）
//            ③ 输入栏（白底 52 高）：左 attach + textfield + 表情 + 录音 +
//               紫色「发送」按钮（输入为空时变浅）。
//
// 颜色：白卡 / #F5F6FA 灰底板 / #EFF3FC 页面底 / #8741FF 主紫
//      / #325BFF 蓝（@提及/链接）/ #FF323C 红（未读）/ #F04545 红（角标）
// 字体：PingFang SC（中文） + Manrope（数字徽章）
//
// 消息模型：参考 1.0 `the-road-of-music/pages/SmartCampus/chat.vue`
//   - type=0 系统通知（item.text）/ type=1 文本（item.content）/
//   - type=2 图片（item.content url）/ type=3 富内容（item.param1 决定子类）
//      · param1=='kj'    课件分享
//      · param1=='video' 视频分享
//      · param1=='news'  资讯分享
//      · param1=='book'  课程分享
//      · param1=='voice' 录音分享（点击切换播放，同 1.0 `playVoice`）
//   - 这里 Flutter 端把消息收敛为 `_ChatMessage` 密封类树，对应 `_TextBubble`
//     `_FileBubble` `_VoiceBubble` `_ImageBubble`，方便后续接入 socket
//     消息时直接 mapping。
// =============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/chat_repository.dart';

import '../../../core/widgets/app_text.dart';
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kCardBg = Colors.white;
const Color _kBoardBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextDivider = Color(0xFFCECED1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleLight = Color(0xFFB48BFF);
const Color _kRecordRed = Color(0xFFFF323C);
const Color _kRecordRedLight = Color(0xFFFF7A7A);
const Color _kAnnouncementBg = Color(0xBDEFE5FF); // rgba(239,229,255,0.74)
const Color _kBlueLink = Color(0xFF325BFF);
const Color _kBadgeRed = Color(0xFFFF323C);
const Color _kPdfBlueGradStart = Color(0xFFD7E2FF);
const Color _kPdfBlueGradEnd = Color(0xFFF9FBFF);
const Color _kPdfBorder = Color(0xFFE5EFFF);
const Color _kPdfRed = Color(0xFFFF5040);

// =============================================================================
// 顶级视图
// =============================================================================

class GroupChatView extends ConsumerStatefulWidget {
  const GroupChatView({
    super.key,
    required this.onBack,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserAvatarUrl,
  });

  final VoidCallback onBack;

  /// 当前登录用户的 id（来自 `myInfo.user.id`，雪花长整型字符串）。
  /// 用于 `fromUserId == currentUserId` 判断当前消息是否是自己发的。
  final String currentUserId;

  /// 当前登录用户名（出现在自己消息气泡的右侧 nickname）。
  final String currentUserName;

  /// 当前登录用户头像 URL；如果不可用，UI 会回退到首字母彩色头像。
  final String currentUserAvatarUrl;

  @override
  ConsumerState<GroupChatView> createState() => _GroupChatViewState();
}

class _GroupChatViewState extends ConsumerState<GroupChatView> {
  // —— 会话 ——————————————————————————————————————————————————————
  /// `null` = 加载中；空 List = 已加载但接口返回空。
  List<_Conversation>? _conversations;
  String? _selectedConvId;

  // —— 消息列表（针对当前会话） —————————————————————————————————
  List<_ChatMessage> _messages = const [];
  bool _loadingMessages = false;
  int _msgLoadSeq = 0;

  // —— 群详情（公告 / 成员数 / 免打扰 / 是否班主任） ——————————————————
  String _announcement = '';
  String _announcementUpdatedAt = '';
  bool _canEditAnnouncement = false;
  int? _detailMemberCount;
  int _detailLoadSeq = 0;

  // —— 发送 / 撤回 / 公告 / 免打扰 提交锁 ——————————————————————————
  bool _sending = false;
  final Set<String> _recalling = <String>{};
  bool _muteSaving = false;
  bool _announcementSaving = false;

  String? _playingVoiceId;
  double _playingFraction = 0.32;
  bool _muted = false;

  final TextEditingController _inputController = TextEditingController();

  // —— 语音录制状态 ———————————————————————————————————————————————
  // _voiceMode：mic icon 切换到语音输入模式后，输入栏被替换为大按钮。
  // _recording：长按"按住说话"时为 true，松手即结束。
  // _willCancel：录音过程中手指上滑超过阈值，进入"松开取消"状态。
  // _recordSeconds：当前录音时长秒数（每秒 +1，UI 用作 demo 文案）。
  // _liveWaveform：录音时滚动更新的随机波形采样，长度固定 _kLiveWaveLen。
  bool _voiceMode = false;
  bool _recording = false;
  bool _willCancel = false;
  int _recordSeconds = 0;
  late List<double> _liveWaveform;
  Timer? _recordTimer;
  final math.Random _rng = math.Random();
  static const int _kLiveWaveLen = 56;

  /// 上滑取消的阈值（dy 小于该值即视为进入"松开取消"区域）。
  static const double _kCancelThresholdY = -56;

  @override
  void initState() {
    super.initState();
    _liveWaveform = List<double>.filled(_kLiveWaveLen, 0.18);
    // 进入页面后立即拉群聊列表；后续 didChangeDependencies 不再重复触发。
    Future.microtask(_loadConversations);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // 接口加载
  // ===========================================================================

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  Future<void> _loadConversations() async {
    final res = await _repo.classList();
    if (!mounted) return;
    if (res.code != 0) {
      setState(() => _conversations = const []);
      AppToast.show(context, res.msg.isEmpty ? '群聊列表加载失败' : res.msg);
      return;
    }
    final list = _parseConversations(res.data);
    setState(() {
      _conversations = list;
      if (list.isNotEmpty) {
        _selectedConvId = list.first.id;
      }
    });
    if (list.isNotEmpty) {
      unawaited(_loadGroupDetail(list.first));
      unawaited(_loadMessages(list.first.id));
    }
  }

  Future<void> _loadGroupDetail(_Conversation conv) async {
    final seq = ++_detailLoadSeq;
    final res = await _repo.classDetail(classId: conv.id);
    if (!mounted || seq != _detailLoadSeq) return;
    if (res.code != 0) {
      setState(() {
        _announcement = '';
        _announcementUpdatedAt = '';
        _canEditAnnouncement = false;
        _detailMemberCount = null;
        _muted = conv.muted;
      });
      return;
    }
    final detail = _parseGroupDetail(res.data, conv);
    setState(() {
      _announcement = detail.announcement;
      _announcementUpdatedAt = detail.announcementUpdatedAt;
      _canEditAnnouncement = detail.canEditAnnouncement;
      _detailMemberCount = detail.memberCount;
      _muted = detail.doNotDisturb;
    });
  }

  Future<void> _loadMessages(String classId) async {
    final seq = ++_msgLoadSeq;
    setState(() {
      _loadingMessages = true;
      _messages = const [];
    });
    final res = await _repo.msgList(classId: classId);
    if (!mounted || seq != _msgLoadSeq) return;
    if (res.code != 0) {
      setState(() => _loadingMessages = false);
      AppToast.show(context, res.msg.isEmpty ? '消息加载失败' : res.msg);
      return;
    }
    setState(() {
      _messages = _parseMessages(res.data);
      _loadingMessages = false;
    });
  }

  // ===========================================================================
  // 交互
  // ===========================================================================

  void _selectConversation(String id) {
    if (_selectedConvId == id) return;
    final conv = _conversations?.firstWhere(
      (c) => c.id == id,
      orElse: () => _Conversation(
        id: id,
        name: '',
        lastMessage: '',
        lastTime: '',
        unread: 0,
        muted: false,
        memberCount: 0,
      ),
    );
    setState(() {
      _selectedConvId = id;
      _playingVoiceId = null;
      _abortRecording();
    });
    if (conv != null && conv.name.isNotEmpty) {
      unawaited(_loadGroupDetail(conv));
      unawaited(_loadMessages(id));
    }
  }

  void _toggleVoicePlay(String voiceMsgId) {
    setState(() {
      if (_playingVoiceId == voiceMsgId) {
        _playingVoiceId = null;
      } else {
        _playingVoiceId = voiceMsgId;
        _playingFraction = 0.32;
      }
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    final classId = _selectedConvId;
    if (classId == null) return;
    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = _UserChatMessage(
      id: tempId,
      fromUserId: widget.currentUserId,
      fromName: widget.currentUserName,
      avatarUrl: widget.currentUserAvatarUrl,
      avatarColor: const Color(0xFF8741FF),
      sentAt: DateTime.now(),
      bubble: _TextBubble(text: text),
    );
    setState(() {
      _sending = true;
      _messages = [..._messages, optimistic];
      _inputController.clear();
    });
    final res = await _repo.sendMsg(
      classId: classId,
      type: 1,
      content: text,
    );
    if (!mounted) return;
    if (res.code == 0) {
      final newId = _extractMsgId(res.data);
      setState(() {
        _sending = false;
        if (newId != null) {
          _messages = _messages
              .map(
                (m) => m.id == tempId
                    ? _replaceUserMessageId(m as _UserChatMessage, newId)
                    : m,
              )
              .toList();
        }
      });
    } else {
      setState(() {
        _sending = false;
        _messages = _messages.where((m) => m.id != tempId).toList();
        _inputController.text = text;
      });
      AppToast.show(context, res.msg.isEmpty ? '发送失败' : res.msg);
    }
  }

  /// 撤回（删除）消息：仅自己发的或群管理可发起。后端会再做权限校验。
  Future<void> _recallMessage(_UserChatMessage message) async {
    if (message.fromUserId != widget.currentUserId) return;
    final msgId = message.id;
    if (msgId.startsWith('local-')) {
      AppToast.show(context, '消息未同步，请稍后再试');
      return;
    }
    if (_recalling.contains(msgId)) return;
    final ok = await showConfirmDialog(
      context: context,
      title: '撤回消息',
      content: '确定撤回这条消息吗？',
      confirmLabel: '撤回',
    );
    if (!ok) return;
    setState(() => _recalling.add(msgId));
    final res = await _repo.deleteMsg(msgId: msgId);
    if (!mounted) return;
    if (res.code == 0) {
      setState(() {
        _messages = _messages.where((m) => m.id != msgId).toList();
        _recalling.remove(msgId);
      });
      AppToast.show(context, '已撤回');
    } else {
      setState(() => _recalling.remove(msgId));
      AppToast.show(context, res.msg.isEmpty ? '撤回失败' : res.msg);
    }
  }

  Future<void> _toggleMute() async {
    if (_muteSaving) return;
    final classId = _selectedConvId;
    if (classId == null) return;
    final next = !_muted;
    setState(() {
      _muteSaving = true;
      _muted = next;
    });
    final res = await _repo.updateDoNotDisturb(
      classId: classId,
      doNotDisturb: next,
    );
    if (!mounted) return;
    if (res.code == 0) {
      setState(() => _muteSaving = false);
      AppToast.show(context, next ? '已开启免打扰' : '已取消免打扰');
    } else {
      setState(() {
        _muteSaving = false;
        _muted = !next;
      });
      AppToast.show(context, res.msg.isEmpty ? '设置失败' : res.msg);
    }
  }

  Future<void> _editAnnouncement() async {
    if (!_canEditAnnouncement || _announcementSaving) return;
    final classId = _selectedConvId;
    if (classId == null) return;
    final text = await _showAnnouncementEditor(_announcement);
    if (text == null) return;
    final draft = text.trim();
    setState(() => _announcementSaving = true);
    final res = await _repo.updateAnnouncement(
      classId: classId,
      announcement: draft,
    );
    if (!mounted) return;
    setState(() => _announcementSaving = false);
    if (res.code == 0) {
      setState(() {
        _announcement = draft;
        _announcementUpdatedAt = '更新于 ${_formatLastTime(DateTime.now(),
            withDateForOldDays: false)}';
      });
      AppToast.show(context, '群公告已更新');
    } else {
      AppToast.show(context, res.msg.isEmpty ? '保存失败' : res.msg);
    }
  }

  Future<String?> _showAnnouncementEditor(String initial) {
    final ctrl = TextEditingController(text: initial);
    return showScaledDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return GradientHeaderDialog(
          width: 480,
          title: '编辑群公告',
          actionBar: AppDialogActionBar(
            cancelLabel: '取消',
            confirmLabel: '保存',
            onCancel: () => Navigator.of(dialogContext).pop(),
            onConfirm: () =>
                Navigator.of(dialogContext).pop(ctrl.text),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TextField(
              controller: ctrl,
              maxLines: 8,
              minLines: 6,
              maxLength: 500,
              style: const TextStyle(
                fontSize: 14,
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                height: 1.55,
              ),
              decoration: InputDecoration(
                hintText: '请输入群公告内容',
                hintStyle: const TextStyle(
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                ),
                filled: true,
                fillColor: _kBoardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kPurple, width: 1),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        );
      },
    );
  }

  // —— 语音模式切换 / 录制 ———————————————————————————————————————

  /// 输入栏 mic icon 点击 → 切到语音输入模式（大"按住说话"按钮）；
  /// 已在语音模式时 mic icon / keyboard icon 复用此函数切回文本输入。
  void _toggleVoiceMode() {
    setState(() {
      _voiceMode = !_voiceMode;
      // 切换出语音模式时，若有未发送的录音直接丢弃。
      if (!_voiceMode) _abortRecording();
    });
  }

  /// 长按按下时触发：开始录音；启动 80ms 定时器滚动更新波形 + 1s 计秒。
  void _onRecordPressStart() {
    if (_recording) return;
    _recordTimer?.cancel();
    setState(() {
      _recording = true;
      _willCancel = false;
      _recordSeconds = 0;
      _liveWaveform = List<double>.filled(_kLiveWaveLen, 0.18);
    });
    var tickAcc = 0;
    _recordTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (!mounted || !_recording) return;
      tickAcc++;
      // 每 ~12.5 个 tick (~1s) 累加一秒；上限 60s（demo 阶段防御）。
      final addSecond = tickAcc % 13 == 0;
      setState(() {
        // 左移一格再 push 一个新采样，模拟实时音量。
        final next = 0.25 + _rng.nextDouble() * 0.75;
        _liveWaveform = [..._liveWaveform.skip(1), next];
        if (addSecond && _recordSeconds < 60) _recordSeconds++;
      });
    });
  }

  /// 长按拖动时调用：根据 LongPress 起点的纵向偏移更新"是否取消"。
  void _onRecordPressMove(double offsetDy) {
    if (!_recording) return;
    final cancel = offsetDy < _kCancelThresholdY;
    if (cancel != _willCancel) {
      setState(() => _willCancel = cancel);
    }
  }

  /// 松手：根据 _willCancel 决定丢弃或发送。
  void _onRecordPressEnd() {
    if (!_recording) return;
    if (_willCancel) {
      _abortRecording();
      return;
    }
    final waveSnapshot = List<double>.from(_liveWaveform);
    // 录音时长低于 1s 视为太短，按取消处理（与 1.0 微信常见交互一致）。
    if (_recordSeconds < 1) {
      _abortRecording();
      return;
    }
    final duration = _recordSeconds;
    // 把实时波形采样重采样到约 44 个柱（与气泡内 _kDemoWaveform* 视觉一致）。
    final downsampled = _downsampleWaveform(waveSnapshot, 44);
    setState(() {
      _messages.add(
        _UserChatMessage(
          id: 'local-voice-${DateTime.now().microsecondsSinceEpoch}',
          fromUserId: widget.currentUserId,
          fromName: widget.currentUserName,
          avatarUrl: widget.currentUserAvatarUrl,
          avatarColor: const Color(0xFF8741FF),
          sentAt: DateTime.now(),
          bubble: _VoiceBubble(durationSec: duration, waveform: downsampled),
        ),
      );
      _recording = false;
      _willCancel = false;
    });
    _recordTimer?.cancel();
    _recordTimer = null;
  }

  /// 中止录音：取消 / 短按 / 切换会话 / 切走 voice mode 时统一调用。
  void _abortRecording() {
    _recordTimer?.cancel();
    _recordTimer = null;
    if (!_recording && !_willCancel) return;
    setState(() {
      _recording = false;
      _willCancel = false;
      _recordSeconds = 0;
    });
  }

  /// 把任意长度的波形重采样为 [target] 个柱：取桶平均。
  List<double> _downsampleWaveform(List<double> src, int target) {
    if (src.isEmpty) return List<double>.filled(target, 0.3);
    if (src.length <= target) {
      return List<double>.from(src);
    }
    final out = <double>[];
    final bucket = src.length / target;
    for (var i = 0; i < target; i++) {
      final start = (i * bucket).floor();
      final end = ((i + 1) * bucket).floor().clamp(start + 1, src.length);
      var sum = 0.0;
      for (var j = start; j < end; j++) {
        sum += src[j];
      }
      out.add(sum / (end - start));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final convs = _conversations;
    if (convs == null) {
      return Container(
        color: _kPageBg,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: _kPurple),
      );
    }
    // 空列表时不再「整页占位」，仍按双栏布局渲染：左栏给 _ConversationListPane
    // 内置的「暂无群聊」占位，右栏给一个无群可聊的友好状态（无 header /
    // 输入栏禁用），方便用户看清楚整体页面结构。
    final selectedId =
        convs.isEmpty ? '' : (_selectedConvId ?? convs.first.id);
    final currentConv = convs.isEmpty
        ? const _Conversation(
            id: '',
            name: '群聊',
            lastMessage: '',
            lastTime: '',
            unread: 0,
            muted: false,
            memberCount: 0,
          )
        : convs.firstWhere(
            (c) => c.id == selectedId,
            orElse: () => convs.first,
          );
    final memberCount = _detailMemberCount ?? currentConv.memberCount;
    return Container(
      color: _kPageBg,
      // 直接占满父容器，不再保留任何顶部辅助 row（任课老师 / 管理群聊
      // 等下拉按钮已下线，群信息走 header bar 上的 menu icon 入口）。
      child: _ChatLayout(
        conversations: convs,
        selectedConvId: selectedId,
        hasSelection: convs.isNotEmpty,
        onSelectConv: _selectConversation,
        messages: _messages,
        loadingMessages: _loadingMessages,
        currentUserId: widget.currentUserId,
        playingVoiceId: _playingVoiceId,
        playingFraction: _playingFraction,
        onToggleVoice: _toggleVoicePlay,
        inputController: _inputController,
        onSend: _send,
        onBack: widget.onBack,
        currentConv: currentConv,
        memberCount: memberCount,
        announcement: _announcement,
        announcementUpdatedAt: _announcementUpdatedAt,
        canEditAnnouncement: _canEditAnnouncement,
        onEditAnnouncement: _editAnnouncement,
        onRecallMessage: _recallMessage,
        muted: _muted,
        onToggleMute: _toggleMute,
        voiceMode: _voiceMode,
        recording: _recording,
        willCancel: _willCancel,
        liveWaveform: _liveWaveform,
        onToggleVoiceMode: _toggleVoiceMode,
        onRecordPressStart: _onRecordPressStart,
        onRecordPressMove: _onRecordPressMove,
        onRecordPressEnd: _onRecordPressEnd,
      ),
    );
  }
}

/// 右侧聊天主区在「无选中会话 / 群聊列表为空」时的占位（替换原本
/// 「暂无消息，发送一条吧～」，避免提示用户去发消息）。
class _NoSelectionHint extends StatelessWidget {
  const _NoSelectionHint();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: ui(40),
            color: _kTextHint,
          ),
          SizedBox(height: ui(10)),
          AppText(
            '暂无可聊的群聊',
            style: TextStyle(
              color: _kTextSecondary,
              fontSize: ui(13),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 空会话占位：接口返回 0 群时嵌在「会话栏」搜索框下方代替群列表，
/// 整体页面骨架（双栏 + header bar + 输入栏）继续保留，避免给用户
/// 「整页空白」的错觉。
class _EmptyConversationsHint extends StatelessWidget {
  const _EmptyConversationsHint();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: ui(36),
            color: _kTextHint,
          ),
          SizedBox(height: ui(8)),
          AppText(
            '暂无群聊',
            style: TextStyle(
              color: _kTextSecondary,
              fontSize: ui(13),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// （已移除：_TopActionRow / _SquareIconChip / _DropdownChip 顶部辅助 row。
// 群聊业务直接占满容器，群详情等管理入口收敛到 header bar 上的 menu icon。）

// =============================================================================
// 双栏布局
// =============================================================================

class _ChatLayout extends StatelessWidget {
  const _ChatLayout({
    required this.conversations,
    required this.selectedConvId,
    required this.hasSelection,
    required this.onSelectConv,
    required this.messages,
    required this.loadingMessages,
    required this.currentUserId,
    required this.playingVoiceId,
    required this.playingFraction,
    required this.onToggleVoice,
    required this.inputController,
    required this.onSend,
    required this.onBack,
    required this.currentConv,
    required this.memberCount,
    required this.announcement,
    required this.announcementUpdatedAt,
    required this.canEditAnnouncement,
    required this.onEditAnnouncement,
    required this.onRecallMessage,
    required this.muted,
    required this.onToggleMute,
    required this.voiceMode,
    required this.recording,
    required this.willCancel,
    required this.liveWaveform,
    required this.onToggleVoiceMode,
    required this.onRecordPressStart,
    required this.onRecordPressMove,
    required this.onRecordPressEnd,
  });

  final List<_Conversation> conversations;
  final String selectedConvId;

  /// 是否已经有「当前会话」可聊：会话列表为空 / 还没选中时为 false，
  /// 此时右侧聊天区会显示无选中占位（不显示「发送一条吧～」），
  /// 输入栏的发送按钮也由调用层在 `_send` 中拒绝处理。
  final bool hasSelection;
  final ValueChanged<String> onSelectConv;
  final List<_ChatMessage> messages;
  final bool loadingMessages;
  final String currentUserId;
  final String? playingVoiceId;
  final double playingFraction;
  final ValueChanged<String> onToggleVoice;
  final TextEditingController inputController;
  final VoidCallback onSend;
  final VoidCallback onBack;
  final _Conversation currentConv;
  final int memberCount;
  final String announcement;
  final String announcementUpdatedAt;
  final bool canEditAnnouncement;
  final VoidCallback onEditAnnouncement;
  final ValueChanged<_UserChatMessage> onRecallMessage;
  final bool muted;
  final VoidCallback onToggleMute;

  // —— 录音相关传入 ————————————————————————————————————————
  final bool voiceMode;
  final bool recording;
  final bool willCancel;
  final List<double> liveWaveform;
  final VoidCallback onToggleVoiceMode;
  final VoidCallback onRecordPressStart;
  final ValueChanged<double> onRecordPressMove;
  final VoidCallback onRecordPressEnd;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < ui(720);
        if (compact) {
          // 紧凑布局：会话列表收起为顶部 horizontal scroll；下方是 chat。
          return Column(
            children: [
              _CompactConversationStrip(
                conversations: conversations,
                selectedConvId: selectedConvId,
                onSelect: onSelectConv,
              ),
              SizedBox(height: ui(8)),
              Expanded(
                child: _ChatRightPane(
                  conv: currentConv,
                  hasSelection: hasSelection,
                  memberCount: memberCount,
                  announcement: announcement,
                  announcementUpdatedAt: announcementUpdatedAt,
                  canEditAnnouncement: canEditAnnouncement,
                  onEditAnnouncement: onEditAnnouncement,
                  onRecallMessage: onRecallMessage,
                  messages: messages,
                  loadingMessages: loadingMessages,
                  currentUserId: currentUserId,
                  playingVoiceId: playingVoiceId,
                  playingFraction: playingFraction,
                  onToggleVoice: onToggleVoice,
                  inputController: inputController,
                  onSend: onSend,
                  onBack: onBack,
                  muted: muted,
                  onToggleMute: onToggleMute,
                  outerCornerLeft: true,
                  voiceMode: voiceMode,
                  recording: recording,
                  willCancel: willCancel,
                  liveWaveform: liveWaveform,
                  onToggleVoiceMode: onToggleVoiceMode,
                  onRecordPressStart: onRecordPressStart,
                  onRecordPressMove: onRecordPressMove,
                  onRecordPressEnd: onRecordPressEnd,
                ),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: ui(280),
              child: _ConversationListPane(
                conversations: conversations,
                selectedConvId: selectedConvId,
                onSelect: onSelectConv,
              ),
            ),
            Expanded(
              child: _ChatRightPane(
                conv: currentConv,
                hasSelection: hasSelection,
                memberCount: memberCount,
                announcement: announcement,
                announcementUpdatedAt: announcementUpdatedAt,
                canEditAnnouncement: canEditAnnouncement,
                onEditAnnouncement: onEditAnnouncement,
                onRecallMessage: onRecallMessage,
                messages: messages,
                loadingMessages: loadingMessages,
                currentUserId: currentUserId,
                playingVoiceId: playingVoiceId,
                playingFraction: playingFraction,
                onToggleVoice: onToggleVoice,
                inputController: inputController,
                onSend: onSend,
                onBack: onBack,
                muted: muted,
                onToggleMute: onToggleMute,
                voiceMode: voiceMode,
                recording: recording,
                willCancel: willCancel,
                liveWaveform: liveWaveform,
                onToggleVoiceMode: onToggleVoiceMode,
                onRecordPressStart: onRecordPressStart,
                onRecordPressMove: onRecordPressMove,
                onRecordPressEnd: onRecordPressEnd,
              ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// 左 280：会话列表
// =============================================================================

class _ConversationListPane extends StatelessWidget {
  const _ConversationListPane({
    required this.conversations,
    required this.selectedConvId,
    required this.onSelect,
  });

  final List<_Conversation> conversations;
  final String selectedConvId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ui(16)),
          bottomLeft: Radius.circular(ui(16)),
        ),
        border: Border(right: BorderSide(color: _kBorderSoft)),
      ),
      padding: EdgeInsets.fromLTRB(ui(8), ui(14), ui(8), ui(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: ui(4), bottom: ui(12)),
            child: AppText(
              '会话',
              style: TextStyle(
                fontSize: ui(15),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
          _ConvSearchField(),
          SizedBox(height: ui(12)),
          Expanded(
            child: conversations.isEmpty
                ? const _EmptyConversationsHint()
                : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: conversations.length,
              separatorBuilder: (a, b) =>
                  Divider(height: 1, thickness: 0.5, color: _kBorderSoft),
              itemBuilder: (context, i) {
                final c = conversations[i];
                return _ConversationCell(
                  conv: c,
                  active: c.id == selectedConvId,
                  onTap: () => onSelect(c.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConvSearchField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(40),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      decoration: BoxDecoration(
        color: _kBoardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: ui(16),
            color: const Color(0xFFC6C6C6),
          ),
          SizedBox(width: ui(8)),
          AppText(
            '搜索群聊 / 同学',
            style: TextStyle(
              fontSize: ui(14),
              color: const Color(0xFFD1D1D1),
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationCell extends StatelessWidget {
  const _ConversationCell({
    required this.conv,
    required this.active,
    required this.onTap,
  });

  final _Conversation conv;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(60),
        padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(8)),
        decoration: BoxDecoration(
          color: active ? _kBoardBg : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _AvatarCircle(
              avatarUrl: conv.avatarUrl,
              fallback: conv.name,
              size: ui(36),
              radius: ui(8),
              color: conv.avatarColor,
            ),
            SizedBox(width: ui(10)),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    conv.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: ui(6)),
                  AppText(
                    conv.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(11),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: ui(6)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText(
                  conv.lastTime,
                  style: TextStyle(
                    fontSize: ui(11),
                    color: _kTextDivider,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: ui(8)),
                if (conv.unread > 0)
                  Container(
                    constraints: BoxConstraints(minWidth: ui(16)),
                    height: ui(16),
                    padding: EdgeInsets.symmetric(horizontal: ui(4)),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _kBadgeRed,
                      borderRadius: BorderRadius.circular(ui(8)),
                    ),
                    child: AppText(
                      conv.unread > 99 ? '99+' : '${conv.unread}',
                      style: TextStyle(
                        fontSize: ui(10),
                        color: Colors.white,
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  )
                else if (conv.muted)
                  Icon(
                    Icons.notifications_off_outlined,
                    size: ui(12),
                    color: _kTextHint,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 紧凑布局下的横向会话条带。
class _CompactConversationStrip extends StatelessWidget {
  const _CompactConversationStrip({
    required this.conversations,
    required this.selectedConvId,
    required this.onSelect,
  });

  final List<_Conversation> conversations;
  final String selectedConvId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(64),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: ui(8)),
        itemCount: conversations.length,
        separatorBuilder: (a, b) => SizedBox(width: ui(8)),
        itemBuilder: (context, i) {
          final c = conversations[i];
          final active = c.id == selectedConvId;
          return GestureDetector(
            onTap: () => onSelect(c.id),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(6)),
              decoration: BoxDecoration(
                color: active ? _kBoardBg : Colors.white,
                borderRadius: BorderRadius.circular(ui(12)),
              ),
              child: Row(
                children: [
                  _AvatarCircle(
                    avatarUrl: c.avatarUrl,
                    fallback: c.name,
                    size: ui(36),
                    radius: ui(8),
                    color: c.avatarColor,
                  ),
                  SizedBox(width: ui(6)),
                  AppText(
                    c.name,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// 右侧：聊天主区
// =============================================================================

class _ChatRightPane extends StatefulWidget {
  const _ChatRightPane({
    required this.conv,
    required this.hasSelection,
    required this.memberCount,
    required this.announcement,
    required this.announcementUpdatedAt,
    required this.canEditAnnouncement,
    required this.onEditAnnouncement,
    required this.onRecallMessage,
    required this.messages,
    required this.loadingMessages,
    required this.currentUserId,
    required this.playingVoiceId,
    required this.playingFraction,
    required this.onToggleVoice,
    required this.inputController,
    required this.onSend,
    required this.onBack,
    required this.muted,
    required this.onToggleMute,
    required this.voiceMode,
    required this.recording,
    required this.willCancel,
    required this.liveWaveform,
    required this.onToggleVoiceMode,
    required this.onRecordPressStart,
    required this.onRecordPressMove,
    required this.onRecordPressEnd,
    this.outerCornerLeft = false,
  });

  final _Conversation conv;
  final bool hasSelection;
  final int memberCount;
  final String announcement;
  final String announcementUpdatedAt;
  final bool canEditAnnouncement;
  final VoidCallback onEditAnnouncement;
  final ValueChanged<_UserChatMessage> onRecallMessage;
  final List<_ChatMessage> messages;
  final bool loadingMessages;
  final String currentUserId;
  final String? playingVoiceId;
  final double playingFraction;
  final ValueChanged<String> onToggleVoice;
  final TextEditingController inputController;
  final VoidCallback onSend;
  final VoidCallback onBack;
  final bool muted;
  final VoidCallback onToggleMute;
  final bool outerCornerLeft;

  // —— 录音相关 ———————————————————————————————————————
  final bool voiceMode;
  final bool recording;
  final bool willCancel;
  final List<double> liveWaveform;
  final VoidCallback onToggleVoiceMode;
  final VoidCallback onRecordPressStart;
  final ValueChanged<double> onRecordPressMove;
  final VoidCallback onRecordPressEnd;

  @override
  State<_ChatRightPane> createState() => _ChatRightPaneState();
}

class _ChatRightPaneState extends State<_ChatRightPane> {
  /// 表情面板开关。状态托管在 RightPane 这一层（而不是输入栏内部），
  /// 是为了把表情面板作为一个 `Positioned` 浮层，渲染到聊天主区
  /// （灰底圆角板）的 `Stack` 里 —— 视觉上**悬浮**在消息流上方，不再
  /// 在 Column 里挤压消息区高度（与微信桌面端 / 钉钉一致）。
  bool _showEmoji = false;

  void _setEmoji(bool value) {
    if (_showEmoji == value) return;
    setState(() => _showEmoji = value);
  }

  void _toggleEmoji() => _setEmoji(!_showEmoji);

  /// 在输入框光标处插入 emoji；如有选中区，则替换并把光标移到 emoji 之后。
  void _insertEmoji(String emoji) {
    final controller = widget.inputController;
    final value = controller.value;
    final text = value.text;
    final sel = value.selection;
    final start = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
    final end = sel.isValid ? sel.end.clamp(0, text.length) : text.length;
    final newText = text.replaceRange(start, end, emoji);
    final newOffset = start + emoji.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
      composing: TextRange.empty,
    );
  }

  /// 退格：以「字符簇」为单位删除，正确处理 ZWJ / 肤色 / region 等
  /// 多 code-point 组合 emoji（例如 👨‍👩‍👧‍👦 / 👍🏽 / 🇨🇳）。
  void _backspace() {
    final controller = widget.inputController;
    final value = controller.value;
    final text = value.text;
    if (text.isEmpty) return;
    final sel = value.selection;
    if (sel.isValid && sel.start != sel.end) {
      final start = sel.start.clamp(0, text.length);
      final end = sel.end.clamp(0, text.length);
      controller.value = TextEditingValue(
        text: text.replaceRange(start, end, ''),
        selection: TextSelection.collapsed(offset: start),
        composing: TextRange.empty,
      );
      return;
    }
    final cursor = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
    if (cursor == 0) return;
    final before = text.substring(0, cursor);
    final beforeChars = before.characters;
    if (beforeChars.isEmpty) return;
    final newBefore = beforeChars.skipLast(1).toString();
    final newText = newBefore + text.substring(cursor);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newBefore.length),
      composing: TextRange.empty,
    );
  }

  void _onSend() {
    if (_showEmoji) _setEmoji(false);
    widget.onSend();
  }

  void _onTapMic() {
    if (_showEmoji) _setEmoji(false);
    widget.onToggleVoiceMode();
  }

  void _onInputFocus() {
    if (_showEmoji) _setEmoji(false);
  }

  @override
  void didUpdateWidget(covariant _ChatRightPane old) {
    super.didUpdateWidget(old);
    // 切换会话 / 进入语音模式时收起表情面板，避免错位。
    if (_showEmoji && widget.voiceMode) {
      _setEmoji(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bottomBar = widget.voiceMode
        ? _VoiceHoldBar(
            recording: widget.recording,
            willCancel: widget.willCancel,
            onToggleBackToText: widget.onToggleVoiceMode,
            onPressStart: widget.onRecordPressStart,
            onPressMove: widget.onRecordPressMove,
            onPressEnd: widget.onRecordPressEnd,
          )
        : _ChatInputBar(
            controller: widget.inputController,
            onSend: _onSend,
            onTapMic: _onTapMic,
            emojiActive: _showEmoji,
            onToggleEmoji: _toggleEmoji,
            onInputFocus: _onInputFocus,
          );
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(widget.outerCornerLeft ? ui(16) : 0),
          bottomLeft: Radius.circular(widget.outerCornerLeft ? ui(16) : 0),
          topRight: Radius.circular(ui(16)),
          bottomRight: Radius.circular(ui(16)),
        ),
      ),
      child: Column(
        children: [
          _ChatHeaderBar(
            title: widget.conv.name,
            memberCount: widget.memberCount,
            muted: widget.muted,
            onToggleMute: widget.onToggleMute,
            onBack: widget.onBack,
            onShowDetail: () {},
          ),
          Expanded(
            // 用 Stack 让录音浮窗 / 表情面板悬浮在消息区底部，不挤压消息布局。
            child: Stack(
              children: [
                Positioned.fill(
                  child: _ChatBodyBoard(
                    messages: widget.messages,
                    loading: widget.loadingMessages,
                    hasSelection: widget.hasSelection,
                    announcement: widget.announcement,
                    announcementUpdatedAt: widget.announcementUpdatedAt,
                    canEditAnnouncement: widget.canEditAnnouncement,
                    onEditAnnouncement: widget.onEditAnnouncement,
                    onRecallMessage: widget.onRecallMessage,
                    currentUserId: widget.currentUserId,
                    playingVoiceId: widget.playingVoiceId,
                    playingFraction: widget.playingFraction,
                    onToggleVoice: widget.onToggleVoice,
                  ),
                ),
                if (widget.recording)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: ui(8),
                    child: Center(
                      child: _RecordingHintCard(
                        waveform: widget.liveWaveform,
                        willCancel: widget.willCancel,
                      ),
                    ),
                  ),
                if (_showEmoji)
                  Positioned(
                    left: ui(16),
                    right: ui(16),
                    bottom: ui(8),
                    child: _EmojiPanel(
                      onPick: _insertEmoji,
                      onBackspace: _backspace,
                    ),
                  ),
              ],
            ),
          ),
          bottomBar,
        ],
      ),
    );
  }
}

// =============================================================================
// 顶部 header bar（68 高 紫色渐变）
// =============================================================================

class _ChatHeaderBar extends StatelessWidget {
  const _ChatHeaderBar({
    required this.title,
    required this.memberCount,
    required this.muted,
    required this.onToggleMute,
    required this.onBack,
    required this.onShowDetail,
  });

  final String title;
  final int memberCount;
  final bool muted;
  final VoidCallback onToggleMute;
  final VoidCallback onBack;
  final VoidCallback onShowDetail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(68),
      child: Stack(
        children: [
          // 底层渐变（270deg #C0D2F1 → #E8C8F9）
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(ui(16)),
                topRight: Radius.circular(ui(16)),
              ),
              child: Stack(
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [Color(0xFFC0D2F1), Color(0xFFE8C8F9)],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                  // 右上紫白渐变（覆盖在右侧让左半看起来更白）
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.white, Color(0x00FFFFFF)],
                        stops: [0.4, 1.0],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                  // 浅紫薄膜让整体更柔和
                  const DecoratedBox(
                    decoration: BoxDecoration(color: Color(0x66F9EEFF)),
                    child: SizedBox.expand(),
                  ),
                ],
              ),
            ),
          ),
          // 底部 1 像素分割线
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(height: 0.5, color: _kBorderSoft),
          ),
          // 内容
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(ui(20), 0, ui(16), 0),
              child: Row(
                children: [
                  InkWell(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(ui(8)),
                    child: Container(
                      width: ui(32),
                      height: ui(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(ui(8)),
                        border: Border.all(color: _kBorderSoft),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: ui(20),
                        color: const Color(0xFF1C274C),
                      ),
                    ),
                  ),
                  SizedBox(width: ui(12)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          AppText(
                            title,
                            style: TextStyle(
                              fontSize: ui(14),
                              color: _kTextDark,
                              fontFamily: 'PingFang SC',
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                          ),
                          SizedBox(width: ui(8)),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: ui(14),
                            color: const Color(0xFF1C274C),
                          ),
                        ],
                      ),
                      SizedBox(height: ui(4)),
                      AppText(
                        '$memberCount人',
                        style: TextStyle(
                          fontSize: ui(11),
                          color: _kTextDivider,
                          fontFamily: 'PingFang SC',
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: onToggleMute,
                    borderRadius: BorderRadius.circular(ui(8)),
                    child: Container(
                      width: ui(32),
                      height: ui(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(ui(8)),
                      ),
                      child: Icon(
                        muted
                            ? Icons.notifications_off_rounded
                            : Icons.notifications_active_rounded,
                        size: ui(18),
                        color: muted ? _kPurple : const Color(0xFF1C274C),
                      ),
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  InkWell(
                    onTap: onShowDetail,
                    borderRadius: BorderRadius.circular(ui(8)),
                    child: Container(
                      width: ui(32),
                      height: ui(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(ui(8)),
                      ),
                      child: Icon(
                        Icons.menu_rounded,
                        size: ui(18),
                        color: const Color(0xFF1C274C),
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

// =============================================================================
// 中间消息板（灰底圆角）
// =============================================================================

class _ChatBodyBoard extends StatelessWidget {
  const _ChatBodyBoard({
    required this.messages,
    required this.loading,
    required this.hasSelection,
    required this.announcement,
    required this.announcementUpdatedAt,
    required this.canEditAnnouncement,
    required this.onEditAnnouncement,
    required this.onRecallMessage,
    required this.currentUserId,
    required this.playingVoiceId,
    required this.playingFraction,
    required this.onToggleVoice,
  });

  final List<_ChatMessage> messages;
  final bool loading;
  final bool hasSelection;
  final String announcement;
  final String announcementUpdatedAt;
  final bool canEditAnnouncement;
  final VoidCallback onEditAnnouncement;
  final ValueChanged<_UserChatMessage> onRecallMessage;
  final String currentUserId;
  final String? playingVoiceId;
  final double playingFraction;
  final ValueChanged<String> onToggleVoice;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasAnnouncement = announcement.trim().isNotEmpty;
    final showAnnouncement =
        hasSelection && (hasAnnouncement || canEditAnnouncement);
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(8), ui(16), ui(8)),
      child: Container(
        decoration: BoxDecoration(
          color: _kBoardBg,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        padding: EdgeInsets.all(ui(16)),
        child: Column(
          children: [
            if (showAnnouncement) ...[
              _AnnouncementBar(
                text: hasAnnouncement
                    ? (announcement.startsWith('[群公告]')
                          ? announcement
                          : '[群公告] $announcement')
                    : '暂未发布群公告',
                updatedAt: announcementUpdatedAt.isNotEmpty
                    ? announcementUpdatedAt
                    : '',
                editable: canEditAnnouncement,
                onEdit: onEditAnnouncement,
              ),
              SizedBox(height: ui(12)),
            ],
            Expanded(
              child: !hasSelection
                  ? const _NoSelectionHint()
                  : loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _kPurple),
                    )
                  : messages.isEmpty
                  ? const Center(
                      child: AppText(
                        '暂无消息，发送一条吧～',
                        style: TextStyle(
                          color: _kTextSecondary,
                          fontSize: 13,
                          fontFamily: 'PingFang SC',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final m = messages[i];
                        final showDate = _shouldShowDateBar(messages, i);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDate)
                              _DateDivider(
                                label: _formatDateDivider(m.sentAt),
                              ),
                            _MessageRowDispatcher(
                              message: m,
                              isMine:
                                  m is _UserChatMessage &&
                                  m.fromUserId == currentUserId,
                              playingVoiceId: playingVoiceId,
                              playingFraction: playingFraction,
                              onToggleVoice: onToggleVoice,
                              onRecallMessage: onRecallMessage,
                            ),
                            SizedBox(height: ui(14)),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _shouldShowDateBar(List<_ChatMessage> list, int i) {
    if (i == 0) return true;
    final prev = list[i - 1].sentAt;
    final cur = list[i].sentAt;
    return prev.year != cur.year ||
        prev.month != cur.month ||
        prev.day != cur.day;
  }

  static String _formatDateDivider(DateTime t) {
    final today = DateTime.now();
    if (t.year == today.year && t.month == today.month && t.day == today.day) {
      return '今天';
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (t.year == yesterday.year &&
        t.month == yesterday.month &&
        t.day == yesterday.day) {
      return '昨天';
    }
    if (t.year == today.year) {
      return '${t.month}月${t.day}日';
    }
    return '${t.year}年${t.month}月${t.day}日';
  }
}

class _AnnouncementBar extends StatelessWidget {
  const _AnnouncementBar({
    required this.text,
    required this.updatedAt,
    required this.editable,
    this.onEdit,
  });

  final String text;
  final String updatedAt;
  final bool editable;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(8)),
      decoration: BoxDecoration(
        color: _kAnnouncementBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: ui(2)),
                child: Icon(
                  Icons.campaign_rounded,
                  size: ui(14),
                  color: _kPurple,
                ),
              ),
              SizedBox(width: ui(8)),
              Expanded(
                child: AppText(
                  text,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                    height: 20 / 13,
                  ),
                ),
              ),
              if (editable)
                Padding(
                  padding: EdgeInsets.only(left: ui(8), top: ui(1)),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onEdit,
                    child: AppText(
                      '编辑公告',
                      style: TextStyle(
                        fontSize: ui(13),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (updatedAt.isNotEmpty) ...[
            SizedBox(height: ui(4)),
            Padding(
              padding: EdgeInsets.only(left: ui(20)),
              child: AppText(
                updatedAt,
                style: TextStyle(
                  fontSize: ui(11),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w400,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ui(8)),
      child: Center(
        child: AppText(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 消息行（系统提示 / 普通消息）
// =============================================================================

class _MessageRowDispatcher extends StatelessWidget {
  const _MessageRowDispatcher({
    required this.message,
    required this.isMine,
    required this.playingVoiceId,
    required this.playingFraction,
    required this.onToggleVoice,
    required this.onRecallMessage,
  });

  final _ChatMessage message;
  final bool isMine;
  final String? playingVoiceId;
  final double playingFraction;
  final ValueChanged<String> onToggleVoice;
  final ValueChanged<_UserChatMessage> onRecallMessage;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m is _SystemChatMessage) {
      return _SystemMessageRow(message: m);
    }
    if (m is _UserChatMessage) {
      return _UserMessageRow(
        message: m,
        isMine: isMine,
        playingVoiceId: playingVoiceId,
        playingFraction: playingFraction,
        onToggleVoice: onToggleVoice,
        onRecallMessage: onRecallMessage,
      );
    }
    return const SizedBox.shrink();
  }
}

class _SystemMessageRow extends StatelessWidget {
  const _SystemMessageRow({required this.message});

  final _SystemChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ui(2)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: ui(20),
            padding: EdgeInsets.symmetric(horizontal: ui(6)),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(4)),
            ),
            child: AppText(
              message.tagLabel,
              style: TextStyle(
                fontSize: ui(11),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
          ),
          SizedBox(width: ui(12)),
          Flexible(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextSecondary,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
                children: [
                  for (final seg in message.segments)
                    TextSpan(
                      text: seg.text,
                      style: TextStyle(
                        color: seg.highlight ? _kBlueLink : _kTextSecondary,
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

class _UserMessageRow extends StatelessWidget {
  const _UserMessageRow({
    required this.message,
    required this.isMine,
    required this.playingVoiceId,
    required this.playingFraction,
    required this.onToggleVoice,
    required this.onRecallMessage,
  });

  final _UserChatMessage message;
  final bool isMine;
  final String? playingVoiceId;
  final double playingFraction;
  final ValueChanged<String> onToggleVoice;
  final ValueChanged<_UserChatMessage> onRecallMessage;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final avatar = _AvatarCircle(
      avatarUrl: message.avatarUrl,
      fallback: message.fromName,
      size: ui(36),
      radius: ui(8),
      color: message.avatarColor,
    );
    Widget bubble = _BubbleDispatcher(
      message: message,
      playingVoiceId: playingVoiceId,
      playingFraction: playingFraction,
      onToggleVoice: onToggleVoice,
    );
    if (isMine) {
      bubble = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => onRecallMessage(message),
        child: bubble,
      );
    }
    final meta = Padding(
      padding: EdgeInsets.only(bottom: ui(4)),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            AppText(
              message.fromName,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
            SizedBox(width: ui(8)),
          ],
          AppText(
            _formatTime(message.sentAt),
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDivider,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
          if (isMine) ...[
            SizedBox(width: ui(8)),
            AppText(
              message.fromName,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );

    final textColumn = Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        meta,
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ui(420)),
          child: bubble,
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isMine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: isMine
          ? [Flexible(child: textColumn), SizedBox(width: ui(10)), avatar]
          : [avatar, SizedBox(width: ui(10)), Flexible(child: textColumn)],
    );
  }

  static String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// =============================================================================
// 消息气泡分发
// =============================================================================

class _BubbleDispatcher extends StatelessWidget {
  const _BubbleDispatcher({
    required this.message,
    required this.playingVoiceId,
    required this.playingFraction,
    required this.onToggleVoice,
  });

  final _UserChatMessage message;
  final String? playingVoiceId;
  final double playingFraction;
  final ValueChanged<String> onToggleVoice;

  @override
  Widget build(BuildContext context) {
    final b = message.bubble;
    if (b is _TextBubble) {
      return _TextBubbleView(text: b.text);
    }
    if (b is _FileBubble) {
      return _FileBubbleView(bubble: b);
    }
    if (b is _VoiceBubble) {
      final isPlaying = playingVoiceId == message.id;
      return _VoiceBubbleView(
        bubble: b,
        isPlaying: isPlaying,
        playedFraction: isPlaying ? playingFraction : 0,
        onTap: () => onToggleVoice(message.id),
      );
    }
    if (b is _ImageBubble) {
      return _ImageBubbleView(bubble: b);
    }
    return const SizedBox.shrink();
  }
}

// 文本气泡
class _TextBubbleView extends StatelessWidget {
  const _TextBubbleView({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: AppText(
        text,
        style: TextStyle(
          fontSize: ui(13),
          color: _kTextDark,
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w400,
          height: 24 / 13,
        ),
      ),
    );
  }
}

// 文件气泡（PDF 等）
class _FileBubbleView extends StatelessWidget {
  const _FileBubbleView({required this.bubble});

  final _FileBubble bubble;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FileIconBlock(extension: bubble.fileType),
          SizedBox(width: ui(10)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                bubble.fileName,
                style: TextStyle(
                  fontSize: ui(13),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                ),
              ),
              SizedBox(height: ui(2)),
              AppText(
                bubble.fileSize,
                style: TextStyle(
                  fontSize: ui(11),
                  color: _kTextSecondary,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FileIconBlock extends StatelessWidget {
  const _FileIconBlock({required this.extension});

  final String extension;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(34),
      height: ui(40),
      child: Stack(
        children: [
          // 蓝渐变页面
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_kPdfBlueGradStart, _kPdfBlueGradEnd],
                ),
                borderRadius: BorderRadius.circular(ui(6)),
                border: Border.all(color: _kPdfBorder, width: 0.5),
              ),
            ),
          ),
          // 内部条状装饰
          Positioned(
            left: ui(4),
            top: ui(8),
            right: ui(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: ui(8),
                  height: 2,
                  color: const Color(0xFFDAE4FF),
                ),
                SizedBox(height: ui(3)),
                Container(
                  width: ui(13),
                  height: 2,
                  color: const Color(0xFFDAE4FF),
                ),
                SizedBox(height: ui(3)),
                Container(
                  width: ui(17),
                  height: 2,
                  color: const Color(0xFFDAE4FF),
                ),
              ],
            ),
          ),
          // 红色 PDF 角标
          Positioned(
            right: -ui(2),
            bottom: ui(4),
            child: Container(
              width: ui(28),
              height: ui(11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kPdfRed,
                borderRadius: BorderRadius.circular(ui(2)),
              ),
              child: AppText(
                extension.toUpperCase(),
                style: TextStyle(
                  fontSize: ui(8),
                  color: Colors.white,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 语音气泡
class _VoiceBubbleView extends StatelessWidget {
  const _VoiceBubbleView({
    required this.bubble,
    required this.isPlaying,
    required this.playedFraction,
    required this.onTap,
  });

  final _VoiceBubble bubble;
  final bool isPlaying;
  final double playedFraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 紫色播放/暂停按钮
            Container(
              width: ui(24),
              height: ui(24),
              alignment: Alignment.center,
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: ui(20),
                color: _kPurple,
              ),
            ),
            SizedBox(width: ui(6)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(8)),
              decoration: BoxDecoration(
                color: _kBoardBg,
                borderRadius: BorderRadius.circular(ui(6)),
              ),
              child: _Waveform(
                heights: bubble.waveform,
                playedFraction: isPlaying ? playedFraction.clamp(0, 1) : 0,
                playedColor: _kPurple,
                idleColor: _kTextHint,
              ),
            ),
            SizedBox(width: ui(8)),
            AppText(
              '${bubble.durationSec}s',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.heights,
    required this.playedFraction,
    required this.playedColor,
    required this.idleColor,
  });

  /// 长度任意的归一化高度（0~1），UI 会按 16px 最大高映射。
  final List<double> heights;
  final double playedFraction;
  final Color playedColor;
  final Color idleColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final total = heights.length;
    final playedCount = (playedFraction * total).round();
    return SizedBox(
      height: ui(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++) ...[
            Container(
              width: 1,
              height: ui(2 + heights[i] * 14),
              decoration: BoxDecoration(
                color: i < playedCount ? playedColor : idleColor,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            if (i < total - 1) const SizedBox(width: 1),
          ],
        ],
      ),
    );
  }
}

// 图片气泡（占位）
class _ImageBubbleView extends StatelessWidget {
  const _ImageBubbleView({required this.bubble});

  final _ImageBubble bubble;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(8)),
      child: Image.network(
        bubble.url,
        width: ui(160),
        height: ui(160),
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, st) => Container(
          width: ui(160),
          height: ui(160),
          color: _kBoardBg,
          alignment: Alignment.center,
          child: Icon(Icons.image_outlined, color: _kTextHint, size: ui(24)),
        ),
      ),
    );
  }
}

// =============================================================================
// 输入栏
// =============================================================================

class _ChatInputBar extends StatefulWidget {
  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    required this.onTapMic,
    required this.emojiActive,
    required this.onToggleEmoji,
    required this.onInputFocus,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  /// mic icon 点击：切换到"按住说话"语音录制模式。
  final VoidCallback onTapMic;

  /// 表情 icon 是否处于「面板已展开」高亮态（决定 icon 的紫色高亮）。
  final bool emojiActive;

  /// 表情 icon 点击 → 由父层切换面板可见性（面板渲染在父层 `Stack`，
  /// 浮在消息区上方）。
  final VoidCallback onToggleEmoji;

  /// 输入框获得焦点时回调 → 父层据此自动收起表情面板。
  final VoidCallback onInputFocus;

  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  bool _hasText = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _hasText = widget.controller.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) widget.onInputFocus();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), 0, ui(16), ui(12)),
      child: Container(
        height: ui(52),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorderSoft),
        ),
        padding: EdgeInsets.symmetric(horizontal: ui(8)),
        child: Row(
          children: [
            _MiniIconButton(icon: Icons.text_fields_rounded, onTap: () {}),
            SizedBox(width: ui(12)),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                style: TextStyle(
                  fontSize: ui(13),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w400,
                  height: 24 / 13,
                ),
                decoration: InputDecoration(
                  hintText: '请输入文字',
                  hintStyle: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDivider,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w400,
                    height: 24 / 13,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: ui(8)),
                ),
                onSubmitted: (_) => widget.onSend(),
              ),
            ),
            SizedBox(width: ui(8)),
            _MiniIconButton(
              icon: Icons.mic_none_rounded,
              onTap: widget.onTapMic,
            ),
            SizedBox(width: ui(8)),
            _MiniIconButton(
              icon: Icons.emoji_emotions_outlined,
              active: widget.emojiActive,
              onTap: widget.onToggleEmoji,
            ),
            SizedBox(width: ui(8)),
            _SendButton(enabled: _hasText, onTap: widget.onSend),
          ],
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// 选中态（例如表情 icon 在表情面板已展开时变紫高亮，与微信 / 钉钉
  /// 一致），方便用户识别当前面板状态。
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        width: ui(36),
        height: ui(36),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0x1A8741FF) : _kBoardBg,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Icon(
          icon,
          size: ui(18),
          color: active ? _kPurple : const Color(0xFF1C274C),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final color = enabled ? _kPurple : _kPurple.withValues(alpha: 0.5);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              '发送',
              style: TextStyle(
                fontSize: ui(13),
                color: Colors.white,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
            SizedBox(width: ui(4)),
            Icon(Icons.send_rounded, size: ui(12), color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 表情面板（emoji picker）
// =============================================================================
//
// 显示位置：输入栏正上方，由 `_ChatInputBarState` 通过 `_showEmoji` 切换。
// 顶部高 240，9 列 4 行可见 emoji，整列竖向滚动；底部 40px 是 6 个分类
// tab + 退格按钮。点击 emoji 调 [onPick] 把对应 unicode 字符插入输入框
// 光标处；点击退格调 [onBackspace]，按字符簇（grapheme）删一个，
// 正确处理 ZWJ / 肤色变体等多 code-point 组合 emoji。
//
// emoji 选用 Unicode 字面量，不依赖任何第三方 emoji 库；Flutter 在 Web /
// Android / iOS 上都用系统默认 emoji 字体渲染，呈现效果与系统输入法一致。

class _EmojiPanel extends StatefulWidget {
  const _EmojiPanel({
    required this.onPick,
    required this.onBackspace,
  });

  final ValueChanged<String> onPick;
  final VoidCallback onBackspace;

  @override
  State<_EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<_EmojiPanel> {
  int _categoryIndex = 0;
  // 每个分类一个独立的 ScrollController，切换时滚动位置不会乱跳。
  late final List<ScrollController> _scrollControllers = List.generate(
    _kEmojiCategories.length,
    (_) => ScrollController(),
  );

  @override
  void dispose() {
    for (final c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final cat = _kEmojiCategories[_categoryIndex];
    return Container(
      height: ui(280),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorderSoft),
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: ui(20),
            offset: Offset(0, ui(4)),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              key: ValueKey<int>(_categoryIndex),
              controller: _scrollControllers[_categoryIndex],
              padding: EdgeInsets.symmetric(
                horizontal: ui(8),
                vertical: ui(8),
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 9,
                mainAxisSpacing: ui(2),
                crossAxisSpacing: ui(2),
                childAspectRatio: 1,
              ),
              itemCount: cat.emojis.length,
              itemBuilder: (context, i) {
                final e = cat.emojis[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(ui(6)),
                  onTap: () => widget.onPick(e),
                  child: Center(
                    child: AppText(
                      e,
                      style: TextStyle(
                        fontSize: ui(22),
                        // 关键：emoji 由系统字体渲染，不要带 PingFang SC
                        // 否则部分平台会回退到豆腐块。
                        height: 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 底部：分类 tabs + 退格
          Container(
            height: ui(40),
            decoration: const BoxDecoration(
              color: _kBoardBg,
              border: Border(top: BorderSide(color: _kBorderSoft)),
            ),
            padding: EdgeInsets.symmetric(horizontal: ui(8)),
            child: Row(
              children: [
                for (var i = 0; i < _kEmojiCategories.length; i++)
                  _EmojiCategoryTab(
                    icon: _kEmojiCategories[i].icon,
                    label: _kEmojiCategories[i].label,
                    active: i == _categoryIndex,
                    onTap: () => setState(() => _categoryIndex = i),
                  ),
                const Spacer(),
                _EmojiCategoryTab(
                  icon: Icons.backspace_outlined,
                  label: '退格',
                  active: false,
                  onTap: widget.onBackspace,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiCategoryTab extends StatelessWidget {
  const _EmojiCategoryTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Tooltip(
        message: label,
        child: Container(
          width: ui(32),
          height: ui(28),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(ui(6)),
          ),
          child: Icon(
            icon,
            size: ui(16),
            color: active ? _kPurple : const Color(0xFF6D6B75),
          ),
        ),
      ),
    );
  }
}

class _EmojiCategory {
  const _EmojiCategory({
    required this.label,
    required this.icon,
    required this.emojis,
  });

  final String label;
  final IconData icon;
  final List<String> emojis;
}

const List<_EmojiCategory> _kEmojiCategories = [
  _EmojiCategory(
    label: '表情',
    icon: Icons.emoji_emotions_outlined,
    emojis: [
      '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '🥲', '🥹',
      '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗',
      '😙', '😚', '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓',
      '😎', '🥸', '🤩', '🥳', '😏', '😒', '😞', '😔', '😟', '😕',
      '🙁', '☹️', '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤',
      '😠', '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰',
      '😥', '😓', '🤗', '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑',
      '😬', '🙄', '😯', '😦', '😧', '😮', '😲', '🥱', '😴', '🤤',
      '😪', '😵', '🤐', '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕',
      '🤑', '🤠', '😈', '👿', '👹', '👺', '🤡', '💩', '👻', '💀',
      '☠️', '👽', '👾', '🤖', '🎃', '😺', '😸', '😹', '😻', '😼',
      '😽', '🙀', '😿', '😾',
    ],
  ),
  _EmojiCategory(
    label: '手势',
    icon: Icons.thumb_up_alt_outlined,
    emojis: [
      '👋', '🤚', '🖐', '✋', '🖖', '👌', '🤌', '🤏', '✌️', '🤞',
      '🤟', '🤘', '🤙', '👈', '👉', '👆', '🖕', '👇', '☝️', '👍',
      '👎', '✊', '👊', '🤛', '🤜', '👏', '🙌', '👐', '🤲', '🤝',
      '🙏', '✍️', '💅', '🤳', '💪', '🦾', '🦿', '🦵', '🦶', '👂',
      '🦻', '👃', '🧠', '🫀', '🫁', '🦷', '🦴', '👀', '👁', '👅',
      '👄', '💋',
    ],
  ),
  _EmojiCategory(
    label: '心心',
    icon: Icons.favorite_border_rounded,
    emojis: [
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
      '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '♥️',
      '💌', '💯', '🔥', '⭐', '🌟', '✨', '💫', '🎉', '🎊', '🎁',
      '🎂', '💐', '🌹', '🌷', '🌸', '🌺', '🌻', '🌼', '🌈', '☀️',
      '🌙', '⛅', '☁️', '⚡', '❄️', '☔', '💧', '🌊',
    ],
  ),
  _EmojiCategory(
    label: '动物',
    icon: Icons.pets_outlined,
    emojis: [
      '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯',
      '🦁', '🐮', '🐷', '🐽', '🐸', '🐵', '🙈', '🙉', '🙊', '🐒',
      '🐔', '🐧', '🐦', '🐤', '🐣', '🐥', '🦆', '🦅', '🦉', '🦇',
      '🐺', '🐗', '🐴', '🦄', '🐝', '🐛', '🦋', '🐌', '🐞', '🐜',
      '🦟', '🦗', '🕷', '🕸', '🦂', '🐢', '🐍', '🦎', '🐙', '🦑',
      '🦐', '🦀', '🐡', '🐠', '🐟', '🐬', '🐳', '🐋', '🦈', '🐊',
      '🐅', '🐆', '🦓', '🦍', '🐘', '🦏', '🐪', '🐫', '🦒', '🐃',
      '🐂', '🐄', '🐎', '🐖', '🐏', '🐑', '🐐', '🦌', '🐕', '🐩',
      '🐈', '🐓', '🦃', '🦚', '🦜', '🦢', '🐇', '🐿', '🦔',
    ],
  ),
  _EmojiCategory(
    label: '食物',
    icon: Icons.fastfood_outlined,
    emojis: [
      '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🍈', '🍒',
      '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑', '🥦', '🥬',
      '🥒', '🌶', '🌽', '🥕', '🧄', '🧅', '🥔', '🍠', '🥐', '🥯',
      '🍞', '🥖', '🥨', '🧀', '🥚', '🍳', '🧈', '🥞', '🧇', '🥓',
      '🥩', '🍗', '🍖', '🌭', '🍔', '🍟', '🍕', '🥪', '🥙', '🌮',
      '🌯', '🥗', '🥘', '🥫', '🍝', '🍜', '🍲', '🍛', '🍣', '🍱',
      '🥟', '🦪', '🍤', '🍙', '🍚', '🍘', '🍥', '🥠', '🥮', '🍢',
      '🍡', '🍧', '🍨', '🍦', '🥧', '🧁', '🍰', '🎂', '🍮', '🍭',
      '🍬', '🍫', '🍿', '🍩', '🍪', '🌰', '🥜', '🍯', '☕', '🍵',
      '🍶', '🍺', '🍻', '🥂', '🍷', '🥃', '🍸', '🍹', '🍾', '🥤',
      '🧃', '🧉', '🧊',
    ],
  ),
  _EmojiCategory(
    label: '物品',
    icon: Icons.lightbulb_outline,
    emojis: [
      '⚽', '🏀', '🏈', '⚾', '🎾', '🏐', '🏉', '🎱', '🏓', '🏸',
      '🥅', '🥊', '🥋', '⛳', '🎯', '🎮', '🎲', '🎵', '🎶', '🎤',
      '🎧', '🎷', '🎸', '🎹', '🎺', '🎻', '🥁', '📱', '💻', '⌨️',
      '🖥', '🖨', '💽', '💾', '💿', '📀', '📷', '📹', '🎥', '📞',
      '☎️', '📟', '📠', '📺', '📻', '⏰', '⌛', '⏳', '🔋', '🔌',
      '💡', '🔦', '🕯', '🛢', '💸', '💵', '💴', '💶', '💷', '💰',
      '💳', '💎', '⚖️', '🔧', '🔨', '⚒', '🛠', '⛏', '🔩', '⚙️',
      '🧱', '⛓', '🧲', '🔫', '💣', '🏹', '🛡', '💉', '💊', '🩹',
      '🚪', '🛏', '🛋', '🚽', '🚿', '🛁', '🧼', '🧴', '🛎', '🔑',
      '🗝', '📦', '✉️', '📩', '📨', '📧', '📥', '📤', '📜', '📄',
      '📃', '📑', '📊', '📈', '📉', '📅', '📆', '📇', '📋', '📁',
      '📂', '📰', '📓', '📔', '📒', '📕', '📗', '📘', '📙', '📚',
      '🔖', '📎', '📐', '📏', '📌', '📍', '✂️', '🖊', '🖋', '✒️',
      '📝', '✏️', '🔍', '🔎', '🔒', '🔓', '🚀', '✈️', '🚗', '🚕',
      '🚙', '🚌', '🚓', '🚑', '🚒', '🚚', '🚛', '🚜', '🏍', '🚲',
      '⛵', '🚤', '🛳', '🚢', '🚉', '🚆', '🚄', '🚅',
    ],
  ),
];

// =============================================================================
// 语音输入栏（按住说话）
// =============================================================================
//
// 进入条件：用户在 `_ChatInputBar` 点击 mic icon。
// 视觉：左侧 36×36 keyboard icon 退出语音模式 → 文本模式；右侧大紫色（或
//       上滑取消时的红色）渐变按钮"按住说话"。
// 手势：通过 GestureDetector 的 onLongPressStart / onLongPressMoveUpdate /
//       onLongPressEnd / onLongPressCancel 串联一次完整录音；
//       上滑超过 _kCancelThresholdY 进入取消区，按钮变红，文案变"松开取消"。

class _VoiceHoldBar extends StatelessWidget {
  const _VoiceHoldBar({
    required this.recording,
    required this.willCancel,
    required this.onToggleBackToText,
    required this.onPressStart,
    required this.onPressMove,
    required this.onPressEnd,
  });

  final bool recording;
  final bool willCancel;
  final VoidCallback onToggleBackToText;
  final VoidCallback onPressStart;
  final ValueChanged<double> onPressMove;
  final VoidCallback onPressEnd;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final useRed = recording && willCancel;
    final gradColors = useRed
        ? const [_kRecordRedLight, _kRecordRed]
        : const [_kPurpleLight, _kPurple];
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), 0, ui(16), ui(12)),
      child: Container(
        height: ui(52),
        padding: EdgeInsets.symmetric(horizontal: ui(8)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          children: [
            _MiniIconButton(
              icon: Icons.keyboard_outlined,
              onTap: onToggleBackToText,
            ),
            SizedBox(width: ui(8)),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (_) => onPressStart(),
                onLongPressMoveUpdate: (d) =>
                    onPressMove(d.localOffsetFromOrigin.dy),
                onLongPressEnd: (_) => onPressEnd(),
                onLongPressCancel: onPressEnd,
                child: Container(
                  height: ui(36),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: gradColors,
                    ),
                    borderRadius: BorderRadius.circular(ui(8)),
                    boxShadow: [
                      BoxShadow(
                        color: (useRed ? _kRecordRed : _kPurple).withValues(
                          alpha: 0.18,
                        ),
                        blurRadius: ui(8),
                        offset: Offset(0, ui(2)),
                      ),
                    ],
                  ),
                  child: AppText(
                    '按住说话',
                    style: TextStyle(
                      fontSize: ui(14),
                      color: Colors.white,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w500,
                      height: 1,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 录音浮窗：实时波形 + 提示文案（"松开发送 上滑取消" / "松开取消"）
// =============================================================================

class _RecordingHintCard extends StatelessWidget {
  const _RecordingHintCard({required this.waveform, required this.willCancel});

  final List<double> waveform;
  final bool willCancel;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final color = willCancel ? _kRecordRed : _kPurple;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: ui(320)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(20), vertical: ui(16)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(16)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1C274C).withValues(alpha: 0.06),
              blurRadius: ui(16),
              offset: Offset(0, ui(4)),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: ui(56),
              child: _LiveBigWaveform(heights: waveform, color: color),
            ),
            SizedBox(height: ui(12)),
            AppText(
              willCancel ? '松开取消' : '松开发送 上滑取消',
              style: TextStyle(
                fontSize: ui(12),
                color: willCancel ? _kRecordRed : _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 1,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 录音浮窗专用的大波形：每个柱 2px 宽 + 2px 间距，最高 ≈48px，
/// 颜色随取消/正常态切换。
class _LiveBigWaveform extends StatelessWidget {
  const _LiveBigWaveform({required this.heights, required this.color});

  final List<double> heights;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final maxHeight = ui(48);
    final base = ui(3);
    final barW = ui(2);
    final gap = ui(2);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < heights.length; i++) ...[
          Container(
            width: barW,
            height: base + heights[i] * (maxHeight - base),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(barW),
            ),
          ),
          if (i < heights.length - 1) SizedBox(width: gap),
        ],
      ],
    );
  }
}

// =============================================================================
// 通用组件
// =============================================================================

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.avatarUrl,
    required this.fallback,
    required this.size,
    required this.radius,
    required this.color,
  });

  final String? avatarUrl;
  final String fallback;
  final double size;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hasUrl = (avatarUrl ?? '').isNotEmpty;
    final ch = fallback.isNotEmpty ? fallback.characters.first : '?';
    final initial = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: AppText(
        ch,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
    if (!hasUrl) return initial;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, st) => initial,
      ),
    );
  }
}

// =============================================================================
// 数据模型 + Demo
// =============================================================================

class _Conversation {
  const _Conversation({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.lastTime,
    required this.unread,
    required this.muted,
    required this.memberCount,
    this.avatarColor = const Color(0xFF8741FF),
  });

  final String id;
  final String name;
  final String lastMessage;
  final String lastTime;
  final int unread;
  final bool muted;
  final int memberCount;
  final Color avatarColor;
  // Demo 阶段不接入远程头像 url；统一走首字母彩色 fallback。
  String? get avatarUrl => null;
}

abstract class _ChatMessage {
  const _ChatMessage({required this.id, required this.sentAt});

  final String id;
  final DateTime sentAt;
}

/// 系统通知（对应 1.0 chat.vue 的 type === 0）
class _SystemChatMessage extends _ChatMessage {
  _SystemChatMessage({
    required super.id,
    required super.sentAt,
    required this.tagLabel,
    required this.segments,
  });

  final String tagLabel; // 入群通知 / 群公告 ...
  final List<_RichSpan> segments;
}

class _RichSpan {
  // ignore: unused_element_parameter
  const _RichSpan(this.text, {this.highlight = false});

  final String text;
  final bool highlight;
}

/// 用户消息（type 1/2/3）
class _UserChatMessage extends _ChatMessage {
  _UserChatMessage({
    required super.id,
    required super.sentAt,
    required this.fromUserId,
    required this.fromName,
    required this.bubble,
    this.avatarUrl,
    this.avatarColor = const Color(0xFF8741FF),
  });

  final String fromUserId;
  final String fromName;
  final String? avatarUrl;
  final Color avatarColor;
  final _ChatBubble bubble;
}

abstract class _ChatBubble {
  const _ChatBubble();
}

class _TextBubble extends _ChatBubble {
  const _TextBubble({required this.text});

  final String text;
}

class _ImageBubble extends _ChatBubble {
  const _ImageBubble({required this.url});

  final String url;
}

class _VoiceBubble extends _ChatBubble {
  const _VoiceBubble({required this.durationSec, required this.waveform});

  final int durationSec;
  final List<double> waveform;
}

class _FileBubble extends _ChatBubble {
  const _FileBubble({
    required this.fileName,
    required this.fileSize,
    required this.fileType, // 'pdf' / 'doc' ...
  });

  final String fileName;
  final String fileSize;
  final String fileType;
}

// =============================================================================
// 解析 1.0 后端返回的原始 message JSON 为 _ChatMessage 树
// =============================================================================
//
// 1.0 chat.vue 的消息字段约定（节选 chat.vue 第 13~248 行）：
//   - id / msgId / messageId：消息唯一 id
//   - createTime / sendTime / msgTime：发送时间
//   - fromUserId、userName、userHead
//   - type==0：系统通知，content 是字符串/text
//   - type==1：text，content 字符串（可能含表情 img）
//   - type==2：image，content 是 url
//   - type==3：富内容，param1 决定 sub-kind，content 是 JSON 字符串
//
// 这里写一个 best-effort 的 parse，前端 demo 阶段其实用不到，但保留以后接
// socket / REST 时可以直接接入。这里把内部气泡树包成 dynamic 暴露，避免
// 把私有类型直接写进 public API（library_private_types_in_public_api）。
class GroupChatMessageParser {
  const GroupChatMessageParser();

  /// 返回内部 `_ChatMessage` 实例（动态类型暴露），调用方只需要把它放进
  /// `messages` 列表即可（Demo 接口）。
  dynamic parseRaw(Map<String, dynamic> raw) {
    return _parseInternal(raw);
  }

  _ChatMessage? _parseInternal(Map<String, dynamic> raw) {
    final id =
        (raw['id'] ?? raw['msgId'] ?? raw['messageId'])?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final time = _parseDate(
      raw['createTime'] ?? raw['sendTime'] ?? raw['msgTime'],
    );
    final type = raw['type'];
    if (type == 0) {
      // 1.0 系统消息只有 text 字段，这里 fallback 到 content。
      final text = (raw['text'] ?? raw['content'] ?? '').toString();
      return _SystemChatMessage(
        id: id,
        sentAt: time,
        tagLabel: '系统消息',
        segments: [_RichSpan(text)],
      );
    }
    final fromId = raw['fromUserId']?.toString() ?? '';
    final fromName =
        raw['userName']?.toString() ?? raw['nickname']?.toString() ?? '';
    final avatar = raw['userHead']?.toString() ?? raw['headUrl']?.toString();
    final color = _avatarColorFor(fromId);
    _ChatBubble? bubble;
    if (type == 1) {
      bubble = _TextBubble(text: raw['content']?.toString() ?? '');
    } else if (type == 2) {
      bubble = _ImageBubble(url: raw['content']?.toString() ?? '');
    } else if (type == 3) {
      // param1 子类
      final p1 = raw['param1']?.toString() ?? '';
      // content 可能是字符串（JSON）或对象。
      final content = raw['content'];
      Map<String, dynamic>? obj;
      if (content is Map<String, dynamic>) obj = content;
      // 这里只接 voice / file，其它子类（kj/video/news/book）忽略，
      // 等到具体业务接入再补。
      if (p1 == 'voice') {
        final dur = (obj?['duration'] ?? 0).toString();
        bubble = _VoiceBubble(
          durationSec: int.tryParse(dur) ?? 0,
          waveform: _kDemoWaveformIdle,
        );
      } else if (p1 == 'file') {
        bubble = _FileBubble(
          fileName: (obj?['name'] ?? '未命名文件').toString(),
          fileSize: (obj?['size'] ?? '').toString(),
          fileType: ((obj?['ext'] ?? 'pdf').toString()).toLowerCase(),
        );
      }
    }
    if (bubble == null) return null;
    return _UserChatMessage(
      id: id,
      sentAt: time,
      fromUserId: fromId,
      fromName: fromName,
      avatarUrl: avatar,
      avatarColor: color,
      bubble: bubble,
    );
  }

  DateTime _parseDate(Object? raw) {
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Color _avatarColorFor(String uid) {
    final palette = <Color>[
      Color(0xFF325BFF),
      Color(0xFFF97316),
      Color(0xFFB98FFF),
      Color(0xFF12CE51),
      Color(0xFF8741FF),
    ];
    if (uid.isEmpty) return palette.first;
    final h = uid.hashCode.abs();
    return palette[h % palette.length];
  }
}

// =============================================================================
// API 响应 → UI model 解析（_parseConversations / _parseMessages /
// _parseGroupDetail），以及发送消息后从响应抽 msgId 的 helper。
// =============================================================================

class _GroupDetail {
  const _GroupDetail({
    required this.announcement,
    required this.announcementUpdatedAt,
    required this.canEditAnnouncement,
    required this.memberCount,
    required this.doNotDisturb,
  });

  final String announcement;
  final String announcementUpdatedAt;
  final bool canEditAnnouncement;
  final int? memberCount;
  final bool doNotDisturb;
}

List<_Conversation> _parseConversations(Object? raw) {
  final list = _asList(raw);
  if (list.isEmpty) return const [];
  final out = <_Conversation>[];
  for (final item in list) {
    if (item is! Map) continue;
    final m = item.map((k, v) => MapEntry(k.toString(), v));
    final id = (m['id'] ?? m['classId'])?.toString();
    if (id == null || id.isEmpty) continue;
    final name = (m['name'] ?? m['className'] ?? '').toString();
    final lastMsgRaw =
        m['lastMsg'] ?? m['lastMessage'] ?? m['lastContent'] ?? '';
    final lastTimeMs = m['lastTime'] ?? m['lastMsgTime'] ?? m['updateTime'];
    final unreadRaw = m['unread'] ?? m['unreadCount'] ?? m['badge'] ?? 0;
    final muted =
        m['doNotDisturb'] == true ||
        m['muted'] == true ||
        m['isMute'] == true ||
        (m['doNotDisturb'] is num && (m['doNotDisturb'] as num) != 0);
    final memberRaw = m['memberCount'] ?? m['userCount'] ?? m['memberNum'] ?? 0;
    out.add(
      _Conversation(
        id: id,
        name: name.isEmpty ? '群聊' : name,
        lastMessage: lastMsgRaw.toString(),
        lastTime: _formatLastTime(_parseDateTime(lastTimeMs)),
        unread: _asInt(unreadRaw) ?? 0,
        muted: muted,
        memberCount: _asInt(memberRaw) ?? 0,
        avatarColor: _avatarColorFor(id),
      ),
    );
  }
  return out;
}

List<_ChatMessage> _parseMessages(Object? raw) {
  // msgList 可能返回数组、{records: []}、{list: []} 等多种结构。
  final list = _asList(raw is Map ? (raw['records'] ?? raw['list']) : raw);
  if (list.isEmpty) return const [];
  const parser = GroupChatMessageParser();
  final out = <_ChatMessage>[];
  for (final item in list) {
    if (item is! Map) continue;
    final m = item.map((k, v) => MapEntry(k.toString(), v));
    final parsed = parser.parseRaw(m);
    if (parsed is _ChatMessage) out.add(parsed);
  }
  // 后端按降序，UI 按升序。
  out.sort((a, b) => a.sentAt.compareTo(b.sentAt));
  return out;
}

_GroupDetail _parseGroupDetail(Object? raw, _Conversation fallback) {
  final m = raw is Map
      ? raw.map((k, v) => MapEntry(k.toString(), v))
      : <String, dynamic>{};
  final schoolClass = m['schoolClass'];
  final classMap = schoolClass is Map
      ? schoolClass.map((k, v) => MapEntry(k.toString(), v))
      : const <String, dynamic>{};

  final announcement =
      (m['announcement'] ?? classMap['announcement'] ?? '').toString();
  final announcementBy =
      (m['announcementUserName'] ??
              m['announcementBy'] ??
              classMap['announcementUserName'] ??
              '')
          .toString();
  final announcementAt = _parseDateTime(
    m['announcementTime'] ??
        m['announcementUpdateTime'] ??
        classMap['announcementTime'],
  );
  String updatedAt = '';
  if (announcement.isNotEmpty && announcementAt != null) {
    final whenLabel = _formatLastTime(announcementAt, withDateForOldDays: true);
    updatedAt = announcementBy.isEmpty
        ? '更新于 $whenLabel'
        : '更新于 $announcementBy $whenLabel';
  } else if (announcement.isNotEmpty && announcementBy.isNotEmpty) {
    updatedAt = '更新于 $announcementBy';
  }

  final memberCount = _asInt(
    m['memberCount'] ?? m['userCount'] ?? classMap['memberCount'],
  );
  final canEdit =
      m['isHeadTeacher'] == true ||
      m['canEditAnnouncement'] == true ||
      m['isManager'] == true ||
      m['isAdmin'] == true ||
      (m['role']?.toString() == 'headTeacher') ||
      (m['role']?.toString() == 'admin');
  final doNotDisturb =
      m['doNotDisturb'] == true ||
      m['muted'] == true ||
      (m['doNotDisturb'] is num && (m['doNotDisturb'] as num) != 0) ||
      fallback.muted;
  return _GroupDetail(
    announcement: announcement,
    announcementUpdatedAt: updatedAt,
    canEditAnnouncement: canEdit,
    memberCount: memberCount,
    doNotDisturb: doNotDisturb,
  );
}

/// 从 sendMsg 响应里把新消息 id 摘出来：data 可能是数字 / 字符串 /
/// 含 `msgId` 的对象。
String? _extractMsgId(Object? data) {
  if (data == null) return null;
  if (data is num) return data.toString();
  if (data is String) return data.isEmpty ? null : data;
  if (data is Map) {
    final v = data['msgId'] ?? data['id'] ?? data['messageId'];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }
  return null;
}

/// 复用既有 _UserChatMessage，把临时 `local-...` id 替换为后端真实 msgId。
_UserChatMessage _replaceUserMessageId(_UserChatMessage src, String newId) {
  return _UserChatMessage(
    id: newId,
    sentAt: src.sentAt,
    fromUserId: src.fromUserId,
    fromName: src.fromName,
    avatarUrl: src.avatarUrl,
    avatarColor: src.avatarColor,
    bubble: src.bubble,
  );
}

List<dynamic> _asList(Object? raw) {
  if (raw is List) return raw;
  if (raw is Map) {
    final inner = raw['records'] ?? raw['list'] ?? raw['data'];
    if (inner is List) return inner;
  }
  return const [];
}

int? _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

DateTime? _parseDateTime(Object? raw) {
  if (raw == null) return null;
  if (raw is num) {
    return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
  }
  if (raw is String) {
    if (raw.isEmpty) return null;
    final v = int.tryParse(raw);
    if (v != null && raw.length >= 10) {
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }
  return null;
}

/// 给会话列表的 lastTime / 公告 updatedAt 用：今天 = HH:mm，昨天 =「昨天」，
/// 同年 = M月D日，不同年 = YYYY-MM-DD。
String _formatLastTime(DateTime? t, {bool withDateForOldDays = false}) {
  if (t == null) return '';
  final now = DateTime.now();
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  String hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (sameDay(t, now)) return hm(t);
  final yesterday = now.subtract(const Duration(days: 1));
  if (sameDay(t, yesterday)) {
    return withDateForOldDays ? '昨天 ${hm(t)}' : '昨天';
  }
  if (t.year == now.year) {
    return withDateForOldDays
        ? '${t.month}月${t.day}日 ${hm(t)}'
        : '${t.month}月${t.day}日';
  }
  return withDateForOldDays
      ? '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} ${hm(t)}'
      : '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

Color _avatarColorFor(String key) {
  const palette = <Color>[
    Color(0xFF8741FF),
    Color(0xFF325BFF),
    Color(0xFFF97316),
    Color(0xFFB98FFF),
    Color(0xFF12CE51),
    Color(0xFFFF6A00),
  ];
  if (key.isEmpty) return palette.first;
  return palette[key.hashCode.abs() % palette.length];
}

// =============================================================================
// 录音波形 demo 采样：消息解析器解析 voice 消息时，后端只回返时长，
// 没有真实波形，先用一组固定的样本充当占位。
// =============================================================================

const _kDemoWaveformIdle = <double>[
  0.5,
  1.0,
  0.4,
  0.6,
  1.0,
  0.1,
  0.25,
  0.5,
  0.6,
  0.5,
  0.25,
  0.1,
  1.0,
  0.6,
  1.0,
  0.6,
  1.0,
  0.6,
  1.0,
  1.0,
  0.6,
  1.0,
  0.6,
  1.0,
  0.4,
  0.4,
  1.0,
  0.4,
  0.4,
  0.4,
  0.4,
  0.4,
  0.4,
  0.4,
  0.25,
  0.6,
  0.6,
  0.25,
  0.6,
  1.0,
  0.25,
  0.6,
  0.25,
  0.6,
];

