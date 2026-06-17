import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';

import '../state/school_website_controller.dart';
import '../state/school_website_state.dart';
import 'widgets/school_website_html_view.dart';

/// 校园官网：全屏渲染后端返回的完整 HTML（含自带 CSS / 轮播脚本）。
class SchoolWebsitePage extends ConsumerWidget {
  const SchoolWebsitePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(schoolWebsiteControllerProvider);

    return Material(
      color: const Color(0xFFF7F7FB),
      child: PopScope(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _BackButton(
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              ),
              Expanded(child: _Body(state: state)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 全局统一的圆角方形返回按钮（与资讯等页一致）。
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF3F2F3)),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.chevron_left,
          color: Color(0xFF1C274C),
          size: 20,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final SchoolWebsiteState state;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (state.errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          state.errorMessage,
          style: const TextStyle(
            color: Color(0xFF6D6B75),
            fontSize: 14,
            fontFamily: 'PingFang SC',
          ),
        ),
      );
    }
    return SchoolWebsiteHtmlView(html: state.htmlContent);
  }
}
