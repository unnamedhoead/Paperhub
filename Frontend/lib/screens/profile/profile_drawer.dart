import 'package:flutter/material.dart';

/// Side menu for the current user's own profile.
///
/// Each tile first closes the drawer (`Navigator.pop`) and then invokes the
/// matching callback, preserving the original screen behavior.
class ProfileDrawer extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onOpenAdmin;
  final VoidCallback onOpenPrivacy;
  final Future<void> Function() onOpenHistory;
  final Future<void> Function() onLogout;

  const ProfileDrawer({
    super.key,
    required this.isAdmin,
    required this.onOpenAdmin,
    required this.onOpenPrivacy,
    required this.onOpenHistory,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(child: ListView(padding: EdgeInsets.zero, children: [
      const DrawerHeader(child: Text('菜单', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
      if (isAdmin) ListTile(leading: const Icon(Icons.admin_panel_settings), title: const Text('管理员模式'), onTap: () { Navigator.pop(context); onOpenAdmin(); }),
      ListTile(leading: const Icon(Icons.settings), title: const Text('隐私设置'), onTap: () { Navigator.pop(context); onOpenPrivacy(); }),
      ListTile(leading: const Icon(Icons.history), title: const Text('浏览历史'), onTap: () async { Navigator.pop(context); await onOpenHistory(); }),
      const Divider(),
      ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('登出'), onTap: () async { Navigator.pop(context); await onLogout(); }),
    ]));
  }
}
