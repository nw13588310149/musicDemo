import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/theory_controller.dart';
import '../state/theory_state.dart';
import 'widgets/theory_pdf_view.dart';

import '../../../core/widgets/app_text.dart';
class TheoryPage extends ConsumerStatefulWidget {
  const TheoryPage({super.key});

  @override
  ConsumerState<TheoryPage> createState() => _TheoryPageState();
}

class _TheoryPageState extends ConsumerState<TheoryPage> {
  bool _shareDialogShowing = false;
  bool _imageGalleryOpen = false;

  @override
  Widget build(BuildContext context) {
    final args = TheoryPageArgs.fromRaw(
      ModalRoute.of(context)?.settings.arguments,
    );
    final state = ref.watch(theoryControllerProvider(args));
    final controller = ref.read(theoryControllerProvider(args).notifier);
    final ui = DashboardScaleScope.of(context).ui;

    ref.listen<TheoryState>(theoryControllerProvider(args), (previous, next) {
      final message = next.errorMessage;
      if (message.isNotEmpty && message != previous?.errorMessage) {
        AppToast.show(context, message);
        controller.clearError();
      }

      if (next.shareDialogVisible && !_shareDialogShowing) {
        _shareDialogShowing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showShareDialog(context, args);
        });
      }
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
                  onShare: controller.openShareDialog,
                  onOpenAssignment: () {
                    final detail = state.detail;
                    if (detail == null || !detail.hasAssignmentImages) {
                      AppToast.show(context, '暂无课程作业图片');
                      return;
                    }
                    _openImageGallery(
                      images: detail.assignmentImages,
                      heroTagPrefix: 'theory_assignment',
                    );
                  },
                  onOpenAnswer: () {
                    final detail = state.detail;
                    if (detail == null || !detail.hasAnswerImages) {
                      AppToast.show(context, '暂无答案图片');
                      return;
                    }
                    controller.markAnswerOpened();
                    _openImageGallery(
                      images: detail.answerImages,
                      heroTagPrefix: 'theory_answer',
                    );
                  },
                ),
                SizedBox(height: ui(12)),
                Expanded(
                  child: _TheoryContent(
                    state: state,
                    pdfInteractive: !_imageGalleryOpen,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _openImageGallery({
    required List<String> images,
    required String heroTagPrefix,
  }) async {
    setState(() => _imageGalleryOpen = true);
    try {
      await showImageGallery(
        context,
        images: images,
        heroTagPrefix: heroTagPrefix,
      );
    } finally {
      if (mounted) {
        setState(() => _imageGalleryOpen = false);
      }
    }
  }

  Future<void> _showShareDialog(
    BuildContext context,
    TheoryPageArgs args,
  ) async {
    if (!mounted) {
      return;
    }
    final scale = DashboardScaleScope.of(context);
    await showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.20),
      barrierDismissible: true,
      barrierLabel: '关闭分享',
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return DashboardScaleScope(
          data: scale,
          child: _ShareDrawer(args: args),
        );
      },
      transitionBuilder: (context, animation, secondary, child) {
        final offset = Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return SlideTransition(position: offset, child: child);
      },
    );
    _shareDialogShowing = false;
    if (mounted) {
      ref.read(theoryControllerProvider(args).notifier).closeShareDialog();
    }
  }
}

class _ShareDrawer extends ConsumerWidget {
  const _ShareDrawer({required this.args});

