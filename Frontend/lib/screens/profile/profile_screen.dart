import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/post_model.dart';
import '../../models/user_profile.dart';
import '../../services/api/report_api.dart';
import '../../services/browse_history_service.dart';
import '../../services/chat_service.dart';
import '../../services/local_storage.dart';
import '../admin/admin_screen.dart';
import '../auth/login_page.dart';
import '../chat_screen.dart';
import '../follow_list_screen.dart';
import '../home_screen.dart';
import '../message_screen.dart';
import '../note_editor/note_editor_screen.dart';
import '../post_detail_screen.dart';
import '../privacy_settings_screen.dart';
import 'profile_bottom_nav.dart';
import 'profile_browse_history_sheet.dart';
import 'profile_controller.dart';
import 'profile_drawer.dart';
import 'profile_edit_sheet.dart';
import 'profile_header.dart';
import 'profile_image_viewer.dart';
import 'profile_research_directions.dart';
import 'profile_tabs.dart';

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
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _currentUserId;
  bool? _isFollowing;
  List<Post> _authoredPosts = [];
  List<Post> _favoritePosts = [];
  List<Post> _draftPosts = [];
  bool _loadingAuthored = false;
  bool _loadingFavorites = false;
  bool _loadingDrafts = false;
  bool _hasMoreAuthored = true;
  bool _hasMoreFavorites = true;
  bool _hasMoreDrafts = true;
  int _authoredPage = 1;
  int _favoritesPage = 1;
  int _draftsPage = 1;
  final Set<String> _likeInFlight = {};

  @override
  void initState() {
    super.initState();
    _currentUserId = LocalStorage.instance.read('userId');
    _loadProfile();
  }

  bool get _isViewingSelf {
    if (widget.userId == null) return true;
    if (_currentUserId == null) return false;
    return widget.userId == _currentUserId;
  }

  bool get _canViewFavorites {
    if (_profile == null) return false;
    if (_isViewingSelf) return true;
    return _profile!.publicFavorites;
  }

  // ── Profile loading ──────────────────────────────────────────────

  Future<void> _loadProfile({bool forceNetwork = false}) async {
    setState(() { _loading = true; _error = null; });

    try {
      // Try cache first for own profile
      if (_isViewingSelf && !forceNetwork) {
        final cached = LocalStorage.instance.read('currentUser');
        if (cached != null) {
          final payload = jsonDecode(cached) as Map<String, dynamic>;
          setState(() {
            _profile = UserProfile.fromJson(payload);
            _isFollowing = _profile!.isFollowing;
          });
        }
      }

      if (widget.userId == null) {
        final token = LocalStorage.instance.read('accessToken');
        if (token == null || token.isEmpty) {
          setState(() { _error = '请先登录'; _loading = false; });
          return;
        }
      }

      UserProfile profile;
      if (widget.userId == null) {
        profile = await ProfileController.loadOwnProfile(
          currentUserId: _currentUserId ?? '',
          cached: _profile,
        );
        // Refresh cached userId
        final uid = LocalStorage.instance.read('userId');
        if (uid != null) _currentUserId = uid;
      } else {
        profile = await ProfileController.loadUserProfile(widget.userId!);
      }

      setState(() {
        _profile = profile;
        _isFollowing = profile.isFollowing;
        _loading = false;
      });

      await Future.wait([
        _loadUserPosts(refresh: true),
        if (_canViewFavorites) _loadFavoritePosts(refresh: true),
        if (_isViewingSelf) _loadDraftPosts(refresh: true),
      ]);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _handleRefresh() => _loadProfile(forceNetwork: true);

  // ── Post lists ───────────────────────────────────────────────────

  Future<void> _loadUserPosts({bool refresh = false}) async {
    if (_profile == null || _loadingAuthored) return;
    setState(() { _loadingAuthored = true; if (refresh) { _authoredPage = 1; _hasMoreAuthored = true; _authoredPosts = []; } });
    final page = refresh ? 1 : _authoredPage;
    try {
      final result = await ProfileController.loadUserPosts(_profile!.id, page: page);
      setState(() {
        if (refresh) { _authoredPosts = result.posts; } else { _authoredPosts.addAll(result.posts); }
        _hasMoreAuthored = _authoredPosts.length < result.total;
        _authoredPage = page + 1;
      });
    } catch (e) { _showSnack('加载我的笔记失败：$e'); }
    finally { if (mounted) setState(() => _loadingAuthored = false); }
  }

  Future<void> _loadFavoritePosts({bool refresh = false}) async {
    if (_profile == null || !_isViewingSelf && !_canViewFavorites || _loadingFavorites) return;
    setState(() { _loadingFavorites = true; if (refresh) { _favoritesPage = 1; _hasMoreFavorites = true; _favoritePosts = []; } });
    final page = refresh ? 1 : _favoritesPage;
    try {
      final result = await ProfileController.loadFavoritePosts(_profile!.id, page: page);
      setState(() {
        if (refresh) { _favoritePosts = result.posts; } else { _favoritePosts.addAll(result.posts); }
        _hasMoreFavorites = _favoritePosts.length < result.total;
        _favoritesPage = page + 1;
      });
    } catch (e) { _showSnack('加载收藏失败：$e'); }
    finally { if (mounted) setState(() => _loadingFavorites = false); }
  }

  Future<void> _loadDraftPosts({bool refresh = false}) async {
    if (!_isViewingSelf || _loadingDrafts) return;
    setState(() { _loadingDrafts = true; if (refresh) { _draftsPage = 1; _hasMoreDrafts = true; _draftPosts = []; } });
    final page = refresh ? 1 : _draftsPage;
    try {
      final result = await ProfileController.loadDraftPosts(page: page);
      setState(() {
        if (refresh) { _draftPosts = result.posts; } else { _draftPosts.addAll(result.posts); }
        _hasMoreDrafts = _draftPosts.length < result.total;
        _draftsPage = page + 1;
      });
    } catch (e) { _showSnack('加载草稿失败：$e'); }
    finally { if (mounted) setState(() => _loadingDrafts = false); }
  }

  // ── Follow ────────────────────────────────────────────────────────

  Future<void> _toggleFollow() async {
    if (_profile == null || _isViewingSelf || _profile!.id.isEmpty) return;
    final targetId = _profile!.id;
    final original = _profile!.followersCount;
    final prev = _isFollowing ?? false;
    final next = !prev;
    setState(() {
      _isFollowing = next;
      _profile = _profile!.copyWith(followersCount: next ? original + 1 : (original > 0 ? original - 1 : 0), isFollowing: next);
    });
    try {
      await ProfileController.toggleFollow(targetId, prev);
    } catch (e) {
      setState(() { _isFollowing = prev; _profile = _profile!.copyWith(followersCount: original, isFollowing: prev); });
      _showSnack('操作失败：$e');
    }
  }

  // ── Like ──────────────────────────────────────────────────────────

  Future<bool> _handlePostLike(Post post) async {
    if (_likeInFlight.contains(post.id)) return false;
    _likeInFlight.add(post.id);
    try {
      final result = await ProfileController.toggleLike(post.id, post.isLiked);
      void update(List<Post> list) {
        final idx = list.indexWhere((p) => p.id == post.id);
        if (idx != -1) {
          setState(() {
            list[idx].likesCount = result.likesCount ?? list[idx].likesCount;
            list[idx].isLiked = result.isLiked ?? !list[idx].isLiked;
          });
        }
      }
      update(_authoredPosts);
      update(_favoritePosts);
      return true;
    } catch (_) {
      return false;
    } finally { _likeInFlight.remove(post.id); }
  }

  // ── Profile edit ──────────────────────────────────────────────────

  Future<void> _openEditProfileSheet() async {
    if (!_isViewingSelf || _profile == null) return;
    final result = await showModalBottomSheet<ProfileEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileEditSheet(profile: _profile!),
    );
    if (result != null) await _submitProfileChanges(result);
  }

  Future<void> _openDirectionsSheet() async {
    if (!_isViewingSelf || _profile == null) return;
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DirectionsEditSheet(directions: _profile!.researchDirections),
    );
    if (result != null) await _submitDirectionChanges(result);
  }

  Future<void> _submitProfileChanges(ProfileEditResult result) async {
    setState(() => _saving = true);
    try {
      final avatarUrl = await _uploadIf(result.avatarBytes, result.avatarFileName, isAvatar: true);
      final bgUrl = await _uploadIf(result.backgroundBytes, result.backgroundFileName, isAvatar: false);
      await ProfileController.updateProfile(
        displayName: result.displayName,
        bio: result.bio,
        researchDirections: result.researchDirections,
        avatarUrl: avatarUrl,
        backgroundImage: bgUrl,
      );
      await _loadProfile(forceNetwork: true);
      _showSnack('资料已更新');
    } catch (e) { _showSnack('保存失败：$e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _submitDirectionChanges(List<String> directions) async {
    setState(() => _saving = true);
    try {
      await ProfileController.updateProfile(
        displayName: _profile!.displayName,
        researchDirections: directions,
      );
      await _loadProfile(forceNetwork: true);
      _showSnack('研究方向已更新');
    } catch (e) { _showSnack('更新失败：$e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<String?> _uploadIf(Uint8List? bytes, String? name, {required bool isAvatar}) async {
    if (bytes == null || bytes.isEmpty) return null;
    return isAvatar
        ? ProfileController.uploadAvatar(bytes, name ?? 'avatar.png')
        : ProfileController.uploadBackground(bytes, name ?? 'background.png');
  }

  // ── Avatar / background direct pick ───────────────────────────────

  Future<void> _pickAvatarDirectly() async {
    if (!_isViewingSelf || _profile == null) return;
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1024);
    if (picked == null) return;
    final ext = picked.name.split('.').last.toLowerCase();
    if (!['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) { _showSnack('仅支持 png/jpg/jpeg/gif/webp 格式'); return; }
    setState(() => _saving = true);
    try {
      final bytes = await picked.readAsBytes();
      final avatarUrl = await ProfileController.uploadAvatar(bytes, picked.name);
      await ProfileController.updateProfile(displayName: _profile!.displayName, bio: _profile!.bio, researchDirections: _profile!.researchDirections, avatarUrl: avatarUrl);
      await _loadProfile(forceNetwork: true);
      _showSnack('头像已更新');
    } catch (e) { _showSnack('上传失败：$e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _pickBackgroundDirectly() async {
    if (!_isViewingSelf || _profile == null) return;
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1920);
    if (picked == null) return;
    final ext = picked.name.split('.').last.toLowerCase();
    if (!['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) { _showSnack('仅支持 png/jpg/jpeg/gif/webp 格式'); return; }
    setState(() => _saving = true);
    try {
      final bytes = await picked.readAsBytes();
      final bgUrl = await ProfileController.uploadBackground(bytes, picked.name);
      await ProfileController.updateProfile(displayName: _profile!.displayName, bio: _profile!.bio, researchDirections: _profile!.researchDirections, backgroundImage: bgUrl);
      await _loadProfile(forceNetwork: true);
      _showSnack('背景图已更新');
    } catch (e) { _showSnack('上传失败：$e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  // ── Avatar / background viewer ────────────────────────────────────

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
        onReplaceBackground: _isViewingSelf ? _pickBackgroundDirectly : null,
      ),
    );
  }

  // ── Browse history ────────────────────────────────────────────────

  Future<void> _openBrowseHistory() async {
    final userId = _currentUserId ?? LocalStorage.instance.read('userId');
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
        currentUserId: _currentUserId,
        onClearConfirmed: () => BrowseHistoryService.clearHistory(userId),
        onCleared: () { if (mounted) _showSnack('浏览历史已清空'); },
        onPostTap: _openPostDetail,
        onAuthorTap: (p) => Navigator.of(rootContext).pushNamed('/user/${p.author.id}'),
        onLikeTap: _handlePostLike,
      ),
    );
  }

  // ── Report dialog ─────────────────────────────────────────────────

  void _showReportDialog() {
    final reasonCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('举报用户'),
      content: TextField(controller: reasonCtrl, decoration: const InputDecoration(hintText: '请输入举报理由', border: OutlineInputBorder()), maxLines: 3),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(onPressed: () async {
          final reason = reasonCtrl.text.trim();
          if (reason.isEmpty) { _showSnack('请输入举报理由'); return; }
          Navigator.pop(ctx);
          try {
            final resp = await ReportApi.reportUser(widget.userId!, reason);
            _showSnack(resp['statusCode'] == 200 ? '举报成功' : ((resp['body'] as Map<String, dynamic>?)?['message'] ?? '举报失败'));
          } catch (e) { _showSnack('举报失败: $e'); }
        }, child: const Text('提交')),
      ],
    ));
  }

  // ── Chat ──────────────────────────────────────────────────────────

  void _startPrivateChat() {
    if (_profile == null || _isViewingSelf) return;
    setState(() => _saving = true);
    ChatService().createOrGetPrivateConversation(_profile!.id).then((conv) {
      if (mounted) setState(() => _saving = false);
      if (conv != null) { Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv))); }
      else { _showSnack('创建会话失败，请稍后重试'); }
    }).catchError((e) { if (mounted) setState(() => _saving = false); _showSnack('创建会话失败：$e'); });
  }

  // ── Follow list ───────────────────────────────────────────────────

  Future<void> _openFollowList(bool showFollowers) async {
    if (_profile == null) return;
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => FollowListScreen(userId: _profile!.id, initialTab: showFollowers ? 'followers' : 'following'),
    ));
    if (changed == true) await _loadProfile(forceNetwork: true);
  }

  // ── Post detail ───────────────────────────────────────────────────

  void _openPostDetail(Post post) {
    if (post.status == 'DRAFT' || post.status == 'AUDIT') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorPage(initialPost: post)))
          .then((_) { _loadProfile(forceNetwork: true); _loadDraftPosts(refresh: true); });
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)))
        .then((result) { if (result == true) { setState(() { _authoredPosts.removeWhere((p) => p.id == post.id); _favoritePosts.removeWhere((p) => p.id == post.id); }); return; } _loadProfile(forceNetwork: true); });
  }

  // ── Drawer ────────────────────────────────────────────────────────

  Widget? _buildDrawer() {
    if (!_isViewingSelf) return null;
    final hasAdmin = _profile != null && _profile!.role.isAdmin;
    return ProfileDrawer(
      isAdmin: hasAdmin,
      onOpenAdmin: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminScreen(role: _profile!.role.name))),
      onOpenPrivacy: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySettingsScreen())),
      onOpenHistory: _openBrowseHistory,
      onLogout: () async {
        await ProfileController.logout();
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
      },
    );
  }

  // ── Bottom nav ────────────────────────────────────────────────────

  Widget _buildBottomNavigationBar() {
    return ProfileBottomNav(
      currentIndex: _currentIndex,
      onNavigate: (index) {
        setState(() => _currentIndex = index);
        if (index == 0) { Navigator.pushNamed(context, '/home').then((_) => setState(() => _currentIndex = 3)); }
        else if (index == 1) { Navigator.push(context, PageRouteBuilder(pageBuilder: (_, __, ___) => const MessageScreen(), transitionsBuilder: (_, __, ___, child) => child, transitionDuration: Duration.zero)).then((_) => setState(() => _currentIndex = 3)); }
        else if (index == 2) { Navigator.push(context, PageRouteBuilder(pageBuilder: (_, __, ___) => const NoteEditorPage(), transitionsBuilder: (_, __, ___, child) => child, transitionDuration: Duration.zero)).then((_) => setState(() => _currentIndex = 3)); }
        else if (index == 3) { if (!_isViewingSelf) { Navigator.push(context, PageRouteBuilder(pageBuilder: (_, __, ___) => const ProfilePage(isMainPage: true), transitionsBuilder: (_, __, ___, child) => child, transitionDuration: Duration.zero)).then((_) => setState(() => _currentIndex = 3)); } }
      },
    );
  }

  // ── Snack helper ──────────────────────────────────────────────────

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _isViewingSelf ? 3 : 2,
      child: Scaffold(
        drawer: _buildDrawer(),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        bottomNavigationBar: (_isViewingSelf && widget.isMainPage) ? _buildBottomNavigationBar() : null,
        body: SafeArea(child: RefreshIndicator(onRefresh: _handleRefresh, child: _buildBody())),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.6, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48), const SizedBox(height: 12),
          Text(_error!), const SizedBox(height: 12),
          ElevatedButton(onPressed: () => _loadProfile(forceNetwork: true), child: const Text('重试')),
        ]))),
      ]);
    }
    if (_profile == null) {
      return ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
        SizedBox(height: 200, child: Center(child: Text('暂无资料'))),
      ]);
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(children: [
        if (_saving) const LinearProgressIndicator(minHeight: 2),
        ProfileHeader(
          profile: _profile!,
          isViewingSelf: _isViewingSelf,
          isFollowing: _isFollowing,
          saving: _saving,
          onEditProfile: _openEditProfileSheet,
          onToggleFollow: _toggleFollow,
          onStartChat: _startPrivateChat,
          onAvatarTap: () => _showAvatarViewer(_profile!.avatar),
          onBackgroundTap: () => _isViewingSelf ? _showBackgroundViewer(_profile!.backgroundImage) : null,
          onOpenFollowList: (showFollowers) => _openFollowList(showFollowers),
          onShowAvatarViewer: _showAvatarViewer,
        ),
        ProfileResearchDirections(profile: _profile!),
        ProfileTabs(
          isViewingSelf: _isViewingSelf,
          canViewFavorites: _canViewFavorites,
          authoredPosts: _authoredPosts,
          loadingAuthored: _loadingAuthored,
          hasMoreAuthored: _hasMoreAuthored,
          favoritePosts: _favoritePosts,
          loadingFavorites: _loadingFavorites,
          hasMoreFavorites: _hasMoreFavorites,
          draftPosts: _draftPosts,
          loadingDrafts: _loadingDrafts,
          hasMoreDrafts: _hasMoreDrafts,
          loadUserPosts: _loadUserPosts,
          loadFavoritePosts: _loadFavoritePosts,
          loadDraftPosts: _loadDraftPosts,
          onPostTap: _openPostDetail,
          onAuthorTap: (authorId) { if (authorId != _currentUserId) Navigator.of(context).pushNamed('/user/$authorId'); },
          onLikeTap: _handlePostLike,
        ),
      ]),
    );
  }

}

