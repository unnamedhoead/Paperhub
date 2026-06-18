import 'package:flutter/material.dart';

import '../../widgets/bottom_navigation.dart';

/// Bottom navigation bar shown on the current user's main profile page.
///
/// Navigation side effects (route pushes, index reset) are owned by the host
/// screen and delivered through [onNavigate]; this widget only renders the bar.
class ProfileBottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int index) onNavigate;

  const ProfileBottomNav({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigation(
      currentIndex: currentIndex,
      onTap: onNavigate,
      context: context,
    );
  }
}
