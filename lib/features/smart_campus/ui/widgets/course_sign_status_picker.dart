import 'package:flutter/material.dart';

import '../../../../core/widgets/scaled_dialog.dart';
import '../../data/course_sign_data.dart';
import '../../../shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kGreen = Color(0xFF0CAC40);
const Color _kGreenBg = Color(0xFFDFFCF0);
const Color _kOrange = Color(0xFFF59E0B);
const Color _kOrangeBg = Color(0xFFFFF7E6);
const Color _kRed = Color(0xFFFF323C);
const Color _kRedBg = Color(0xFFFFEEEF);
const Color _kGrayBg = Color(0xFFF0F0F0);
const Color _kBorderSoft = Color(0xFFF3F2F3);

/// 管理员签课：统一「修改签到状态」弹窗（GradientHeaderDialog 风格）。
Future<CourseSignStatus?> showCourseSignStatusPicker(
  BuildContext context, {
  required String studentName,
  required String studentNo,
  required CourseSignStatus? current,
}) {
  return showScaledDialog<CourseSignStatus>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      CourseSignStatus? selected = current ?? CourseSignStatus.present;

      return StatefulBuilder(
        builder: (ctx, setLocalState) {
          return GradientHeaderDialog(
            title: '修改签到状态',
            titleFontSize: 20,
            titleFontWeight: FontWeight.w600,
            titlePaddingTop: 36,
            width: 400,
            contentPadding: EdgeInsets.fromLTRB(ui(32), ui(24), ui(32), ui(8)),
            actionBar: AppDialogActionBar(
              confirmLabel: '确认',
              cancelLabel: '取消',
              onCancel: () => Navigator.of(dialogContext).pop(),
              onConfirm: () {
                if (selected == null) {
                  return;
                }
                Navigator.of(dialogContext).pop(selected);
              },
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  studentName,
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: ui(4)),
                Text(
                  '学号 $studentNo',
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                  ),
                ),
                SizedBox(height: ui(20)),
                Wrap(
                  spacing: ui(10),
                  runSpacing: ui(10),
                  children: CourseSignStatus.selectable.map((status) {
                    final isSelected = selected == status;
                    final (fg, bg) = _statusColors(status);
                    return InkWell(
                      onTap: () => setLocalState(() => selected = status),
                      borderRadius: BorderRadius.circular(ui(8)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: EdgeInsets.symmetric(
                          horizontal: ui(16),
                          vertical: ui(10),
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? bg : Colors.white,
                          borderRadius: BorderRadius.circular(ui(8)),
                          border: Border.all(
                            color: isSelected ? fg : _kBorderSoft,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: fg.withValues(alpha: 0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: ui(8),
                              height: ui(8),
                              decoration: BoxDecoration(
                                color: fg,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: ui(8)),
                            Text(
                              status.label,
                              style: TextStyle(
                                fontSize: ui(13),
                                color: isSelected ? fg : _kTextDark,
                                fontFamily: 'PingFang SC',
                                fontWeight: isSelected
                                    ? AppFont.w600
                                    : AppFont.w400,
                              ),
                            ),
                            if (isSelected) ...[
                              SizedBox(width: ui(6)),
                              Icon(Icons.check_rounded, size: ui(14), color: fg),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

(Color fg, Color bg) _statusColors(CourseSignStatus status) {
  switch (status) {
    case CourseSignStatus.present:
      return (_kGreen, _kGreenBg);
    case CourseSignStatus.absent:
      return (_kRed, _kRedBg);
    case CourseSignStatus.late:
      return (_kOrange, _kOrangeBg);
    case CourseSignStatus.leave:
      return (const Color(0xFF6D6B75), _kGrayBg);
  }
}

Color courseSignStatusFg(CourseSignStatus? status) {
  if (status == null) return _kTextHint;
  return _statusColors(status).$1;
}

Color courseSignStatusBg(CourseSignStatus? status) {
  if (status == null) return const Color(0xFFF5F6FA);
  return _statusColors(status).$2;
}

String courseSignStatusLabel(CourseSignStatus? status) {
  return status?.label ?? '未签到';
}
