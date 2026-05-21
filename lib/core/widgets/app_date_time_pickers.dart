import 'package:flutter/material.dart';

import '../constants/app_assets.dart';

/// 与资料页「生日」日期选择器（`info_page` → `_editBirthday`）一致的主题色。
const Color appPickerPrimary = Color(0xFF8741FF);
const Color appPickerOnSurface = Color(0xFF0B081A);

/// 日期/时间选择器入口模式切换按钮用的 PNG 图标。
///
/// 继承 [Icon] 以满足 [showDatePicker] / [showTimePicker] 的 [Icon?] 参数类型。
class AppPickerAssetIcon extends Icon {
  const AppPickerAssetIcon(this.asset, {super.key, this.imageSize = 24})
      : super(Icons.circle, size: 0, color: Colors.transparent);

  final String asset;
  final double imageSize;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: imageSize,
      height: imageSize,
      fit: BoxFit.contain,
    );
  }
}

/// 日历模式下「切换输入模式」按钮。
const AppPickerAssetIcon appPickerRenameIcon = AppPickerAssetIcon(
  AppAssets.homeRename,
);

/// 输入模式下「切回日历」按钮。
const AppPickerAssetIcon appPickerCalendarIcon = AppPickerAssetIcon(
  AppAssets.homeRili,
);

DatePickerThemeData _appDatePickerThemeFor(BuildContext context) {
  final defaults = DatePickerTheme.defaults(context);
  final baseHeadline =
      defaults.headerHeadlineStyle ?? Theme.of(context).textTheme.headlineLarge;
  final headlineFontSize = (baseHeadline?.fontSize ?? 32) - 2;

  return DatePickerThemeData(
    headerHeadlineStyle: baseHeadline?.copyWith(fontSize: headlineFontSize),
  );
}

/// 供 `showDatePicker` / `showTimePicker` 的 [builder] 使用，统一紫色强调与按钮色。
ThemeData appPickerThemeFor(BuildContext context) {
  return Theme.of(context).copyWith(
    colorScheme: const ColorScheme.light(
      primary: appPickerPrimary,
      onPrimary: Colors.white,
      onSurface: appPickerOnSurface,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: appPickerPrimary),
    ),
    datePickerTheme: _appDatePickerThemeFor(context),
  );
}

/// `builder: appPickerDialogTheme` 传入 Material 日期/时间对话框。
Widget appPickerDialogTheme(BuildContext context, Widget? child) {
  return Theme(
    data: appPickerThemeFor(context),
    child: child ?? const SizedBox.shrink(),
  );
}

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? currentDate,
  DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
  SelectableDayPredicate? selectableDayPredicate,
  String? helpText,
  String? cancelText,
  String? confirmText,
  Locale? locale,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  TextDirection? textDirection,
  DatePickerMode initialDatePickerMode = DatePickerMode.day,
  String? errorFormatText,
  String? errorInvalidText,
  String? fieldHintText,
  String? fieldLabelText,
  TextInputType? keyboardType,
  Offset? anchorPoint,
  ValueChanged<DatePickerEntryMode>? onDatePickerModeChange,
  CalendarDelegate<DateTime> calendarDelegate = const GregorianCalendarDelegate(),
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    currentDate: currentDate,
    initialEntryMode: initialEntryMode,
    selectableDayPredicate: selectableDayPredicate,
    helpText: helpText,
    cancelText: cancelText,
    confirmText: confirmText,
    locale: locale,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    textDirection: textDirection,
    builder: appPickerDialogTheme,
    initialDatePickerMode: initialDatePickerMode,
    errorFormatText: errorFormatText,
    errorInvalidText: errorInvalidText,
    fieldHintText: fieldHintText,
    fieldLabelText: fieldLabelText,
    keyboardType: keyboardType,
    anchorPoint: anchorPoint,
    onDatePickerModeChange: onDatePickerModeChange,
    switchToInputEntryModeIcon: appPickerRenameIcon,
    switchToCalendarEntryModeIcon: appPickerCalendarIcon,
    calendarDelegate: calendarDelegate,
  );
}

Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  TimePickerEntryMode initialEntryMode = TimePickerEntryMode.dial,
  String? cancelText,
  String? confirmText,
  String? helpText,
  String? errorInvalidText,
  String? hourLabelText,
  String? minuteLabelText,
  RouteSettings? routeSettings,
  EntryModeChangeCallback? onEntryModeChanged,
  Offset? anchorPoint,
  Orientation? orientation,
  bool emptyInitialInput = false,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: appPickerDialogTheme,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    initialEntryMode: initialEntryMode,
    cancelText: cancelText,
    confirmText: confirmText,
    helpText: helpText,
    errorInvalidText: errorInvalidText,
    hourLabelText: hourLabelText,
    minuteLabelText: minuteLabelText,
    routeSettings: routeSettings,
    onEntryModeChanged: onEntryModeChanged,
    anchorPoint: anchorPoint,
    orientation: orientation,
    switchToInputEntryModeIcon: appPickerRenameIcon,
    emptyInitialInput: emptyInitialInput,
  );
}
