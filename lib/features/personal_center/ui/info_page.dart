import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/avatar_picker.dart';
import '../state/personal_center_controller.dart';
import '../state/personal_center_state.dart';

/// 个人信息页（迭代自 1.0 `pages/PersonalCenter/info.vue`）。
///
/// 布局/逻辑/功能与 1.0 完全对齐：
/// 头像、昵称、姓名（只读）、性别、生日、身份（只读）、实名认证、所在地区、
/// 所在学校、个人简介、修改密码。视觉风格采用 2.0 的白底卡片 + 紫色渐变按钮。
class InfoPage extends ConsumerWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(personalCenterControllerProvider);
    final controller = ref.read(personalCenterControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;

    return ShellPageSurface(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
      color: const Color(0xFFFAFAFB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _InfoHeader(onBack: () => Navigator.of(context).maybePop()),
          SizedBox(height: ui(12)),
          Expanded(
            child: state.loading && state.user.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _InfoListCard(state: state, controller: controller),
          ),
        ],
      ),
    );
  }
}

// ────────────────── 顶部返回栏 ──────────────────

class _InfoHeader extends StatelessWidget {
  const _InfoHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: <Widget>[
        _GlassIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
        SizedBox(width: ui(12)),
        Text(
          '个人信息',
          style: TextStyle(
            color: const Color(0xFF0B081A),
            fontSize: ui(16),
            fontWeight: FontWeight.w600,
            fontFamily: 'PingFang SC',
            height: 1.2,
          ),
        ),
      ],
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

// ────────────────── 信息卡片 ──────────────────

class _InfoListCard extends StatelessWidget {
  const _InfoListCard({required this.state, required this.controller});

  final PersonalCenterState state;
  final PersonalCenterController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final user = state.user;
    final verified = user['verified']?.toString() ?? '';
    final isVerified = verified == '已认证';

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(20), vertical: ui(8)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(14)),
          border: Border.all(color: const Color(0xFFF3F2F3)),
        ),
        child: Column(
          children: <Widget>[
            _AvatarRow(
              avatarUrl: user['headUrl']?.toString(),
              onTap: () => _editAvatar(context, controller, user),
            ),
            const _RowDivider(),
            _InfoRow(
              title: '昵称',
              value: user['nickname']?.toString() ?? '',
              onTap: () => _editNickname(context, controller, user),
            ),
            const _RowDivider(),
            _InfoRow(
              title: '姓名',
              value: user['realname']?.toString() ?? '',
              showChevron: false,
            ),
            const _RowDivider(),
            _InfoRow(
              title: '性别',
              value: user['gender']?.toString() ?? '',
              onTap: () => _editGender(context, controller, user),
            ),
            const _RowDivider(),
            _InfoRow(
              title: '生日',
              value: user['birthday']?.toString() ?? '',
              onTap: () => _editBirthday(context, controller, user),
            ),
            const _RowDivider(),
            _InfoRow(
              title: '身份',
              value: user['identity']?.toString() ?? '',
              showChevron: false,
            ),
            const _RowDivider(),
            _InfoRow(
              title: '实名认证',
              value: verified,
              showChevron: !isVerified,
              onTap: isVerified
                  ? null
                  : () {
                      Navigator.pushNamed(
                        context,
                        RoutePaths.verifie,
                        arguments: <String, dynamic>{'id': verified},
                      );
                    },
            ),
            const _RowDivider(),
            _InfoRow(
              title: '所在地区',
              value: user['province']?.toString() ?? '',
              onTap: () => _editProvince(context, controller, user),
            ),
            const _RowDivider(),
            _InfoRow(
              title: '所在学校',
              value: user['school']?.toString() ?? '',
              onTap: () => _editSchool(context, controller, user),
            ),
            const _RowDivider(),
            _InfoRow(
              title: '个人简介',
              value: user['introduce']?.toString() ?? '',
              onTap: () => _editIntroduce(context, controller, user),
            ),
            const _RowDivider(),
            _InfoRow(
              title: '修改密码',
              value: '',
              onTap: () => _editPassword(context, controller),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: Color(0xFFF3F2F3));
}

// ────────────────── 行：标题 + 值 / 头像 + 箭头 ──────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.title,
    required this.value,
    this.onTap,
    this.showChevron = true,
  });

  final String title;
  final String value;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: ui(56)),
        padding: EdgeInsets.symmetric(vertical: ui(14)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(15),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: ui(16)),
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF999999),
                    fontSize: ui(14),
                    fontFamily: 'PingFang SC',
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            if (showChevron)
              Icon(
                Icons.chevron_right,
                size: ui(20),
                color: const Color(0xFF6B6B6B),
              )
            else
              SizedBox(width: ui(20)),
          ],
        ),
      ),
    );
  }
}

