// lib/screens/follow_list_screen.dart
/// 关注/粉丝/互相关注列表页面
import 'package:flutter/material.dart';
import '../models/user_summary.dart';
import '../services/local_storage.dart';
import 'follow/follow_tab.dart';

class FollowListScreen extends StatefulWidget {
  final String userId;
  final String? initialTab; // 'following', 'followers', 'mutual'

  const FollowListScreen({
    Key? key,
    required this.userId,
    this.initialTab,
  }) : super(key: key);

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;
  bool _hasRelationshipChanges = false;
  late final bool _isViewingSelf;
  late final List<GlobalKey<FollowTabState>> _tabKeys;

  @override
  void initState() {
    super.initState();

    final currentUserId = LocalStorage.instance.read('userId')?.toString();
    _isViewingSelf = currentUserId != null && currentUserId == widget.userId;

    final tabCount = _isViewingSelf ? 3 : 2;
    _tabKeys = List.generate(
      tabCount,
      (_) => GlobalKey<FollowTabState>(),
    );

    // 根据初始tab设置当前索引（在仅两栏时忽略 mutual）
    if (widget.initialTab == 'followers') {
      _currentTabIndex = 1;
    } else if (widget.initialTab == 'mutual' && _isViewingSelf) {
      _currentTabIndex = 2;
    }

    _tabController = TabController(
      length: _tabKeys.length,
      vsync: this,
      initialIndex: _currentTabIndex,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasRelationshipChanges);
        return false;
      },
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
            onPressed: () => Navigator.pop(context, _hasRelationshipChanges),
        ),
        title: Text(
          '关注与粉丝',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: scheme.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: scheme.primary,
              indicatorWeight: 2,
              labelColor: scheme.primary,
              unselectedLabelColor: scheme.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.normal,
              ),
              tabs: [
                const Tab(text: '关注'),
                const Tab(text: '粉丝'),
                if (_isViewingSelf) const Tab(text: '互相关注'),
              ],
            ),
          ),
        ),
      ),
        body: TabBarView(
          controller: _tabController,
          children: [
            FollowTab(
              key: _tabKeys[0],
              userId: widget.userId,
              type: 'following',
              onRelationshipChanged: _handleRelationshipChanged,
              onProfileReturned: _reloadAllTabs,
            ),
            FollowTab(
              key: _tabKeys[1],
              userId: widget.userId,
              type: 'followers',
              onRelationshipChanged: _handleRelationshipChanged,
              onProfileReturned: _reloadAllTabs,
            ),
            if (_isViewingSelf)
              FollowTab(
                key: _tabKeys[2],
                userId: widget.userId,
                type: 'mutual',
                onRelationshipChanged: _handleRelationshipChanged,
                onProfileReturned: _reloadAllTabs,
              ),
          ],
        ),
      ),
    );
  }

  void _handleRelationshipChanged(String sourceType, UserSummary user) {
    _hasRelationshipChanges = true;
    for (var i = 0; i < _tabKeys.length; i++) {
      final key = _tabKeys[i];
      final tabType = _tabTypeForIndex(i);
      if (tabType == sourceType) continue;
      key.currentState?.applyExternalUpdate(user);
    }
  }

  /// 从个人主页返回后，可能发生了关注关系变化，统一刷新所有Tab
  void _reloadAllTabs() {
    for (final key in _tabKeys) {
      key.currentState?.reload();
    }
    _hasRelationshipChanges = true;
  }

  String _tabTypeForIndex(int index) {
    if (index == 0) return 'following';
    if (index == 1) return 'followers';
    // 仅在查看自己的时候才会存在第三个互相关注 Tab
    return 'mutual';
  }
}
