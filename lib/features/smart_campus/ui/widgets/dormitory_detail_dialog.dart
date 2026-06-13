import 'package:flutter/material.dart';

import '../../../../core/widgets/scaled_dialog.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../data/student_dormitory_data.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kBoardBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);

Future<void> showDormitoryDetailDialog(
  BuildContext context, {
  required String title,
  required List<DormitoryDetailField> fields,
  List<Widget>? actions,
}) {
  final ui = DashboardScaleScope.of(context).ui;
  return showScaledDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (ctx) => GradientHeaderDialog(
      title: title,
      width: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ui(16)),
            decoration: BoxDecoration(
              color: _kBoardBg,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) SizedBox(height: ui(6)),
                  _DetailRow(field: fields[i]),
                ],
              ],
            ),
          ),
          if (actions != null && actions.isNotEmpty) ...[
            SizedBox(height: ui(16)),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) SizedBox(width: ui(8)),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ],
          SizedBox(height: ui(16)),
          SizedBox(
            width: double.infinity,
            height: ui(44),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kBorderSoft),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ui(12)),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                '关闭',
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.field});

  final DormitoryDetailField field;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: ui(13),
          height: 1.5,
          fontFamily: 'PingFang SC',
        ),
        children: [
          TextSpan(
            text: '${field.label}：',
            style: TextStyle(color: _kTextHint, fontWeight: AppFont.w400),
          ),
          TextSpan(
            text: field.value.isEmpty ? '—' : field.value,
            style: TextStyle(color: _kTextDark, fontWeight: AppFont.w400),
          ),
        ],
      ),
    );
  }
}