  final TheoryPageArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(theoryControllerProvider(args));
    final controller = ref.read(theoryControllerProvider(args).notifier);
    final ui = DashboardScaleScope.of(context).ui;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white,
        child: SizedBox(
          width: ui(600),
          height: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ui(20), vertical: ui(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _DrawerTitle(title: '分享课件'),
                SizedBox(height: ui(20)),
                const Divider(height: 1, color: Color(0xFFF3F2F3)),
                SizedBox(height: ui(24)),
                _ShareTargetCard(detail: state.detail),
                SizedBox(height: ui(28)),
                AppText(
                  '您的班级群',
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(16),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: ui(16)),
                Expanded(
                  child: state.classLoading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : state.classList.isEmpty
                      ? const _ShareDrawerEmpty()
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: state.classList.length,
                          separatorBuilder: (_, _) => SizedBox(height: ui(12)),
                          itemBuilder: (context, index) {
                            final cls = state.classList[index];
                            return _ClassRow(
                              cls: cls,
                              onTap: () => controller.toggleClass(cls.id),
                            );
                          },
                        ),
                ),
                SizedBox(height: ui(12)),
                _SendButton(
                  loading: state.sending,
                  onTap: () async {
                    final success = await controller.sendShare();
                    if (!context.mounted) {
                      return;
                    }
                    if (success) {
                      Navigator.of(context).maybePop();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerTitle extends StatelessWidget {
  const _DrawerTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Container(
          width: ui(3.25),
          height: ui(14.85),
          decoration: BoxDecoration(
            color: const Color(0xFF8741FF),
            borderRadius: BorderRadius.circular(ui(6)),
          ),
        ),
        SizedBox(width: ui(4)),
        AppText(
          title,
          style: TextStyle(
            color: const Color(0xFF0B081A),
            fontSize: ui(16),
            fontFamily: 'PingFang SC',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ShareTargetCard extends StatelessWidget {
  const _ShareTargetCard({required this.detail});

  final TheoryDetail? detail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(106),
      padding: EdgeInsets.symmetric(horizontal: ui(24), vertical: ui(20)),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4FF),
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppText(
                  '您将分享的课件',
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(14),
                    fontFamily: 'PingFang SC',
                  ),
                ),
                SizedBox(height: ui(10)),
                AppText(
                  detail?.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(16),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(16)),
          Container(
            width: ui(75.76),
            height: ui(55.27),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF1E8FD), Color(0xFFDDC4FF)],
              ),
              borderRadius: BorderRadius.circular(ui(6.82)),
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              color: Color(0xFFA773FF),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.cls, required this.onTap});

  final TheoryShareClass cls;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final checked = cls.checked;
    return Material(
      color: const Color(0xFFF5F6FA),
      borderRadius: BorderRadius.circular(ui(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(ui(16)),
        onTap: onTap,
        child: Container(
          height: ui(80),
          padding: EdgeInsets.symmetric(horizontal: ui(16)),
          child: Row(
            children: [
              Container(
                width: ui(24),
                height: ui(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: checked
                        ? const Color(0xFF8741FF)
                        : const Color(0xFFCECED1),
                    width: 1,
                  ),
                ),
                child: checked
                    ? Icon(
                        Icons.check_rounded,
                        size: ui(16),
                        color: const Color(0xFF8741FF),
                      )
                    : null,
              ),
              SizedBox(width: ui(16)),
              Expanded(
                child: AppText(
                  cls.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: ui(16),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w600,
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

class _ShareDrawerEmpty extends StatelessWidget {
  const _ShareDrawerEmpty();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: AppText(
        '暂无班级群',
        style: TextStyle(
          color: const Color(0xFFB6B5BB),
          fontSize: ui(14),
          fontFamily: 'PingFang SC',
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: ui(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: loading
            ? SizedBox(
                width: ui(20),
                height: ui(20),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : AppText(
                '发送',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ui(14),
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w500,
                  height: 24 / 14,
                ),
              ),
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
    final showAssignmentBtn =
        !state.args.answerEndMode && (detail?.showsAssignmentButton ?? true);

    return Row(
      children: <Widget>[
        _GlassIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
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
              child: AppText(
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
  const _TheoryContent({required this.state, required this.pdfInteractive});

  final TheoryState state;
  final bool pdfInteractive;

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
          ? TheoryPdfView(
              url: detail.pdfUrl,
              authToken: token,
              interactive: pdfInteractive,
            )
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
          AppText(
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
    final bg = highlighted ? const Color(0xFFEDE3FF) : const Color(0xFFF4F4FF);
    final fg = highlighted ? const Color(0xFF8741FF) : const Color(0xFF1C274C);
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
            AppText(
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
