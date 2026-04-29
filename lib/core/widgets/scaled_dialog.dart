import 'package:flutter/material.dart';

import '../../features/shell/ui/shell_layout.dart';

/// `showDialog` 的封装：在打开对话框前先从 [context] 中读取
/// [DashboardScaleScope]，再把同一份 [DashboardScaleData] 重新注入到弹窗子树。
///
/// 这样从 Dashboard 内层页面里直接 `showDialog` 时，弹窗 builder 收到的
/// `dialogContext` 即便走的是 root Overlay，也能让 `DashboardScaleScope.of(...)`
/// 正常工作，避免出现 `scope != null` 的断言异常。
Future<T?> showScaledDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  bool useSafeArea = true,
  RouteSettings? routeSettings,
}) {
  final scale = DashboardScaleScope.of(context);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black54,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    useSafeArea: useSafeArea,
    routeSettings: routeSettings,
    builder: (dialogContext) {
      return DashboardScaleScope(
        data: scale,
        child: Builder(builder: builder),
      );
    },
  );
}

/// 通用底部按钮组（取消 / 确认），样式与上传课件弹窗一致：
/// - 取消：白底 + 浅边框 + 阴影
/// - 确认：紫色渐变 + 阴影
class AppDialogActionBar extends StatelessWidget {
  const AppDialogActionBar({
    required this.onCancel,
    required this.onConfirm,
    this.cancelLabel = '取消',
    this.confirmLabel = '确认',
    this.confirmEnabled = true,
    super.key,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String cancelLabel;
  final String confirmLabel;
  final bool confirmEnabled;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _AppDialogButton(
            label: cancelLabel,
            onTap: onCancel,
            isPrimary: false,
          ),
        ),
        SizedBox(width: ui(16)),
        Expanded(
          child: _AppDialogButton(
            label: confirmLabel,
            onTap: confirmEnabled ? onConfirm : null,
            isPrimary: true,
          ),
        ),
      ],
    );
  }
}

class _AppDialogButton extends StatelessWidget {
  const _AppDialogButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(45),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
                )
              : null,
          color: isPrimary ? null : Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: isPrimary
              ? null
              : Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? const Color(0x59AD80FF)
                  : const Color(0x59B5B5B5),
              blurRadius: ui(20),
              offset: Offset(0, ui(16)),
            ),
          ],
        ),
        child: Opacity(
          opacity: disabled ? 0.55 : 1,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : const Color(0xFF0B081A),
                fontSize: ui(16),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w400,
                height: 12 / 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 弹出一个**单行文本输入**对话框，返回用户输入（trim 后非空）；点击取消返回 null。
///
/// 样式与上传课件弹窗保持一致：
/// - 圆角 24，白底（无渐变 / 无顶部装饰图）
/// - 输入框：白底，1px `#F3F2F3` 边框，圆角 12
/// - 底部按钮使用 [AppDialogActionBar]
Future<String?> showTextInputDialog({
  required BuildContext context,
  required String title,
  String hintText = '',
  String initialValue = '',
  String confirmLabel = '确认',
  String cancelLabel = '取消',
  int? maxLength,
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showScaledDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: ui(32),
          vertical: ui(24),
        ),
        child: Container(
          width: ui(420),
          padding: EdgeInsets.fromLTRB(ui(24), ui(28), ui(24), ui(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: ui(18),
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: ui(20)),
              SizedBox(
                height: ui(45),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: maxLength,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: const Color(0xFF0B081A),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    counterText: '',
                    hintStyle: TextStyle(
                      fontSize: ui(14),
                      color: const Color(0xFFB6B5BB),
                      fontFamily: 'PingFang SC',
                      fontWeight: FontWeight.w400,
                      height: 12 / 14,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: ui(13),
                      vertical: ui(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ui(12)),
                      borderSide: BorderSide(
                        color: const Color(0xFFF3F2F3),
                        width: ui(1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ui(12)),
                      borderSide: BorderSide(
                        color: const Color(0xFFD9C7FF),
                        width: ui(1),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: ui(24)),
              AppDialogActionBar(
                cancelLabel: cancelLabel,
                confirmLabel: confirmLabel,
                onCancel: () => Navigator.of(dialogContext).pop(),
                onConfirm: () => Navigator.of(dialogContext).pop(
                  controller.text.trim(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  controller.dispose();
  return result;
}

/// 弹出一个二次确认对话框（带说明文本），返回 `true` 表示用户点击确认。
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmLabel = '确认',
  String cancelLabel = '取消',
}) async {
  final result = await showScaledDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: ui(32),
          vertical: ui(24),
        ),
        child: Container(
          width: ui(420),
          padding: EdgeInsets.fromLTRB(ui(24), ui(28), ui(24), ui(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: ui(18),
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: ui(12)),
              Text(
                content,
                style: TextStyle(
                  fontSize: ui(14),
                  height: 1.6,
                  color: const Color(0xFF788698),
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: ui(24)),
              AppDialogActionBar(
                cancelLabel: cancelLabel,
                confirmLabel: confirmLabel,
                onCancel: () => Navigator.of(dialogContext).pop(false),
                onConfirm: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
