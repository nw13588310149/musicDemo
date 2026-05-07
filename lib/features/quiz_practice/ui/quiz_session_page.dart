import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/quiz_practice_state.dart';
import '../state/quiz_session_controller.dart';
import '../state/quiz_session_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

class QuizSessionPage extends ConsumerStatefulWidget {
  const QuizSessionPage({super.key, this.openCompletion = false});

  /// 来自 /camp_over 路由：进入即弹完成对话框。
  final bool openCompletion;

  @override
  ConsumerState<QuizSessionPage> createState() => _QuizSessionPageState();
}

class _QuizSessionPageState extends ConsumerState<QuizSessionPage> {
  QuizSessionPageArgs? _args;
  bool _dialogShowing = false;

  QuizSessionPageArgs _resolveArgs(BuildContext context) {
    if (_args != null) return _args!;
    final raw = ModalRoute.of(context)?.settings.arguments;
    final parsed = QuizSessionPageArgs.fromRaw(raw);
    _args = widget.openCompletion
        ? QuizSessionPageArgs(
            practiceType: parsed.practiceType,
            practiceId: parsed.practiceId,
            startIndex: parsed.startIndex,
            allCount: parsed.allCount,
            openCompletionDialog: true,
          )
        : parsed;
    return _args!;
  }

  @override
  Widget build(BuildContext context) {
    final args = _resolveArgs(context);
    final provider = quizSessionControllerProvider(args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<QuizSessionState>(provider, (previous, next) {
      // 错误吐司
      final msg = next.errorMessage;
      if (msg.isNotEmpty && msg != previous?.errorMessage) {
        AppToast.show(context, msg);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) controller.clearError();
        });
      }

      // 完成/退出弹窗
      if (next.completionDialogVisible && !_dialogShowing) {
        _dialogShowing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCompletionDialog(context, controller);
        });
      }
    });

    // DashboardScaffold 已提供外层 padding + #EFF3FC 背景，这里只需要单层白卡。
    return ShellPageSurface(
      padding: EdgeInsets.zero,
      child: state.loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SessionHeader(
                  title: state.args.practiceType.label,
                  autoNext: state.autoNext,
                  onBack: controller.openExitDialog,
                  onAutoNextChanged: controller.setAutoNext,
                ),
                Expanded(
                  child: state.questions.isEmpty
                      ? const Center(child: Text('暂无题目'))
                      : _SessionBody(
                          state: state,
                          onSelect: controller.selectAnswer,
                          onPrevious: controller.previousQuestion,
                          onNext: controller.nextQuestion,
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _showCompletionDialog(
    BuildContext context,
    QuizSessionController controller,
  ) async {
    if (!mounted) return;
    // showDialog 走 root Overlay，不会继承 ShellScaffold 内层的 DashboardScaleScope，
    // 这里把当前页面的 scale 数据捕获后再透传给 dialog。
    final scale = DashboardScaleScope.of(context);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.20),
      barrierDismissible: false,
      builder: (dialogContext) {
        return DashboardScaleScope(
          data: scale,
          child: _CompletionDialog(
            controller: controller,
            providerArgs: _args!,
          ),
        );
      },
    );
    _dialogShowing = false;
    if (mounted) controller.closeCompletionDialog();
  }
}

// ─────────────────────────────────────────────────────────────────────
// 顶部 56px header
// ─────────────────────────────────────────────────────────────────────

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.title,
    required this.autoNext,
    required this.onBack,
    required this.onAutoNextChanged,
  });

  final String title;
  final bool autoNext;
  final VoidCallback onBack;
  final ValueChanged<bool> onAutoNextChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(56),
      padding: EdgeInsets.symmetric(horizontal: ui(20)),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F2F3), width: 1)),
      ),
      child: Row(
        children: [
          _BackButton(onTap: onBack),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(16),
                  fontWeight: AppFont.w600,
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
          ),
          Text(
            '自动刷题',
            style: TextStyle(
              color: const Color(0xFF0B081A),
              fontSize: ui(16),
              fontFamily: 'PingFang SC',
              height: 1.0,
            ),
          ),
          SizedBox(width: ui(8)),
          _AutoNextSwitch(value: autoNext, onChanged: onAutoNextChanged),
        ],
      ),
    );
  }
}

