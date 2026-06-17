import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';

import '../../shell/ui/shell_layout.dart';
import '../state/school_website_controller.dart';
import '../state/school_website_state.dart';
import 'widgets/school_website_html_view.dart';

/// 校园官网：在 Shell 主内容区内铺满渲染后端返回的完整 HTML。
class SchoolWebsitePage extends ConsumerWidget {
  const SchoolWebsitePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(schoolWebsiteControllerProvider);
    final ui = DashboardScaleScope.of(context).ui;

    return ShellPageSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(ShellLayoutSpec.panelRadius)),
        child: _Body(state: state),
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