class _AvatarRow extends StatelessWidget {
  const _AvatarRow({required this.avatarUrl, required this.onTap});

  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: ui(64)),
        padding: EdgeInsets.symmetric(vertical: ui(10)),
        child: Row(
          children: <Widget>[
            Text(
              '头像',
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(15),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
            const Spacer(),
            _AvatarImage(url: avatarUrl, size: ui(40)),
            SizedBox(width: ui(8)),
            Icon(
              Icons.chevron_right,
              size: ui(20),
              color: const Color(0xFF6B6B6B),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = url?.trim() ?? '';
    final isNetwork =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFEFEEF3),
        alignment: Alignment.center,
        child: isNetwork
            ? Image.network(
                trimmed,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.person_rounded, size: size * 0.6, color: const Color(0xFF7E879C)),
              )
            : Icon(
                Icons.person_rounded,
                size: size * 0.6,
                color: const Color(0xFF7E879C),
              ),
      ),
    );
  }
}

// ────────────────── 编辑动作（每个字段一个） ──────────────────

Future<void> _editNickname(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final value = await showTextInputDialog(
    context: context,
    title: '修改昵称',
    hintText: '请输入新昵称',
    initialValue: user['nickname']?.toString() ?? '',
    maxLength: 30,
  );
  if (value == null || value.isEmpty || !context.mounted) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'nickname': value,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editSchool(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final value = await showTextInputDialog(
    context: context,
    title: '修改学校',
    hintText: '请输入学校名称',
    initialValue: user['school']?.toString() ?? '',
    maxLength: 60,
  );
  if (value == null || value.isEmpty || !context.mounted) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'school': value,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editIntroduce(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final value = await showTextInputDialog(
    context: context,
    title: '修改个人简介',
    hintText: '请输入个人简介',
    initialValue: user['introduce']?.toString() ?? '',
    maxLength: 200,
  );
  if (value == null || value.isEmpty || !context.mounted) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'introduce': value,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editGender(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final selected = await showOptionsDialog(
    context: context,
    title: '请选择性别',
    options: const <String>['男', '女'],
    selected: user['gender']?.toString(),
  );
  if (selected == null || !context.mounted) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'gender': selected,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editProvince(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final provinces = await controller.ensureProvinces();
  if (!context.mounted) return;
  if (provinces.isEmpty) {
    _toast(context, '加载省份失败，请稍后重试');
    return;
  }
  final selected = await showOptionsDialog(
    context: context,
    title: '请选择所在地区',
    options: provinces,
    selected: user['province']?.toString(),
  );
  if (selected == null || !context.mounted) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'province': selected,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editBirthday(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final initial = _parseDate(user['birthday']?.toString()) ??
      DateTime(2010, 1, 1);
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1950, 1, 1),
    lastDate: DateTime(2014, 12, 31),
    helpText: '选择日期',
    cancelText: '取消',
    confirmText: '确定',
    builder: (ctx, child) {
      // 紫色主题，与 2.0 视觉一致。
      return Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF8741FF),
            onPrimary: Colors.white,
            onSurface: Color(0xFF0B081A),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8741FF),
            ),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
  if (picked == null || !context.mounted) {
    return;
  }
  final formatted =
      '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  final err = await controller.updateProfileFields(<String, dynamic>{
    'birthday': formatted,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final parts = raw.split('-');
    if (parts.length != 3) return DateTime.tryParse(raw);
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    return DateTime(y, m, d);
  } catch (_) {
    return DateTime.tryParse(raw);
  }
}

// ────────────────── 头像 / 密码 弹窗（自定义） ──────────────────

Future<void> _editAvatar(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  await showScaledDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (ctx) => _AvatarEditDialog(
      currentUrl: user['headUrl']?.toString(),
      controller: controller,
    ),
  );
}

class _AvatarEditDialog extends StatefulWidget {
  const _AvatarEditDialog({required this.currentUrl, required this.controller});

  final String? currentUrl;
  final PersonalCenterController controller;

  @override
  State<_AvatarEditDialog> createState() => _AvatarEditDialogState();
}