class _AutoNextSwitch extends StatelessWidget {
  const _AutoNextSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final trackWidth = ui(44);
    final trackHeight = ui(26);
    final thumbSize = ui(20);
    final inset = ui(3);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: trackWidth,
        height: trackHeight,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: trackWidth,
              height: trackHeight,
              decoration: BoxDecoration(
                color: value
                    ? const Color(0xFFA773FF)
                    : const Color(0xFFE6E9F1),
                borderRadius: BorderRadius.circular(ui(13.5)),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              left: value ? trackWidth - thumbSize - inset : inset,
              top: inset,
              child: Container(
                width: thumbSize,
                height: thumbSize,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(32),
        height: ui(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.chevron_left,
          color: const Color(0xFF1C274C),
          size: ui(20),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 主体：题型 chip / 题干 / 选项 / 解析 / 上下一题按钮
// ─────────────────────────────────────────────────────────────────────

class _SessionBody extends StatelessWidget {
  const _SessionBody({
    required this.state,
    required this.onSelect,
    required this.onPrevious,
    required this.onNext,
  });

  final QuizSessionState state;
  final ValueChanged<int> onSelect;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final question = state.currentQuestion;
    if (question == null) {
      return const Center(child: Text('暂无题目'));
    }

    final questionHtmlStripped = _stripHtml(question.questionHtml);
    final parseHtmlStripped = _stripHtml(question.parseHtml);

    // 内容区做成可滚动；底部"上一题/下一题"按钮固定不动。这样题干/
    // 选项/解析里嵌入的乐谱图片再高也不会撑爆页面。
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(20), ui(12), ui(20), ui(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TypeChip(),
                  SizedBox(height: ui(20)),
                  // 题干：左侧"第 N 题"前缀 + 富文本（可能含 <img>、
                  // <sup>/<sub> 等）。无富文本结构时退回纯 Text，避免
                  // HtmlWidget 在空字符串下渲染一个空段落。
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '第${state.currentIndex + 1}题  ',
                        style: TextStyle(
                          color: const Color(0xFF0B081A),
                          fontSize: ui(18),
                          fontWeight: AppFont.w500,
                          fontFamily: 'PingFang SC',
                          height: 1.5,
                        ),
                      ),
                      Expanded(
                        child: _QuizHtml(
                          html: question.questionHtml,
                          fallbackText: questionHtmlStripped,
                          textStyle: TextStyle(
                            color: const Color(0xFF0B081A),
                            fontSize: ui(18),
                            fontWeight: AppFont.w500,
                            fontFamily: 'PingFang SC',
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ui(24)),
                  _OptionsGrid(question: question, onSelect: onSelect),
                  if (question.answered) ...[
                    SizedBox(height: ui(28)),
                    const Divider(height: 1, color: Color(0xFFF3F2F3)),
                    SizedBox(height: ui(20)),
                    _AnswerRow(question: question),
                    SizedBox(height: ui(24)),
                    Text(
                      '题目解析',
                      style: TextStyle(
                        color: const Color(0xFF6D6B75),
                        fontSize: ui(18),
                        fontWeight: AppFont.w600,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                    SizedBox(height: ui(10)),
                    if (parseHtmlStripped.isEmpty)
                      Text(
                        '暂无解析',
                        style: TextStyle(
                          color: const Color(0xFFB6B5BB),
                          fontSize: ui(14),
                          fontFamily: 'PingFang SC',
                          height: 1.6,
                        ),
                      )
                    else
                      _QuizHtml(
                        html: question.parseHtml,
                        fallbackText: parseHtmlStripped,
                        textStyle: TextStyle(
                          color: const Color(0xFFB6B5BB),
                          fontSize: ui(14),
                          fontFamily: 'PingFang SC',
                          height: 1.6,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: ui(20)),
          _NavButtons(onPrevious: onPrevious, onNext: onNext),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(3)),
        decoration: BoxDecoration(
          color: const Color(0xFFEAE5FF),
          borderRadius: BorderRadius.circular(ui(4)),
        ),
        child: Text.rich(
          TextSpan(
            style: TextStyle(
              color: const Color(0xFF0B081A),
              fontSize: ui(12),
              fontFamily: 'PingFang SC',
              height: 1.0,
            ),
            children: const [
              TextSpan(text: '当前题型：'),
              TextSpan(text: '单选题'),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionsGrid extends StatelessWidget {
  const _OptionsGrid({required this.question, required this.onSelect});

  final QuizQuestion question;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final letters = ['A', 'B', 'C', 'D'];

    Widget option(int index) {
      final letter = letters[index];
      final rawHtml = index < question.options.length
          ? question.options[index]
          : '';
      final stripped = _stripHtml(rawHtml);
      final answered = question.answered;
      final isCorrectOption = index == question.correctAnswer;
      final isUserPick = index == question.userAnswer;
      final showCorrect = answered && isCorrectOption;
      final showWrong = answered && isUserPick && !isCorrectOption;

      Color bg = const Color(0xFFF5F6FA);
      Color textColor = const Color(0xFF0B081A);
      Widget? trailing;
      if (showCorrect) {
        bg = const Color(0xFFE8F5EC);
        textColor = const Color(0xFF1AAB5B);
        trailing = Icon(Icons.check_rounded, color: textColor, size: ui(20));
      } else if (showWrong) {
        bg = const Color(0xFFFCEBEB);
        textColor = const Color(0xFFE0494B);
        trailing = Icon(Icons.close_rounded, color: textColor, size: ui(20));
      }

      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ui(8)),
          onTap: answered ? null : () => onSelect(index),
          child: Container(
            // 移除固定 44 高度，改成最低 44；选项里出现图片时让卡片
            // 自适应内容（垂直居中）。
            constraints: BoxConstraints(minHeight: ui(44)),
            padding: EdgeInsets.symmetric(
              horizontal: ui(20),
              vertical: ui(8),
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: ui(22),
                  child: Text(
                    '$letter.',
                    style: TextStyle(
                      color: textColor,
                      fontSize: ui(16),
                      fontWeight: AppFont.w600,
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                ),
                SizedBox(width: ui(9)),
                Expanded(
                  child: _QuizHtml(
                    html: rawHtml,
                    fallbackText: stripped,
                    textStyle: TextStyle(
                      color: textColor,
                      fontSize: ui(16),
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                ),
                if (trailing != null) ...[SizedBox(width: ui(8)), trailing],
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // crossAxisAlignment.stretch 让每行的两个选项高度对齐——
        // 如果一边是文字、一边是图片，两个卡片仍然一样高。
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: option(0)),
              SizedBox(width: ui(20)),
              Expanded(child: option(1)),
            ],
          ),
        ),
        SizedBox(height: ui(20)),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: option(2)),
              SizedBox(width: ui(20)),
              Expanded(child: option(3)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.question});

  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final letters = ['A', 'B', 'C', 'D'];
    final correctLetter = letters[question.correctAnswer.clamp(0, 3)];
    final pickIndex = question.userAnswer ?? -1;
    final pickLetter = (pickIndex >= 0 && pickIndex < 4)
        ? letters[pickIndex]
        : '-';
    final pickColor = question.status == 1
        ? const Color(0xFF1AAB5B)
        : const Color(0xFFE0494B);

    final labelStyle = TextStyle(
      color: const Color(0xFF0B081A),
      fontSize: ui(18),
      fontWeight: AppFont.w500,
      fontFamily: 'PingFang SC',
    );
    final valueStyle = TextStyle(
      fontSize: ui(18),
      fontWeight: AppFont.w600,
      fontFamily: 'PingFang SC',
    );

    return Row(
      children: [
        Text('正确答案：', style: labelStyle),
        Text(
          correctLetter,
          style: valueStyle.copyWith(color: const Color(0xFF1AAB5B)),
        ),
        SizedBox(width: ui(36)),
        Text('已选答案：', style: labelStyle),
        Text(pickLetter, style: valueStyle.copyWith(color: pickColor)),
      ],
    );
  }
}

class _NavButtons extends StatelessWidget {
  const _NavButtons({required this.onPrevious, required this.onNext});

  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GhostButton(label: '上一题', onTap: onPrevious),
          SizedBox(width: ui(16)),
          _PrimaryButton(label: '下一题', onTap: onNext),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(182),
        height: ui(45),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0x59B5B5B5),
              blurRadius: ui(20),
              offset: Offset(0, ui(16)),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: const Color(0xFF0B081A),
            fontSize: ui(16),
            fontFamily: 'PingFang SC',
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(182),
        height: ui(45),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
          boxShadow: [
            BoxShadow(
              color: const Color(0x59AD80FF),
              blurRadius: ui(20),
              offset: Offset(0, ui(16)),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: ui(16),
            fontFamily: 'PingFang SC',
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 完成 / 退出弹窗
// ─────────────────────────────────────────────────────────────────────

class _CompletionDialog extends ConsumerWidget {
  const _CompletionDialog({
    required this.controller,
    required this.providerArgs,
  });

  final QuizSessionController controller;
  final QuizSessionPageArgs providerArgs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quizSessionControllerProvider(providerArgs));
    final ui = DashboardScaleScope.of(context).ui;

    final summary = _summaryOf(state, providerArgs.practiceType);
    final notDone = summary?.notDoneCount ?? state.notDoneCount;
    final done = summary?.doneCount ?? state.answeredCount;
    final wrong = summary?.errorCount ?? state.errorCount;
    final accuracyPercent = summary?.accuracyPercent ?? state.accuracyPercent;

    final isExam = providerArgs.practiceType == QuizPracticeType.exam;
    final recommendedLabel = isExam ? '随机练习' : '考前密卷';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: ui(428),
        padding: EdgeInsets.fromLTRB(ui(19), ui(28), ui(19), ui(28)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatGrid(
              notDone: notDone,
              done: done,
              wrong: wrong,
              accuracyPercent: accuracyPercent,
            ),
            SizedBox(height: ui(20)),
            _RecommendedSwitchCard(
              label: recommendedLabel,
              onTap: () async {
                final next = await controller.switchToRecommended();
                if (next == null) {
                  if (context.mounted) {
                    AppToast.show(context, '暂无可切换的练习');
                  }
                  return;
                }
                if (!context.mounted) return;
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(
                  context,
                  RoutePaths.campAnswer,
                  arguments: next,
                );
              },
            ),
            SizedBox(height: ui(20)),
            Row(
              children: [
                Expanded(
                  child: _GhostButton(
                    label: '退出',
                    onTap: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.pop(true);
                    },
                  ),
                ),
                SizedBox(width: ui(16)),
                Expanded(
                  child: _PrimaryButton(
                    label: '继续学习',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  QuizPracticeSummary? _summaryOf(
    QuizSessionState state,
    QuizPracticeType type,
  ) {
    for (final s in state.summaryAfter) {
      if (s.type == type) return s;
    }
    return null;
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.notDone,
    required this.done,
    required this.wrong,
    required this.accuracyPercent,
  });

  final int notDone;
  final int done;
  final int wrong;
  final int accuracyPercent;

  @override
  Widget build(BuildContext context) {
    // 设计宽度 = 弹窗宽 428 - 左右各 19 padding = 390
    // 4 个统计格 90×86 + 3 个间距 10 = 360 + 30 = 390，正好填满。
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StatCell(value: '$notDone', label: '未做题'),
        _StatCell(value: '$done', label: '已做题'),
        _StatCell(value: '$wrong', label: '错题'),
        _StatCell(value: '$accuracyPercent%', label: '正确率'),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(90),
      height: ui(86),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: const Color(0xFF0B081A),
              fontSize: ui(24),
              fontWeight: AppFont.w500,
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(8)),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF6D6B75),
              fontSize: ui(12),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedSwitchCard extends StatelessWidget {
  const _RecommendedSwitchCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // Stack 让"推荐 badge + 下指小三角"作为浮层"挂"在卡片右上方，
    // badge 顶部超出卡片 5px，三角紧贴 badge 底部指向卡片，
    // 形成消息气泡的视觉。clipBehavior.none 允许超出。
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 卡片本体
          Container(
            height: ui(66),
            padding: EdgeInsets.symmetric(horizontal: ui(20)),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF5F6FA), Colors.white],
              ),
              borderRadius: BorderRadius.circular(ui(12)),
              border: Border.all(
                color: const Color(0xFFF3F2F3),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(16),
                fontFamily: 'PingFang SC',
                height: 1.0,
              ),
            ),
          ),
          // 浮层"推荐"气泡：定位参考设计稿
          //   弹窗 428、内容宽 390（左右 19 padding）
          //   badge 全局 left=246, top=90；卡片 left=19, top=95
          //   ⇒ badge 在卡片内 right ≈ 390-(246-19)-38 = 125, top = -5
          Positioned(
            right: ui(125),
            top: ui(-5),
            child: Image.asset(
              AppAssets.quizRecommendBubble,
              width: ui(38),
              height: ui(30),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 工具
// ─────────────────────────────────────────────────────────────────────

String _stripHtml(String html) {
  if (html.isEmpty) return '';
  return html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();
}

// ─────────────────────────────────────────────────────────────────────
// 富文本渲染：题干 / 选项 / 解析共用一套
// ─────────────────────────────────────────────────────────────────────

/// 题干、选项、解析的富文本渲染入口。
///
/// 后端这些字段都是富文本编辑器吐出来的 HTML，常见标签包括
/// `<p>`、`<br>`、`<strong>`、`<em>`、`<sub>`、`<sup>`、`<img>` 等。
/// 项目里已经引入 `flutter_widget_from_html_core`，但它的 _core_ 包
/// **不会**自动渲染 `<img>`，所以这里：
/// - 走 [HtmlWidget]，文本/段落/上下标交给它默认处理；
/// - 用 `customWidgetBuilder` 拦截 `<img>`，自己用 [Image.network]
///   渲染成响应式图片，按容器最大宽度自适应缩放，保持比例；
/// - 富文本拆出来全是空白时，回退到纯文本（避免渲染一个空段落）。
class _QuizHtml extends StatelessWidget {
  const _QuizHtml({
    required this.html,
    required this.fallbackText,
    required this.textStyle,
  });

  /// 后端原始 HTML 字符串。
  final String html;

  /// 用 [_stripHtml] 抠出来的纯文本，仅作 fallback / 空判定用。
  final String fallbackText;

  /// 普通文本样式（颜色 / 字号 / 字体）。
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final trimmed = html.trim();
    // HTML 整体为空 / 只有 `<p></p>` 之类的空段落 → 退回纯文本。
    if (trimmed.isEmpty || fallbackText.isEmpty) {
      return Text(fallbackText, style: textStyle);
    }
    return HtmlWidget(
      trimmed,
      textStyle: textStyle,
      // 关闭默认的 ext renderer，直接走 `customWidgetBuilder` 来
      // 接管 <img>，避免 _core 包对 img 的占位/默认行为。
      customWidgetBuilder: (element) {
        if (element.localName != 'img') {
          return null;
        }
        final src = element.attributes['src']?.trim() ?? '';
        if (src.isEmpty) {
          return null;
        }
        final designW = double.tryParse(element.attributes['width'] ?? '');
        final designH = double.tryParse(element.attributes['height'] ?? '');
        return _ResponsiveNetworkImage(
          url: src,
          designWidth: designW,
          designHeight: designH,
        );
      },
    );
  }
}

/// 把后端给的 `<img src=".." width="W" height="H" />` 渲染成
/// 自适应宽度的网络图片：
/// - 设计尺寸 ≤ 容器最大宽度：按设计尺寸渲染（保留 1.0 视觉）；
/// - 设计尺寸 > 容器最大宽度：按容器宽度等比缩放，避免越界；
/// - 加载失败时退化成一个灰色 broken image 占位图，不会让整张题目
///   崩掉。
class _ResponsiveNetworkImage extends StatelessWidget {
  const _ResponsiveNetworkImage({
    required this.url,
    this.designWidth,
    this.designHeight,
  });

  final String url;
  final double? designWidth;
  final double? designHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        double width = designWidth ?? maxW;
        double? height = designHeight;
        if (width > maxW) {
          if (designWidth != null &&
              designHeight != null &&
              designWidth! > 0) {
            height = designHeight! * (maxW / designWidth!);
          } else {
            height = null;
          }
          width = maxW;
        }

        return Image.network(
          url,
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            width: width,
            height: height ?? 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.broken_image_rounded,
              color: Color(0xFFC9C6D8),
            ),
          ),
        );
      },
    );
  }
}
