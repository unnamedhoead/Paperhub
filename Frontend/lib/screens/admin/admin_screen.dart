import 'package:flutter/material.dart';

import 'admin_controller.dart';
import 'admin_common.dart';
import 'admin_user_section.dart';
import 'admin_post_section.dart';
import 'admin_report_section.dart';
import 'admin_notice_section.dart';
import 'admin_permission_section.dart';

/// Top-level admin panel screen.
/// Owns [AdminController] and delegates each section to a dedicated widget.
class AdminScreen extends StatefulWidget {
  final String role;

  const AdminScreen({super.key, required this.role});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final AdminController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AdminController(role: widget.role);
    _controller.addListener(_onControllerChanged);
    _controller.init();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  // ---- menu items ----

  static const List<_AdminMenuItem> _superAdminMenuItems = [
    _AdminMenuItem(
        section: AdminSection.users,
        label: '用户管理',
        icon: Icons.people_outline),
    _AdminMenuItem(
        section: AdminSection.posts,
        label: '帖子管理',
        icon: Icons.description_outlined),
    _AdminMenuItem(
        section: AdminSection.userReports,
        label: '用户举报管理',
        icon: Icons.person_off_outlined),
    _AdminMenuItem(
        section: AdminSection.postReports,
        label: '帖子举报管理',
        icon: Icons.article_outlined),
    _AdminMenuItem(
        section: AdminSection.applyReview,
        label: '管理员申请审核',
        icon: Icons.assignment_turned_in_outlined),
    _AdminMenuItem(
        section: AdminSection.permissions,
        label: '管理员权限管理',
        icon: Icons.security_outlined),
  ];

  static const List<_AdminMenuItem> _regularAdminMenuItems = [
    _AdminMenuItem(
        section: AdminSection.userReports,
        label: '用户举报管理',
        icon: Icons.person_off_outlined),
    _AdminMenuItem(
        section: AdminSection.postReports,
        label: '帖子举报管理',
        icon: Icons.article_outlined),
    _AdminMenuItem(
        section: AdminSection.recommend,
        label: '管理员推荐',
        icon: Icons.person_add_outlined),
  ];

  List<_AdminMenuItem> get _menuItems =>
      _controller.isSuperAdmin ? _superAdminMenuItems : _regularAdminMenuItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: Row(
                children: [
                  _buildSidebar(context),
                  Expanded(
                    child: _buildSectionContent(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 1),
            blurRadius: 6,
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.dashboard_customize_outlined,
              size: 28, color: scheme.onSurface),
          const SizedBox(width: 12),
          Text(
            'PaperHub 管理员后台',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface),
          ),
          const Spacer(),
          Chip(
            avatar: Icon(
              _controller.isSuperAdmin
                  ? Icons.star
                  : Icons.verified_user_outlined,
              size: 18,
              color: Colors.white,
            ),
            label:
                Text(_controller.isSuperAdmin ? '超级管理员' : '管理员'),
            backgroundColor: _controller.isSuperAdmin
                ? Colors.deepPurpleAccent
                : Colors.blueAccent,
            labelStyle: const TextStyle(color: Colors.white),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.logout),
            label: const Text('返回普通模式'),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final collapsed = _controller.sidebarCollapsed;
    final sidebarWidth = collapsed ? 72.0 : 220.0;
    return Container(
      width: sidebarWidth,
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 12 : 20, vertical: 18),
            decoration: BoxDecoration(
              border: Border(
                  bottom:
                      BorderSide(color: scheme.outline.withOpacity(0.12))),
            ),
            child: Row(
              children: [
                if (!collapsed)
                  Text(
                    '管理员后台',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: scheme.onSurface),
                  ),
                if (!collapsed) const Spacer(),
                IconButton(
                  icon: Icon(
                    collapsed ? Icons.chevron_right : Icons.chevron_left,
                    color: scheme.onSurface.withOpacity(0.8),
                    size: 20,
                  ),
                  tooltip: collapsed ? '展开侧栏' : '收起侧栏',
                  onPressed: () {
                    _controller.sidebarCollapsed =
                        !_controller.sidebarCollapsed;
                    _controller.notify();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: _menuItems
                  .map((item) => _AdminMenuTile(
                        label: item.label,
                        icon: item.icon,
                        selected:
                            _controller.selectedSection == item.section,
                        collapsed: _controller.sidebarCollapsed,
                        onTap: () {
                          _controller.selectedSection = item.section;
                          _controller.notify();
                          if (item.section == AdminSection.recommend &&
                              _controller.recommendUserList.isEmpty &&
                              !_controller.recommendLoading) {
                            _controller.loadRecommendUsers(page: 0);
                          }
                          if (item.section == AdminSection.permissions &&
                              _controller.adminList.isEmpty &&
                              _controller.normalUserList.isEmpty &&
                              !_controller.permissionLoading) {
                            _controller.loadPermissionUsers();
                          }
                        },
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent(BuildContext context) {
    final section = _controller.selectedSection;
    switch (section) {
      case AdminSection.users:
        return AdminUserSection(controller: _controller);
      case AdminSection.posts:
        return AdminPostSection(controller: _controller);
      case AdminSection.reports:
        return AdminReportSection(controller: _controller);
      case AdminSection.userReports:
        return AdminUserReportSection(controller: _controller);
      case AdminSection.postReports:
        return AdminPostReportSection(controller: _controller);
      case AdminSection.notices:
        return AdminNoticeSection(controller: _controller);
      case AdminSection.recommend:
        return AdminRecommendSection(controller: _controller);
      case AdminSection.applyReview:
        return AdminApplyReviewSection(controller: _controller);
      case AdminSection.permissions:
        return AdminPermissionSection(controller: _controller);
    }
  }
}

// ==================== Private Menu Widgets ====================

class _AdminMenuItem {
  final AdminSection section;
  final String label;
  final IconData icon;
  const _AdminMenuItem(
      {required this.section, required this.label, required this.icon});
}

class _AdminMenuTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _AdminMenuTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color activeColor = scheme.primary;
    final Color inactiveColor = scheme.onSurface;
    final bgColor =
        selected ? scheme.primary.withOpacity(0.14) : Colors.transparent;
    return Material(
      color: bgColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: collapsed ? 16 : 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: selected ? activeColor : inactiveColor),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? activeColor : inactiveColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
