import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../state/ai_chat_controller.dart';
import '../state/ai_chat_state.dart';

const _border = Color(0xFFF3F2F3);
const _panelFill = Color(0xFFF4F4FF);
const _textPrimary = Color(0xFF0B081A);
const _textSecondary = Color(0xFF707790);
const _textHint = Color(0xFFB6B5BB);
const _purple = Color(0xFF8741FF);
const _purpleSoft = Color(0x0D8741FF);
const _green = Color(0xFF0CAC40);
const _greenSoft = Color(0x0D0CAC40);

const _historyPaneWidth = 230.0;
const _mainHorizontalPadding = 64.0;
const _mainTopPadding = 40.0;
const _mainBottomPadding = 12.0;

const _theoryPrompts = <_AiPromptQuestion>[
  _AiPromptQuestion('1', '大小调怎么快速区分？', Color(0xFFEB2F2F)),
  _AiPromptQuestion('2', '增四度和减五度为什么是三全音？', Color(0xFFEB2F2F)),
  _AiPromptQuestion('3', '属七为什么必须解决？', Color(0xFFFE7B3F)),
  _AiPromptQuestion('4', '4/4 和 6/8 区别在哪？', _textHint),
  _AiPromptQuestion('5', '同主音大小调区别？', _textHint),
  _AiPromptQuestion('6', '常用音乐术语（中英对照）', _textHint),
];

