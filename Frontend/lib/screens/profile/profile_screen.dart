import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/post_model.dart';
import '../../services/browse_history_service.dart';
import '../../services/chat_service.dart';
import '../../services/local_storage.dart';
import '../admin/admin_screen.dart';
import '../auth/login_page.dart';
import '../chat_screen.dart';
import '../follow_list_screen.dart';
import '../message_screen.dart';
import '../note_editor/note_editor_screen.dart';
import '../post_detail_screen.dart';
import '../privacy_settings_screen.dart';
import 'profile_bottom_nav.dart';
import 'profile_browse_history_sheet.dart';
import 'profile_content.dart';
import 'profile_controller.dart';
import 'profile_drawer.dart';
import 'profile_edit_sheet.dart';
import 'profile_image_viewer.dart';
import 'profile_view_controller.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;
  final bool isMainPage;

  const ProfilePage({super.key, this.userId, this.isMainPage = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  int _currentIndex = 3;
  late final ProfileViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProfileViewController(userId: widget.userId)
      ..onError = _showSnack
      ..addListener(_onControllerChanged);
    _controller.loadProfile();
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

  Future<void> _handleRefresh() => _controller.loadProfile(forceNetwork: true);

  // -- Profile edit -----------------------------------------------------

  Future<void> _openEditProfileSheet() async {
    if (!_controller.isViewingSelf || _controller.profile == null) return;
    final result = await showModalBottomSheet<ProfileEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileEditSheet(profile: _controller.profile!),
    );
    if (result != null) await _submitProfileChanges(result);
  }

  Future<void> _submitProfileChanges(ProfileEditResult result) async {
    _controller.isSaving = true;
    try {
      final avatarUrl = await _controller.uploadIf(result.avatarBytes, result.avatarFileName, isAvatar: true);
      final bgUrl = await _controller.uploadIf(result.backgroundBytes, result.backgroundFileName, isAvatar: false);
      await ProfileController.updateProfile(
        displayName: result.displayName,
        bio: result.bio,
        researchDirections: result.researchDirections,
        avatarUrl: avatarUrl,
        backgroundImage: bgUrl,
      );
      await _controller.loadProfile(forceNetwork: true);
      _showSnack('资料已更新');
    } catch (e) { _showSnack('保存失败：$e'); }
    finally { if (mounted) _controller.isSaving = false; }
  }

  // -- Background direct pick -------------------------------------------

  Future<void> _pickBackgroundDirectly() async {
    if (!_controller.isViewingSelf || _controller.profile == null) return;
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1920);
    if (picked == null) return;
    final ext = picked.name.split('.').last.toLowerCase();
    if (!['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) { _showSnack('仅支持 png/jpg/jpeg/gif/webp 格式'); return; }
    _controller.isSaving = true;
    try {
      final bytes = await picked.readAsBytes();
      await _controller.uploadBackgroundAndReload(bytes, picked.name);
      _showSnack('背景图已更新');
    } catch (e) { _showSnack('上传失败：$e'); }
    finally { if (mounted) _controller.isSaving = false; }
  }

  // -- Avatar / background viewer ---------------------------------------

  void _showAvatarViewer(String? avatar) {
    showDialog(
      context: context, barrierColor: Colors.black87,
      builder: (_) => AvatarViewerDialog(avatar: avatar),
    );
  }

  void _showBackgroundViewer(String? background) {
    showDialog(
      context: context, barrierColor: Colors.black87,
      builder: (_) => BackgroundViewerDialog(
        background: background,
        onReplaceBackground: _controller.isViewingSelf ? _pickBackgroundDirectly : null,
      ),
    );
  }

  // -- Browse history ---------------------------------------------------

  Future<void> _openBrowseHistory() async {
    final userId = _controller.currentUserId ?? LocalStorage.instance.read('userId');
    if (userId == null || userId.isEmpty) { _showSnack('未登录，无法查看浏览历史'); return; }
    final history = await BrowseHistoryService.getHistory(userId);
    if (!mounted) return;
    if (history.isEmpty) { _showSnack('暂无浏览历史'); return; }
    final List<Post> posts = [];
    for (final item in history) {
      try {
        final post = await ProfileController.getPost(item.postId);
        if (post != null) { posts.add(post); }
      } catch (_) {}
    }
    if (!mounted || posts.isEmpty) { _showSnack('浏览的帖子都已不存在或加载失败'); return; }
    final rootContext = context;
    await showModalBottomSheet(
      context: rootContext, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => BrowseHistorySheet(
        posts: posts,
        currentUserId: _controller.currentUserId,
        onClearConfirmed: () => BrowseHistoryService.clearHistory(userId),
        onCleared: () { if (mounted) _showSnack('浏览历史已清空'); },
        onPostTap: _openPostDetail,
        onAuthorTap: (p) => Navigator.of(rootContext).pushNamed('/user/${p.author.id}'),
        onLikeTap: _controller.handlePostLike,
      ),
    );
  }

  // -- Chat -------------------------------------------------------------

  void _startPrivateChat() {
    final profile = _controller.profile;
    if (profile == null || _controller.isViewingSelf) return;
    _controller.isSaving = true;
    ChatService().createOrGetPrivateConversation(profile.id).then((conv) {
      if (mounted) _controller.isSaving = false;
      if (conv != null) { Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv))); }
      else { _showSnack('创建会话失败，请稍后重试'); }
    }).catchError((e) { if (mounted) _controller.isSaving = false; _showSnack('创建会话失败：$e'); });
  }

  // -- Follow list ------------------------------------------------------

  Future<void> _openFollowList(bool showFollowers) async {
    final profile = _controller.profile;
    if (profile == null) return;
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => FollowListScreen(userId: profile.id, initialTab: showFollowers ? 'followers' : 'following'),
    ));
    if (changed == true) await _controller.loadProfile(forceNetwork: true);
  }

  // -- Post detail ------------------------------------------------------

  void _openPostDetail(Post post) {
    if (post.status == 'DRAFT' || post.status == 'AUDIT') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorPage(initialPost: post)))
          .then((_) { _controller.loadProfile(forceNetwork: true); _controller.loadDraftPosts(refresh: true); });
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)))
        .then((result) { if (result == true) { _controller.removePost(post.id); return; } _controller.loadProfile(forceNetwork: true); });
  }

  // -- Drawer -----------------------------------------------------------

  Widget? _buildDrawer() {
    if (!_controller.isViewingSelf) return null;
    final profile = _controller.profile;
    final hasAdmin = profile != null && profile.role.isAdmin;
    return ProfileDrawer(
      isAdmin: hasAdmin,
      onOpenAdmin: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminScreen(role: profile!.role.name))),
      onOpenPrivacy: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySettingsScreen())),
      onOpenHistory: _openBrowseHistory,
      onLogout: () async {
        await ProfileController.logout();
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
      },
    );
  }

  // -- Bottom nav -------------------------------------------------------

  Widget _buildBottomNavigationBar() {
    return ProfileBottomNav(
      currentIndex: _currentIndex,
      onNavigate: (index) {
        setState(() => _currentIndex = index);
        if (index == 0) { Navigator.pushNamed(context, '/home').then((_) => setState(() => _currentIndex = 3)); }
        else if (index == 1) { Navigator.push(context, PageRouteBuilder(pageBuilder: (_, __, ___) => const MessageScreen(), transitionsBuilder: (_, __, ___, child) => child, transitionDuration: Duration.zero)).then((_) => setState(() => _currentIndex = 3)); }
        else if (index == 2) { Navigator.push(context, PageRouteBuilder(pageBuilder: (_, __, ___) => const NoteEditorPage(), transitionsBuilder: (_, __, ___, child) => child, transitionDuration: Duration.zero)).then((_) => setState(() => _currentIndex = 3)); }
        else if (index == 3) { if (!_controller.isViewingSelf) { Navigator.push(context, PageRouteBuilder(pageBuilder: (_, __, ___) => const ProfilePage(isMainPage: true), transitionsBuilder: (_, __, ___, child) => child, transitionDuration: Duration.zero)).then((_) => setState(() => _currentIndex = 3)); } }
      },
    );
  }

  // -- Snack helper -----------------------------------------------------

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // -- Build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _controller.isViewingSelf ? 3 : 2,
      child: Scaffold(
        drawer: _buildDrawer(),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        bottomNavigationBar: (_controller.isViewingSelf && widget.isMainPage) ? _buildBottomNavigationBar() : null,
        body: SafeArea(child: RefreshIndicator(onRefresh: _handleRefresh, child: _buildBody())),
      ),
    );
  }

  Widget _buildBody() {
    final c = _controller;
    return ProfileContent(
      loading: c.loading,
      error: c.error,
      saving: c.saving,
      profile: c.profile,
      isViewingSelf: c.isViewingSelf,
      canViewFavorites: c.canViewFavorites,
      isFollowing: c.isFollowing,
      currentUserId: c.currentUserId,
      authoredPosts: c.authoredPosts,
      loadingAuthored: c.loadingAuthored,
      hasMoreAuthored: c.hasMoreAuthored,
      favoritePosts: c.favoritePosts,
      loadingFavorites: c.loadingFavorites,
      hasMoreFavorites: c.hasMoreFavorites,
      draftPosts: c.draftPosts,
      loadingDrafts: c.loadingDrafts,
      hasMoreDrafts: c.hasMoreDrafts,
      onRetry: () => c.loadProfile(forceNetwork: true),
      onEditProfile: _openEditProfileSheet,
      onToggleFollow: c.toggleFollow,
      onStartChat: _startPrivateChat,
      onShowAvatarViewer: _showAvatarViewer,
      onShowBackgroundViewer: () => _showBackgroundViewer(c.profile!.backgroundImage),
      onOpenFollowList: _openFollowList,
      loadUserPosts: c.loadUserPosts,
      loadFavoritePosts: c.loadFavoritePosts,
      loadDraftPosts: c.loadDraftPosts,
      onPostTap: _openPostDetail,
      onAuthorTap: (authorId) { if (authorId != c.currentUserId) Navigator.of(context).pushNamed('/user/$authorId'); },
      onLikeTap: c.handlePostLike,
    );
  }

}