class _AvatarEditDialogState extends State<_AvatarEditDialog> {
  String? _newUrl;
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    final picked = await pickAvatarFile();
    if (!mounted) return;
    if (picked == null) {
      _toast(context, '当前平台暂未支持选择头像，请在浏览器中操作');
      return;
    }
    setState(() => _uploading = true);
    final res = await widget.controller.uploadAvatar(
      bytes: picked.bytes,
      filename: picked.filename,
    );
    if (!mounted) return;
    if (res.error != null) {
      setState(() => _uploading = false);
      _toast(context, res.error!);
      return;
    }
    setState(() {
      _newUrl = res.url;
      _uploading = false;
    });
  }

  Future<void> _confirm() async {
    final url = _newUrl;
    if (url == null || url.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final err = await widget.controller.updateProfileFields(<String, dynamic>{
      'headUrl': url,
    });
    if (!mounted) return;
    Navigator.of(context).pop();
    _toast(context, err ?? '修改成功！');
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final previewUrl = _newUrl ?? widget.currentUrl;
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
          children: <Widget>[
            Text(
              '修改头像',
              style: TextStyle(
                fontSize: ui(18),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: ui(20)),
            _AvatarImage(url: previewUrl, size: ui(160)),
            SizedBox(height: ui(20)),
            _UploadButton(
              uploading: _uploading,
              onTap: _pickAndUpload,
            ),
            SizedBox(height: ui(20)),
            AppDialogActionBar(
              cancelLabel: '取消',
              confirmLabel: '确认',
              confirmEnabled: !_uploading,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: _confirm,
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  const _UploadButton({required this.uploading, required this.onTap});

  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: uploading ? null : onTap,
      borderRadius: BorderRadius.circular(ui(10)),
      child: Container(
        height: ui(38),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4FF),
          borderRadius: BorderRadius.circular(ui(10)),
          border: Border.all(color: const Color(0xFFE8E2FF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (uploading)
              SizedBox(
                width: ui(14),
                height: ui(14),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF8741FF),
                ),
              )
            else
              Icon(Icons.add_a_photo_outlined,
                  size: ui(16), color: const Color(0xFF8741FF)),
            SizedBox(width: ui(6)),
            Text(
              uploading ? '上传中...' : '上传新头像',
              style: TextStyle(
                color: const Color(0xFF8741FF),
                fontSize: ui(13),
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

Future<void> _editPassword(
  BuildContext context,
  PersonalCenterController controller,
) async {
  await showScaledDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (ctx) => _PasswordEditDialog(controller: controller),
  );
}

class _PasswordEditDialog extends StatefulWidget {
  const _PasswordEditDialog({required this.controller});

  final PersonalCenterController controller;

  @override
  State<_PasswordEditDialog> createState() => _PasswordEditDialogState();
}

class _PasswordEditDialogState extends State<_PasswordEditDialog> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    final oldPwd = _oldCtrl.text.trim();
    final newPwd = _newCtrl.text.trim();
    final confirmPwd = _confirmCtrl.text.trim();
    if (oldPwd.isEmpty) {
      _toast(context, '请输入原密码');
      return;
    }
    if (newPwd.isEmpty) {
      _toast(context, '请输入新密码');
      return;
    }
    if (newPwd != confirmPwd) {
      _toast(context, '两次新密码不一致');
      return;
    }
    if (newPwd == oldPwd) {
      _toast(context, '新密码不能与旧密码相同');
      return;
    }
    setState(() => _submitting = true);
    final err = await widget.controller.changePassword(
      oldPassword: oldPwd,
      newPassword: newPwd,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (err != null) {
      _toast(context, err);
      return;
    }
    Navigator.of(context).pop();
    _toast(context, '修改成功');
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
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
          children: <Widget>[
            Text(
              '修改密码',
              style: TextStyle(
                fontSize: ui(18),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: ui(20)),
            _PasswordField(controller: _oldCtrl, hint: '请输入原密码'),
            SizedBox(height: ui(12)),
            _PasswordField(controller: _newCtrl, hint: '请输入新密码'),
            SizedBox(height: ui(12)),
            _PasswordField(controller: _confirmCtrl, hint: '请再次输入新密码'),
            SizedBox(height: ui(24)),
            AppDialogActionBar(
              cancelLabel: '取消',
              confirmLabel: '确认',
              confirmEnabled: !_submitting,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: _confirm,
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(45),
      child: TextField(
        controller: controller,
        obscureText: true,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.deny(RegExp(r'\s')),
        ],
        style: TextStyle(
          fontSize: ui(14),
          color: const Color(0xFF0B081A),
          fontFamily: 'PingFang SC',
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
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
    );
  }
}

// ────────────────── 工具：toast ──────────────────

void _toast(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
