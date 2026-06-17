/// 首页顶部导航栏（Logo + 关注/发现/分区切换 + 主题切换 + 搜索入口）。
///
/// 纯展示组件：所有状态（当前选中的 tab、关注红点、主题模式）由父组件传入，
/// 所有交互（切换 tab、切换主题、点击搜索）通过回调上抛给父组件处理。
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../utils/font_utils.dart';

/// 首页顶部栏组件。
class HomeTabBar extends StatelessWidget {
  /// 当前选中的顶部 tab：0=关注, 1=发现, 2=分区。
  final int selectedTab;

  /// 关注 tab 是否展示未读红点。
  final bool followingHasNew;

  /// 主题模式监听器（为 null 时不展示主题切换按钮）。
  final ValueNotifier<ThemeMode>? themeModeNotifier;

  /// 主题切换按钮回调（优先于 [onThemeModeChanged]）。
  final VoidCallback? onThemeToggle;

  /// 主题模式变更回调（当未提供 [onThemeToggle] 时使用）。
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  /// 点击某个 tab 时回调其索引。
  final ValueChanged<int> onTabSelected;

  /// 点击搜索图标回调。
  final VoidCallback onSearchTap;

  const HomeTabBar({
    Key? key,
    required this.selectedTab,
    required this.followingHasNew,
    required this.onTabSelected,
    required this.onSearchTap,
    this.themeModeNotifier,
    this.onThemeToggle,
    this.onThemeModeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo和PaperHub文字
          Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 32,
                width: 32,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(width: 32, height: 32);
                },
              ),
              const SizedBox(width: 8),
              Text(
                'PaperHub',
                style: FontUtils.textStyle(
                  text: 'PaperHub',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),

          // 中间按钮组
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTabButton("关注", 0, showUnreadDot: followingHasNew),
                const SizedBox(width: 24),
                _buildTabButton("发现", 1),
                const SizedBox(width: 24),
                _buildTabButton("分区", 2),
              ],
            ),
          ),

          // 搜索图标
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (themeModeNotifier != null)
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeModeNotifier!,
                  builder: (_, mode, __) {
                    final isDark = mode == ThemeMode.dark;
                    return IconButton(
                      tooltip: isDark ? '切换日间模式' : '切换夜间模式',
                      icon: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                        color: scheme.onSurface.withOpacity(0.8),
                      ),
                      onPressed: onThemeToggle ??
                          () {
                            final next =
                                isDark ? ThemeMode.light : ThemeMode.dark;
                            onThemeModeChanged?.call(next);
                          },
                    );
                  },
                ),
              InkWell(
                onTap: onSearchTap,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Icon(Icons.search,
                      color: scheme.onSurface.withOpacity(0.7), size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 顶部"关注 / 发现 / 分区"按钮样式
  Widget _buildTabButton(String label, int index,
      {bool showUnreadDot = false}) {
    final bool selected = selectedTab == index;
    return GestureDetector(
      onTap: () => onTabSelected(index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            label,
            style: FontUtils.textStyle(
              text: label,
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          if (showUnreadDot)
            Positioned(
              right: -12,
              top: -6,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
