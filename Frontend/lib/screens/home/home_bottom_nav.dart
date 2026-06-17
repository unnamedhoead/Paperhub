/// 首页底部导航包装：承载消息/发布/个人页的路由跳转与返回回调。
///
/// 把 home_screen 里底部导航的"建路由 + Navigator.push + 返回后回调"
/// 这段样板抽出来。组件本身只负责导航跳转（仅依赖 BuildContext），
/// 状态变更（高亮恢复、置顶帖、tab 切换、刷新发现流）通过回调上抛给父组件。
import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import '../../widgets/bottom_navigation.dart';
import '../message_screen.dart';
import '../note_editor/note_editor_screen.dart';
import '../profile_screen.dart';

/// 首页底部导航组件。
class HomeBottomNav extends StatelessWidget {
  /// 当前激活的导航索引（0~3）。
  final int currentIndex;

  /// 点击导航项时回调新索引（父组件据此更新高亮等状态）。
  final ValueChanged<int> onIndexChanged;

  /// 从消息页返回时回调。
  final VoidCallback onMessageReturn;

  /// 从发布页返回时回调：result 为发布得到的 [Post] 或其他（含 null）。
  final ValueChanged<Object?> onPublishReturn;

  /// 从个人页返回时回调。
  final VoidCallback onProfileReturn;

  const HomeBottomNav({
    Key? key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.onMessageReturn,
    required this.onPublishReturn,
    required this.onProfileReturn,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigation(
      currentIndex: currentIndex,
      onTap: (index) {
        onIndexChanged(index);
        if (index == 1) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const MessageScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) => child,
              transitionDuration: Duration.zero,
            ),
          ).then((_) => onMessageReturn());
        } else if (index == 2) {
          Navigator.of(context)
              .push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const NoteEditorPage(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) => child,
                  transitionDuration: Duration.zero,
                ),
              )
              .then((result) => onPublishReturn(result));
        } else if (index == 3) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const ProfilePage(isMainPage: true),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) => child,
              transitionDuration: Duration.zero,
            ),
          ).then((_) => onProfileReturn());
        }
      },
      context: context,
    );
  }
}
