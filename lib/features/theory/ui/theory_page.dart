import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/theory_controller.dart';
import '../state/theory_state.dart';
import 'widgets/theory_pdf_view.dart';

class TheoryPage extends ConsumerWidget {
  const TheoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = TheoryPageArgs.fromRaw(
      ModalRoute.of(context)?.settings.arguments,
    );
    final state = ref.watch(theoryControllerProvider(args));
    final controller = ref.read(theoryControllerProvider(args).notifier);
    final ui = DashboardScaleScope.of(context).ui;

    ref.listen<TheoryState>(theoryControllerProvider(args), (previous, next) {
      final message = next.errorMessage;
      if (message.isEmpty || message == previous?.errorMessage) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      controller.clearError();
    });

    return ShellPageSurface(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
      child: state.loading && !state.hasDetail
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _TheoryHeader(
                  state: state,
                  onBack: () => Navigator.of(context).maybePop(),
                  onShare: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('分享功能稍后补齐')),
                    );
                  },
                  onOpenAssignment: () {
                    final detail = state.detail;
                    if (detail == null || !detail.hasAssignmentImages) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('暂无课程作业图片')),
                      );
                      return;
                    }
                    showImageGallery(
                      context,
                      images: detail.assignmentImages,
                      heroTagPrefix: 'theory_assignment',
                    );
                  },
                  onOpenAnswer: () {
                    final detail = state.detail;
                    if (detail == null || !detail.hasAnswerImages) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('暂无答案图片')),
                      );
                      return;
                    }
                    controller.markAnswerOpened();
                    showImageGallery(
                      context,
                      images: detail.answerImages,
                      heroTagPrefix: 'theory_answer',
                    );
                  },
                ),
                SizedBox(height: ui(12)),
                Expanded(child: _TheoryContent(state: state)),
              ],
            ),
    );
  }
}

class _TheoryHeader extends StatelessWidget {
  const _TheoryHeader({
    required this.state,
    required this.onBack,
    required this.onShare,
    required this.onOpenAssignment,
    required this.onOpenAnswer,
  });

  final TheoryState state;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onOpenAssignment;
  final VoidCallback onOpenAnswer;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final detail = state.detail;
    final showAssignmentBtn = detail?.showsAssignmentButton ?? true;

    return Row(
      children: <Widget>[
        _GlassIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: onBack,
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: ui(280)),
              height: ui(28),
              padding: EdgeInsets.symmetric(horizontal: ui(18)),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4FF),
                borderRadius: BorderRadius.circular(ui(999)),
              ),
              alignment: Alignment.center,
              child: Text(
                detail?.title ?? '乐理详情',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(13),
                  fontFamily: 'Harmony',
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: ui(8)),
        _SecondaryChipButton(
          icon: Icons.ios_share_outlined,
          label: '分享',
          onTap: onShare,
        ),
        if (showAssignmentBtn) ...<Widget>[
          SizedBox(width: ui(8)),
          _SecondaryChipButton(
            icon: Icons.assignment_outlined,
            label: '课程作业',
            onTap: onOpenAssignment,
          ),
        ],
        SizedBox(width: ui(8)),
        _SecondaryChipButton(
          icon: Icons.menu_book_outlined,
          label: '查看答案',
          onTap: onOpenAnswer,
          highlighted: true,
        ),
      ],
    );
  }
}

class _TheoryContent extends ConsumerWidget {
  const _TheoryContent({required this.state});

  final TheoryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = DashboardScaleScope.of(context).ui;
    final detail = state.detail;
    final token = ref.watch(appStorageProvider).token;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius: BorderRadius.circular(ui(14)),
        border: Border.all(color: const Color(0xFFF3F2F3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: detail == null
          ? const _TheoryEmptyState(message: '加载中…')
          : detail.hasPdf
              ? TheoryPdfView(url: detail.pdfUrl, authToken: token)
              : detail.hasHtmlContent
                  ? _TheoryHtmlView(htmlText: detail.htmlContent)
                  : const _TheoryEmptyState(message: '暂无课程内容'),
    );
  }
}

class _TheoryHtmlView extends StatelessWidget {
  const _TheoryHtmlView({required this.htmlText});

  final String htmlText;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final clean = htmlText
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return Padding(
      padding: EdgeInsets.all(ui(18)),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: SelectableText(
          clean,
          style: TextStyle(
            color: const Color(0xFF0B081A),
            fontSize: ui(14),
            height: 1.7,
            fontFamily: 'PingFang SC',
          ),
        ),
      ),
    );
  }
}

class _TheoryEmptyState extends StatelessWidget {
  const _TheoryEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.menu_book_outlined,
            color: const Color(0xFFC9C6D8),
            size: ui(40),
          ),
          SizedBox(height: ui(12)),
          Text(
            message,
            style: TextStyle(
              color: const Color(0xFFC9C6D8),
              fontSize: ui(13),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
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
          border: Border.all(color: const Color(0xFFF3F2F3)),
        ),
        child: Icon(icon, size: ui(16), color: const Color(0xFF1C274C)),
      ),
    );
  }
}

class _SecondaryChipButton extends StatelessWidget {
  const _SecondaryChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bg = highlighted
        ? const Color(0xFFEDE3FF)
        : const Color(0xFFF4F4FF);
    final fg = highlighted
        ? const Color(0xFF8741FF)
        : const Color(0xFF1C274C);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: ui(28),
        padding: EdgeInsets.symmetric(horizontal: ui(10)),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: ui(16), color: fg),
            SizedBox(width: ui(4)),
            Text(
              label,
              style: TextStyle(
                color: highlighted
                    ? const Color(0xFF8741FF)
                    : const Color(0xFF0B081A),
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

