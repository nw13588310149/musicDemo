import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../video_tutorial/state/video_tutorial_state.dart';
import '../../video_tutorial/ui/video_tutorial_page.dart';
import '../state/school_page_controller.dart';

/// 校园视频页 — 复用公开视频中心 UI，接口走校区端点。
class SchoolVideoTutorialPage extends ConsumerWidget {
  const SchoolVideoTutorialPage({super.key});

  int _resolveSchoolId(BuildContext context, WidgetRef ref) {
    final fromPage = ref.watch(schoolPageControllerProvider).schoolId;
    if (fromPage > 0) {
      return fromPage;
    }

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is Map) {
      final school = routeArgs['school'];
      if (school is int && school > 0) {
        return school;
      }
      if (school is num && school.toInt() > 0) {
        return school.toInt();
      }
      final parsed = int.tryParse(school?.toString() ?? '');
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    return int.tryParse(ref.watch(appStorageProvider).schoolId) ?? 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = _resolveSchoolId(context, ref);
    return VideoTutorialV2Page(
      args: VideoTutorialPageArgs(schoolMode: true, schoolId: schoolId),
    );
  }
}
