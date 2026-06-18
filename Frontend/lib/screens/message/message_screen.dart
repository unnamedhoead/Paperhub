/// PaperHub 消息页面 — 骨架
///
/// 提供：
/// - 顶部图标导航（赞和收藏、新增关注、评论和@）
/// - 会话列表
/// - 底部导航栏
import 'package:flutter/material.dart';
import '../../models/conversation_model.dart';
import '../../models/notification_model.dart';
import '../../services/chat_service.dart';
import '../../services/api_service.dart';
import '../../services/unread_service.dart';
import '../../utils/dialog_utils.dart';
import '../home_screen.dart';
import '../profile_screen.dart';
import '../note_editor/note_editor_screen.dart';
import '../chat_screen.dart';
import 'conversation_list.dart';
import 'notification_list.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({Key? key}) : super(key: key);

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  List<Conversation> _filteredConversations = [];
  bool _isSearching = false;
  int _currentIndex = 1;
  UnreadCount _unreadCount = UnreadCount(likes: 0, follows: 0, comments: 0);
  int _totalUnreadMessages = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUnreadCount();
    _searchController.addListener(_onSearchChanged);
    _chatService.addListener(_onChatServiceChanged);
  }

  Future<void> _loadUnreadCount() async {
    try {
      final resp = await ApiService.getUnreadNotificationCount();
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        setState(() {
          _unreadCount = UnreadCount.fromJson(body);
        });
        UnreadService.instance.updateNotificationUnread(_unreadCount);
      }
    } catch (_) {}
  }

  void _onChatServiceChanged() {
    if (mounted) _updateConversationState();
  }

  @override
  void dispose() {
    _chatService.removeListener(_onChatServiceChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _chatService.loadConversations();
    if (!mounted) return;
    _updateConversationState();
  }

  void _updateConversationState() {
    if (!mounted) return;
    setState(() {
      _filteredConversations = _chatService.conversations;
      _totalUnreadMessages =
          _chatService.conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
    });
    UnreadService.instance.updateChatUnread(_totalUnreadMessages);
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      _isSearching = query.isNotEmpty;
      _filteredConversations = _chatService.searchConversations(query);
    });
  }

  void _onConversationTap(Conversation conversation) async {
    await _chatService.markAsRead(conversation.id);
    _updateConversationState();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversation: conversation),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _onRefresh() async {
    await _loadData();
    await _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(scheme),
      body: SafeArea(
        child: Column(children: [
          _buildTopIconNavigation(),
          Expanded(child: ConversationList(
            conversations: _filteredConversations,
            isLoading: _chatService.isLoadingConversations,
            isSearching: _isSearching,
            onRefresh: _onRefresh,
            onReload: _loadData,
            onConversationTap: _onConversationTap,
          )),
        ]),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(scheme),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme scheme) {
    return AppBar(
      backgroundColor: scheme.surface,
      elevation: 0,
      title: Text('消息',
          style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold)),
      centerTitle: true,
      actions: [
        IconButton(
            icon: Icon(Icons.search, color: scheme.onSurface),
            onPressed: _showSearch),
      ],
    );
  }

  Widget _buildTopIconNavigation() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark ? scheme.surface : Colors.white;
    final labelColor =
        isDark ? scheme.onSurface : const Color(0xFF222222);
    const likesBg = Color(0xFFFFEEF0);
    const likesIcon = Color(0xFFE53935);
    const followsBg = Color(0xFFE8F3FF);
    const followsIcon = Color(0xFF1E88E5);
    const commentsBg = Color(0xFFEFF8F1);
    const commentsIcon = Color(0xFF2E7D32);
    return Container(
      color: containerBg,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTopNavItem(
            icon: Icons.favorite,
            activeIcon: Icons.favorite,
            label: '赞和收藏',
            badgeCount: _unreadCount.likes,
            backgroundColor: likesBg,
            iconColor: likesIcon,
            labelColor: labelColor,
            activeLabelColor: labelColor,
            onTap: () {
              _navigateToLikesAndFavorites();
              _loadUnreadCount();
            },
          ),
          _buildTopNavItem(
            icon: Icons.person_add,
            activeIcon: Icons.person_add,
            label: '新增关注',
            badgeCount: _unreadCount.follows,
            backgroundColor: followsBg,
            iconColor: followsIcon,
            labelColor: labelColor,
            activeLabelColor: labelColor,
            onTap: () {
              _navigateToNewFollowers();
              _loadUnreadCount();
            },
          ),
          _buildTopNavItem(
            icon: Icons.chat_bubble,
            activeIcon: Icons.chat_bubble,
            label: '评论和@',
            badgeCount: _unreadCount.comments,
            backgroundColor: commentsBg,
            iconColor: commentsIcon,
            labelColor: labelColor,
            activeLabelColor: labelColor,
            onTap: () {
              _navigateToCommentsAndMentions();
              _loadUnreadCount();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required VoidCallback onTap,
    int badgeCount = 0,
    Color? backgroundColor,
    Color? iconColor,
    Color? labelColor,
    Color? activeLabelColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.white,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(icon,
                color: iconColor ?? Colors.black87, size: 24),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: labelColor ?? Colors.black87)),
      ]),
    );
  }

  Widget _buildBottomNavigationBar(ColorScheme scheme) {
    return AnimatedBuilder(
      animation: UnreadService.instance,
      builder: (context, _) {
        final badge = UnreadService.instance.totalMessageBadge;
        return BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onBottomNavItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: scheme.surface,
          selectedItemColor: scheme.primary,
          unselectedItemColor: scheme.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: '首页'),
            BottomNavigationBarItem(
              icon: _buildMessageNavIcon(false, badge),
              activeIcon: _buildMessageNavIcon(true, badge),
              label: '消息',
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline),
                activeIcon: Icon(Icons.add_circle),
                label: '发布'),
            const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: '我的'),
          ],
        );
      },
    );
  }

  void _onBottomNavItemTapped(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) {
      Navigator.pushNamed(context, '/home')
          .then((_) => setState(() => _currentIndex = 1));
    } else if (index == 2) {
      Navigator.of(context)
          .push(PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const NoteEditorPage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) => child,
            transitionDuration: Duration.zero,
          ))
          .then((_) => setState(() => _currentIndex = 1));
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
      ).then((_) => setState(() => _currentIndex = 1));
    }
  }

  Widget _buildMessageNavIcon(bool active, int badgeCount) {
    return Stack(clipBehavior: Clip.none, children: [
      Icon(active ? Icons.chat_bubble : Icons.chat_bubble_outline),
      if (badgeCount > 0)
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: const BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.all(Radius.circular(8))),
            constraints:
                const BoxConstraints(minWidth: 12, minHeight: 12),
            child: Text(
              badgeCount > 99 ? '99+' : badgeCount.toString(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
    ]);
  }

  void _navigateToLikesAndFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const LikesAndFavoritesScreen()),
    ).then((_) async {
      try {
        await ApiService.markAllNotificationsAsReadByTypes([
          'POST_LIKE', 'POST_FAVORITE', 'COMMENT_LIKE',
        ]);
      } catch (_) {}
      _loadUnreadCount();
    });
  }

  void _navigateToNewFollowers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewFollowersScreen()),
    ).then((_) async {
      try {
        await ApiService.markAllNotificationsAsReadByTypes(['FOLLOW']);
      } catch (_) {}
      _loadUnreadCount();
    });
  }

  void _navigateToCommentsAndMentions() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const CommentsAndMentionsScreen()),
    ).then((_) async {
      try {
        await ApiService.markAllNotificationsAsReadByTypes([
          'COMMENT', 'MENTION',
        ]);
      } catch (_) {}
      _loadUnreadCount();
    });
  }

  void _showSearch() {
    DialogUtils.showInputDialog(
      context: context,
      title: '搜索聊天记录',
      hintText: '输入关键词搜索...',
      confirmText: '搜索',
      initialValue: _searchController.text,
    ).then((keyword) {
      if (keyword != null && keyword.isNotEmpty) {
        _searchController.text = keyword;
      }
    });
  }
}
