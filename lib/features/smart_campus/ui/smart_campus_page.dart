import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/ui/shell_layout.dart';
import '../state/smart_campus_controller.dart';
import '../state/smart_campus_state.dart';

class SmartCampusPage extends ConsumerWidget {
  const SmartCampusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(smartCampusControllerProvider);
    final controller = ref.read(smartCampusControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.all(ui(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '智慧校园',
            style: TextStyle(
              fontSize: ui(28),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(12)),
          Text(
            '当前智慧校园首页正在整理与重建中，先保留角色切换和基础入口，避免影响其他页面开发。',
            style: TextStyle(
              fontSize: ui(14),
              color: const Color(0xFF788698),
              fontFamily: 'PingFang SC',
              height: 1.5,
            ),
          ),
          SizedBox(height: ui(24)),
          Wrap(
            spacing: ui(12),
            runSpacing: ui(12),
            children: [
              for (final role in state.availableRoles)
                _RoleChip(
                  label: _roleLabel(role),
                  active: role == state.selectedRole,
                  onTap: () => controller.selectRole(role),
                  ui: ui,
                ),
            ],
          ),
          SizedBox(height: ui(24)),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FC),
                borderRadius: BorderRadius.circular(ui(16)),
                border: Border.all(color: const Color(0xFFE8EBF3)),
              ),
              padding: EdgeInsets.all(ui(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: '当前角色',
                    value: _roleLabel(state.selectedRole),
                    ui: ui,
                  ),
                  SizedBox(height: ui(12)),
                  _InfoRow(
                    label: '当前视图',
                    value: _viewLabel(state.mainView),
                    ui: ui,
                  ),
                  SizedBox(height: ui(24)),
                  Text(
                    '说明',
                    style: TextStyle(
                      fontSize: ui(18),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0B081A),
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                  SizedBox(height: ui(10)),
                  Text(
                    '原智慧校园页面文件在上一轮修改中出现了语法级损坏。这里先恢复为稳定骨架页，确保整个项目可以继续编译、路由可进入，后续再按 Figma 节点逐端重建学生端、老师端、班主任、宿管和管理员首页。',
                    style: TextStyle(
                      fontSize: ui(14),
                      color: const Color(0xFF5F6B7B),
                      fontFamily: 'PingFang SC',
                      height: 1.65,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(SmartCampusRole role) {
    switch (role) {
      case SmartCampusRole.student:
        return '学生端';
      case SmartCampusRole.teacher:
        return '任课老师';
      case SmartCampusRole.headTeacher:
        return '班主任';
      case SmartCampusRole.dormManager:
        return '宿管';
      case SmartCampusRole.admin:
        return '管理员';
    }
  }

  String _viewLabel(SmartCampusMainView view) {
    switch (view) {
      case SmartCampusMainView.dashboard:
        return '首页看板';
      case SmartCampusMainView.principalMailbox:
        return '校长信箱';
      case SmartCampusMainView.myClass:
        return '我的班级';
      case SmartCampusMainView.mySchedule:
        return '我的课表';
      case SmartCampusMainView.classWorkbench:
        return '班级工作台';
    }
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.ui,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final double Function(num) ui;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(40),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1A1630) : const Color(0xFFF1F3F8),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : const Color(0xFF5F6B7B),
            fontFamily: 'PingFang SC',
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.ui});

  final String label;
  final String value;
  final double Function(num) ui;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: ui(84),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(14),
              color: const Color(0xFF788698),
              fontFamily: 'PingFang SC',
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: ui(15),
            color: const Color(0xFF0B081A),
            fontWeight: FontWeight.w500,
            fontFamily: 'PingFang SC',
          ),
        ),
      ],
    );
  }
}
