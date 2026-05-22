import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/router/app_navigator.dart';
import '../../features/shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kPickerPrimary = Color(0xFF8741FF);
const Color _kPickerTitle = Color(0xFF0B081A);
const Color _kPickerMuted = Color(0xFF6D6B75);
const Color _kToolbarBorder = Color(0xFFE6E8EB);

/// iOS 风格底部滚轮选择器（[CupertinoPicker] + 取消/确定工具栏）。
///
/// 仿 iOS 系统「地区」等 Picker：自底部滑出，中间滚轮切换，点确定返回选中项。
/// 通过根 Navigator 的 [showGeneralDialog] 铺满整屏宽度（含侧栏区域），
/// 避免 [showModalBottomSheet] 在宽屏/横屏 dashboard 下只覆盖内容区的问题。
Future<String?> showAppWheelPicker({
  required BuildContext context,
  required String title,
  required List<String> items,
  String? selected,
  String cancelLabel = '取消',
  String confirmLabel = '确定',
}) async {
  if (items.isEmpty) return null;

  final scale = DashboardScaleScope.of(context);
  final initialIndex = _indexForSelected(items, selected);
  final rootContext = rootNavigatorKey.currentContext ?? context;

  return showGeneralDialog<String>(
    context: rootContext,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(rootContext).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return DashboardScaleScope(
        data: scale,
        child: _AppWheelPickerOverlay(
          animation: animation,
          title: title,
          items: items,
          initialIndex: initialIndex,
          cancelLabel: cancelLabel,
          confirmLabel: confirmLabel,
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) => child,
  );
}

/// 省份 / 所在地区选择：全 APP 统一入口。
Future<String?> showAppProvincePicker({
  required BuildContext context,
  required List<String> provinces,
  String? selected,
}) {
  return showAppWheelPicker(
    context: context,
    title: '选择地区',
    items: provinces,
    selected: selected,
  );
}

int _indexForSelected(List<String> items, String? selected) {
  final trimmed = selected?.trim() ?? '';
  if (trimmed.isEmpty) return 0;
  final index = items.indexOf(trimmed);
  return index >= 0 ? index : 0;
}

class _AppWheelPickerOverlay extends StatelessWidget {
  const _AppWheelPickerOverlay({
    required this.animation,
    required this.title,
    required this.items,
    required this.initialIndex,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final Animation<double> animation;
  final String title;
  final List<String> items;
  final int initialIndex;
  final String cancelLabel;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: curved,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curved),
              child: _AppWheelPickerSheet(
                title: title,
                items: items,
                initialIndex: initialIndex,
                cancelLabel: cancelLabel,
                confirmLabel: confirmLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppWheelPickerSheet extends StatefulWidget {
  const _AppWheelPickerSheet({
    required this.title,
    required this.items,
    required this.initialIndex,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final String title;
  final List<String> items;
  final int initialIndex;
  final String cancelLabel;
  final String confirmLabel;

  @override
  State<_AppWheelPickerSheet> createState() => _AppWheelPickerSheetState();
}

class _AppWheelPickerSheetState extends State<_AppWheelPickerSheet> {
  late int _selectedIndex = widget.initialIndex;
  late final FixedExtentScrollController _scrollController =
      FixedExtentScrollController(initialItem: widget.initialIndex);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(ui(16))),
      child: ColoredBox(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: ui(44),
                padding: EdgeInsets.symmetric(horizontal: ui(8)),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _kToolbarBorder, width: ui(0.5)),
                  ),
                ),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: ui(8)),
                      minimumSize: Size(ui(56), ui(44)),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        widget.cancelLabel,
                        style: TextStyle(
                          fontSize: ui(16),
                          color: _kPickerMuted,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w400,
                          height: 24 / 16,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(16),
                          color: _kPickerTitle,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                          height: 24 / 16,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: ui(8)),
                      minimumSize: Size(ui(56), ui(44)),
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(widget.items[_selectedIndex]),
                      child: Text(
                        widget.confirmLabel,
                        style: TextStyle(
                          fontSize: ui(16),
                          color: _kPickerPrimary,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                          height: 24 / 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: ui(216),
                width: double.infinity,
                child: CupertinoPicker(
                  scrollController: _scrollController,
                  itemExtent: ui(34),
                  magnification: 1.08,
                  squeeze: 1.1,
                  useMagnifier: true,
                  onSelectedItemChanged: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  children: [
                    for (var i = 0; i < widget.items.length; i++)
                      Center(
                        child: Text(
                          widget.items[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(18),
                            color: i == _selectedIndex
                                ? _kPickerPrimary
                                : _kPickerTitle,
                            fontFamily: 'PingFang SC',
                            fontWeight: i == _selectedIndex
                                ? AppFont.w500
                                : AppFont.w400,
                            height: 22 / 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