const _toolShortcuts = <_AiToolShortcut>[
  _AiToolShortcut(
    title: '分析乐谱',
    subtitle: 'AI 智能解析乐谱数据',
    prompt: '请帮我分析这份乐谱的结构、难点和练习重点。',
    asset: AppAssets.aiChatV2ToolAnalyze,
  ),
  _AiToolShortcut(
    title: '提供练习建议',
    subtitle: 'AI 科学规划练习内容',
    prompt: '请根据音乐艺考训练场景，帮我制定一份更高效的练习建议。',
    asset: AppAssets.aiChatV2ToolSuggest,
  ),
  _AiToolShortcut(
    title: '制定考试计划',
    subtitle: 'AI 定制备考方案',
    prompt: '请帮我制定一份音乐艺考备考计划，分阶段说明每日练习重点。',
  ),
];

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  String _messageSignature = '';

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatControllerProvider);
    final controller = ref.read(aiChatControllerProvider.notifier);
    _scheduleScrollIfNeeded(state);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
        color: state.isNewConversation ? null : Colors.white,
        gradient: state.isNewConversation
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEFEFFD), Colors.white, Colors.white],
                stops: [0, 0.34, 1],
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            SizedBox(
              width: _historyPaneWidth,
              child: _buildHistoryPane(state, controller),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final mainWidth =
                      constraints.maxWidth - _mainHorizontalPadding * 2;
                  final composerWidth = mainWidth > 0
                      ? mainWidth
                      : constraints.maxWidth;
                  final userBubbleWidth = (mainWidth * 0.62)
                      .clamp(220.0, 420.0)
                      .toDouble();
                  final aiBubbleWidth = (mainWidth * 0.78)
                      .clamp(320.0, 560.0)
                      .toDouble();

                  if (state.isNewConversation) {
                    return _buildLanding(
                      state: state,
                      controller: controller,
                      composerWidth: composerWidth,
                    );
                  }
                  return _buildConversation(
                    state: state,
                    controller: controller,
                    composerWidth: composerWidth,
                    userBubbleMaxWidth: userBubbleWidth,
                    aiBubbleMaxWidth: aiBubbleWidth,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryPane(AiChatState state, AiChatController controller) {
    final groups = groupSessionsByTime(state.sessions);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: 199,
              height: 36,
              child: Material(
                color: _panelFill,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    controller.startNewChat();
                    _inputCtrl.clear();
                    setState(() {});
                  },
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppAssetGraphic(
                          AppAssets.aiChatV2NewChatPlus,
                          width: 16,
                          height: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '开启新对话',
                          style: TextStyle(
                            color: _purple,
                            fontSize: 14,
                            fontFamily: 'PingFang SC',
                            fontWeight: FontWeight.w500,
                            height: 1.42,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '全部',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Spacer(),
                AppAssetGraphic(
                  AppAssets.aiChatV2HistoryFilter,
                  width: 16,
                  height: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: state.sessionsLoading && state.sessions.isEmpty
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        const Text(
                          '历史对话',
                          style: TextStyle(
                            color: _textHint,
                            fontSize: 12,
                            fontFamily: 'PingFang SC',
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (state.isNewConversation) ...[
                          _historyTile(
                            title: '新对话',
                            active: true,
                            showMore: true,
                            onTap: () {
                              controller.startNewChat();
                              _inputCtrl.clear();
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 6),
                        ],
                        for (final group in groups)
                          if (group.items.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
                              child: Text(
                                group.label,
                                style: const TextStyle(
                                  color: Color(0xFFCECED1),
                                  fontSize: 12,
                                  fontFamily: 'PingFang SC',
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            for (final session in group.items) ...[
                              _historyTile(
                                title: session.title,
                                active:
                                    !state.isNewConversation &&
                                    state.activeSessionId == session.id,
                                showMore:
                                    !state.isNewConversation &&
                                    state.activeSessionId == session.id,
                                onTap: () async {
                                  final error = await controller.selectSession(
                                    session.id,
                                  );
                                  if (error != null && mounted) {
                                    _showInfo(error);
                                  }
                                },
                                onMoreTap: () =>
                                    _confirmDeleteSession(controller, session),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ],
                        const SizedBox(height: 8),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTile({
    required String title,
    required bool active,
    required VoidCallback onTap,
    bool showMore = false,
    VoidCallback? onMoreTap,
  }) {
    return SizedBox(
      width: 198,
      height: 40,
      child: Material(
        color: active ? _panelFill : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
                      height: 1.42,
                    ),
                  ),
                ),
                if (showMore)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onMoreTap,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: AppAssetGraphic(
                        AppAssets.aiChatV2HistoryMore,
                        width: 13.3,
                        height: 3.1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanding({
    required AiChatState state,
    required AiChatController controller,
    required double composerWidth,
  }) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              _mainHorizontalPadding,
              _mainTopPadding,
              _mainHorizontalPadding,
              20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeSection(),
                const SizedBox(height: 28),
                SizedBox(
                  height: 265,
                  child: Row(
                    children: [
                      Expanded(child: _buildTheoryCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildToolCard()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _mainHorizontalPadding,
            0,
            _mainHorizontalPadding,
            _mainBottomPadding,
          ),
          child: _buildComposer(state, controller, composerWidth),
        ),
        _buildDisclaimer(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildWelcomeSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A8A47FF),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Center(
            child: AppAssetGraphic(
              AppAssets.aiChatV2IntroLogo,
              width: 32,
              height: 32,
            ),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '我是小艺同学，很高兴见到你！',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 20,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '专属音乐AI问答助手，秒解专业疑问，梳理艺考考点，全程陪伴学习，让音乐备考更轻松高效。',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w400,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTheoryCard() {
    return Container(
      height: 265,
      decoration: BoxDecoration(
        color: _panelFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '音乐理论问题',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              '让你的艺考之路更加顺畅~',
              style: TextStyle(
                color: _textHint,
                fontSize: 12,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w400,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _theoryPrompts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final item = _theoryPrompts[index];
                  return InkWell(
                    onTap: () => _handlePromptTap(item.text),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.indexLabel,
                            style: TextStyle(
                              color: item.indexColor,
                              fontSize: 16,
                              fontFamily: 'Barlow',
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 12,
                                fontFamily: 'PingFang SC',
                                fontWeight: FontWeight.w400,
                                height: 1.55,
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
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard() {
    return Container(
      height: 265,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFD4D2FF), Color(0xFFF3F3FF)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '效率工具',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              '音乐学习就用艺同学',
              style: TextStyle(
                color: _textHint,
                fontSize: 12,
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w400,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _toolShortcuts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final tool = _toolShortcuts[index];
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _handlePromptTap(tool.prompt),
                      child: SizedBox(
                        height: 50,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              _buildToolIcon(tool),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tool.title,
                                      style: const TextStyle(
                                        color: _textPrimary,
                                        fontSize: 12,
                                        fontFamily: 'PingFang SC',
                                        fontWeight: FontWeight.w500,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      tool.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _textHint,
                                        fontSize: 10,
                                        fontFamily: 'PingFang SC',
                                        fontWeight: FontWeight.w400,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolIcon(_AiToolShortcut tool) {
    if (tool.asset != null) {
      return AppAssetGraphic(tool.asset!, width: 30, height: 30);
    }

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFFFFBEE9), Color(0xFFFF73D0)],
        ),
      ),
      child: Center(
        child: Stack(
          children: const [
            AppAssetGraphic(
              AppAssets.aiChatV2ToolPlanVector1,
              width: 14,
              height: 14,
            ),
            Positioned(
              right: 1,
              top: 1,
              child: AppAssetGraphic(
                AppAssets.aiChatV2ToolPlanVector2,
                width: 10,
                height: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation({
    required AiChatState state,
    required AiChatController controller,
    required double composerWidth,
    required double userBubbleMaxWidth,
    required double aiBubbleMaxWidth,
  }) {
    return Column(
      children: [
        Container(
          height: 56,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: Text(
            _activeTitle(state),
            style: const TextStyle(
              color: Color(0xFF14214E),
              fontSize: 15,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ),
        Expanded(
          child: state.messagesLoading && state.messages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(
                    _mainHorizontalPadding,
                    28,
                    _mainHorizontalPadding,
                    20,
                  ),
                  itemCount:
                      state.messages.length + (state.waitingAssistant ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.messages.length) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: Text(
                          '小艺同学正在思考中…',
                          style: TextStyle(
                            color: _textHint,
                            fontSize: 13,
                            fontFamily: 'PingFang SC',
                            height: 1.5,
                          ),
                        ),
                      );
                    }
                    final message = state.messages[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: message.type == AiChatMessageType.user
                          ? _buildUserMessage(
                              message: message,
                              controller: controller,
                              maxWidth: userBubbleMaxWidth,
                            )
                          : _buildAiMessage(
                              message: message,
                              controller: controller,
                              maxWidth: aiBubbleMaxWidth,
                            ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _mainHorizontalPadding,
            0,
            _mainHorizontalPadding,
            _mainBottomPadding,
          ),
          child: _buildComposer(state, controller, composerWidth),
        ),
        _buildDisclaimer(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildUserMessage({
    required AiChatMessage message,
    required AiChatController controller,
    required double maxWidth,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: _panelFill,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontFamily: 'PingFang SC',
                    height: 1.55,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionIcon(
                  icon: Icons.content_copy_outlined,
                  onTap: () => _copyText(message.text),
                ),
                const SizedBox(width: 10),
                _actionIcon(
                  icon: Icons.edit_outlined,
                  onTap: () => _reuseText(message.text),
                ),
                if (message.status == AiChatMessageStatus.failed) ...[
                  const SizedBox(width: 10),
                  _actionIcon(
                    icon: Icons.refresh_rounded,
                    color: const Color(0xFFF59E0B),
                    onTap: () async {
                      final error = await controller.resendMessage(message);
                      if (error != null && mounted) {
                        _showInfo(error);
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiMessage({
    required AiChatMessage message,
    required AiChatController controller,
    required double maxWidth,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.reasoning.isNotEmpty) ...[
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => controller.toggleReasoningExpanded(message.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppAssetGraphic(
                        AppAssets.aiChatThinkActive,
                        width: 14,
                        height: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        message.reasoningExpanded ? '已思考（点击收起）' : '已思考（点击展开）',
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 13,
                          fontFamily: 'PingFang SC',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (message.reasoningExpanded) ...[
                const SizedBox(height: 6),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _panelFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                    child: _MessageText(message.reasoning),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: _MessageText(message.text),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionIcon(
                  icon: Icons.content_copy_outlined,
                  onTap: () => _copyText(message.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required VoidCallback onTap,
    Color color = const Color(0xFF99A1AF),
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _buildComposer(
    AiChatState state,
    AiChatController controller,
    double width,
  ) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: Container(
        width: double.infinity,
        height: 104,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0B081A),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: _inputCtrl,
                    maxLines: 1,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
                      height: 1.6,
                    ),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: '流行音乐中常见的和弦进行有哪些？',
                      hintStyle: TextStyle(
                        color: Color(0x7326244C),
                        fontSize: 14,
                        fontFamily: 'PingFang SC',
                        fontWeight: FontWeight.w400,
                        height: 1.6,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSend(controller),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: _border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Row(
                  children: [
                    _featureChip(
                      icon: state.isDeepThinking
                          ? AppAssets.aiChatThinkActive
                          : AppAssets.aiChatThink,
                      label: '深度思考',
                      active: state.isDeepThinking,
                      onTap: controller.toggleDeepThinking,
                      activeTextColor: _purple,
                      activeBg: _purpleSoft,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 8),
                    _featureChip(
                      icon: AppAssets.aiChatSearch,
                      label: '联网搜索',
                      active: state.isWebSearching,
                      onTap: controller.toggleWebSearching,
                      activeTextColor: _green,
                      activeBg: _greenSoft,
                      iconSize: 20,
                    ),
                    const Spacer(),
                    _iconButton(
                      iconAsset: AppAssets.aiChatAttach,
                      onTap: () => _showInfo('附件上传功能开发中'),
                      background: Colors.transparent,
                      borderColor: _border,
                    ),
                    const SizedBox(width: 8),
                    _iconButton(
                      iconAsset: AppAssets.aiChatSend,
                      onTap: state.sending
                          ? null
                          : () => _handleSend(controller),
                      background: state.sending
                          ? const Color(0xFFE6E9F1)
                          : const Color(0xFFCBD2E1),
                      borderColor: Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureChip({
    required String icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    required Color activeTextColor,
    required Color activeBg,
    required double iconSize,
  }) {
    final textColor = active ? activeTextColor : _textHint;
    final bgColor = active ? activeBg : Colors.transparent;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAssetGraphic(icon, width: iconSize, height: iconSize),
              const SizedBox(width: 2),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w500,
                  height: 1.17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required String iconAsset,
    required VoidCallback? onTap,
    required Color background,
    required Color borderColor,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Center(
            child: AppAssetGraphic(iconAsset, width: 20, height: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: _mainHorizontalPadding),
      child: Text(
        '服务生成的所有内容均由人工智能模型生成，其生成内容的准确性和完整性无法保证，不代表我们的态度或观点。',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF99A1AF),
          fontSize: 10,
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w400,
          height: 1.6,
        ),
      ),
    );
  }

  String _activeTitle(AiChatState state) {
    if (state.isNewConversation) {
      return '新对话';
    }
    final active = state.sessions
        .where((item) => item.id == state.activeSessionId)
        .firstOrNull;
    if (active == null || active.title.trim().isEmpty) {
      return '对话';
    }
    return active.title.trim();
  }

  void _handlePromptTap(String prompt) {
    _inputCtrl.text = prompt;
    _inputCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputCtrl.text.length),
    );
    setState(() {});
  }

  Future<void> _handleSend(AiChatController controller) async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) {
      return;
    }
    _inputCtrl.clear();
    setState(() {});

    final error = await controller.sendMessage(text);
    if (error != null && mounted) {
      _showInfo(error);
    }
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    _showInfo('已复制');
  }

  void _reuseText(String text) {
    _inputCtrl.text = text;
    _inputCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputCtrl.text.length),
    );
    setState(() {});
  }

  Future<void> _confirmDeleteSession(
    AiChatController controller,
    AiChatSession session,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除会话'),
          content: Text('确定删除「${session.title}」吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    final error = await controller.deleteSession(session);
    if (error != null && mounted) {
      _showInfo(error);
    }
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _scheduleScrollIfNeeded(AiChatState state) {
    final latest = state.messages.isEmpty
        ? ''
        : '${state.messages.last.id}-${state.messages.last.status.name}';
    final signature =
        '${state.messages.length}-${state.waitingAssistant}-$latest';
    if (_messageSignature == signature) {
      return;
    }
    _messageSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) {
        return;
      }
      final max = _scrollCtrl.position.maxScrollExtent;
      _scrollCtrl.animateTo(
        max,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }
}

class _AiPromptQuestion {
  const _AiPromptQuestion(this.indexLabel, this.text, this.indexColor);

  final String indexLabel;
  final String text;
  final Color indexColor;
}

class _AiToolShortcut {
  const _AiToolShortcut({
    required this.title,
    required this.subtitle,
    required this.prompt,
    this.asset,
  });

  final String title;
  final String subtitle;
  final String prompt;
  final String? asset;
}

class _MessageText extends StatelessWidget {
  const _MessageText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final spans = _buildInlineSpans(text);
    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 14,
        fontFamily: 'PingFang SC',
        fontWeight: FontWeight.w400,
        height: 1.7,
      ),
    );
  }

  List<InlineSpan> _buildInlineSpans(String source) {
    final spans = <InlineSpan>[];
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final matches = RegExp(r'\*\*(.*?)\*\*').allMatches(line).toList();
      if (matches.isEmpty) {
        spans.add(TextSpan(text: line));
      } else {
        var cursor = 0;
        for (final match in matches) {
          if (match.start > cursor) {
            spans.add(TextSpan(text: line.substring(cursor, match.start)));
          }
          final boldText = match.group(1) ?? '';
          spans.add(
            TextSpan(
              text: boldText,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          );
          cursor = match.end;
        }
        if (cursor < line.length) {
          spans.add(TextSpan(text: line.substring(cursor)));
        }
      }
      if (lineIndex != lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    return spans;
  }
}
