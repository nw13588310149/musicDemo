import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../../features/shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 课程列表为空时的统一占位：163×163 插图 + 居中文案。
class CourseEmptyPlaceholder extends StatelessWidget {
  const CourseEmptyPlaceholder({super.key, this.message = '暂无课程'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            AppAssets.emptyCoursePlaceholder,
            width: ui(163),
            height: ui(163),
            fit: BoxFit.contain,
          ),
          SizedBox(height: ui(4)),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PingFang SC',
              fontSize: ui(16),
              fontWeight: AppFont.w400,
              color: const Color(0xFF0B081A),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
