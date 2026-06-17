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
import '../../widgets/bottom_navigation.dart';
import '../../widgets/post_card.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../admin/admin_screen.dart';
import '../auth/login_page.dart';
import '../chat_screen.dart';
import '../follow_list_screen.dart';
import '../home_screen.dart';
import '../message_screen.dart';
import '../../pages/note_editor_page.dart';
import '../post_detail_screen.dart';
import '../privacy_settings_screen.dart';
import 'profile_controller.dart';
import 'profile_edit_sheet.dart';
import 'profile_header.dart';
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
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent, insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          Center(child: InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: Image(image: ProfileHeader.resolveAvatar(avatar), fit: BoxFit.contain))),
          Positioned(top: 20, left: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.of(ctx).pop())),
        ]),
      ),
    );
  }

  void _showBackgroundViewer(String? background) {
    showDialog(
      context: context, barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent, insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          Center(child: InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: Image(image: ProfileHeader.resolveBackground(background), fit: BoxFit.contain))),
          if (_isViewingSelf) Positioned(bottom: 20, left: 0, right: 0, child: Center(child: FloatingActionButton.extended(
            onPressed: () { Navigator.of(ctx).pop(); _pickBackgroundDirectly(); },
            backgroundColor: Colors.white.withOpacity(0.9),
            icon: const Icon(Icons.image, color: Colors.black87),
            label: const Text('更换背景图', style: TextStyle(color: Colors.black87)),
          ))),
          Positioned(top: 20, left: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.of(ctx).pop())),
        ]),
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
      builder: (sheetCtx) => SafeArea(child: SizedBox(
        height: MediaQuery.of(sheetCtx).size.height * 0.8,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('浏览历史', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton.icon(onPressed: () async { await BrowseHistoryService.clearHistory(userId); Navigator.of(sheetCtx).pop(); if (mounted) _showSnack('浏览历史已清空'); }, icon: const Icon(Icons.delete_outline), label: const Text('清空')),
          ])),
          const Divider(height: 1),
          Expanded(child: MasonryGridView.count(
            crossAxisCount: 2, crossAxisSpacing: 3, mainAxisSpacing: 3,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            itemCount: posts.length,
            itemBuilder: (ctx, index) {
              final p = posts[index];
              return PostCard(post: p, onTap: () { Navigator.of(sheetCtx).pop(); _openPostDetail(p); },
                onAuthorTap: () { if (p.author.id != _currentUserId) { Navigator.of(sheetCtx).pop(); Navigator.of(rootContext).pushNamed('/user/${p.author.id}'); } },
                onLikeTap: _handlePostLike);
            },
          )),
        ]),
      )),
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

  Drawer? _buildDrawer() {
    if (!_isViewingSelf) return null;
    final hasAdmin = _profile != null && _profile!.role.isAdmin;
    return Drawer(child: ListView(padding: EdgeInsets.zero, children: [
      const DrawerHeader(child: Text('菜单', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
      if (hasAdmin) ListTile(leading: const Icon(Icons.admin_panel_settings), title: const Text('管理员模式'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => AdminScreen(role: _profile!.role.name))); }),
      ListTile(leading: const Icon(Icons.settings), title: const Text('隐私设置'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySettingsScreen())); }),
      ListTile(leading: const Icon(Icons.history), title: const Text('浏览历史'), onTap: () async { Navigator.pop(context); await _openBrowseHistory(); }),
      const Divider(),
      ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('登出'), onTap: () async {
        Navigator.pop(context);
        await ProfileController.logout();
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
      }),
    ]));
  }

  // ── Bottom nav ────────────────────────────────────────────────────

  Widget _buildBottomNavigationBar() {
    return BottomNavigation(currentIndex: _currentIndex, onTap: (index) {
      setState(() => _currentIndex = index);
      if (index == 0) { Navigator.pushNamed(context, '/home').then((_) => setState(() => _currentIndex = 3)); }
      else if (index == 1) { Navigator.push(context, PageRouteBuilder(pageBuilder: (_, __, ___) => const MessageScreen(), transitionsBuilder: (_, __, ___, child) => child, transitionDuration: Duration.zero)).then((_) => setState(() => _currentIndex = 3)); }
      else if (index == 2) { Navigator.push(context, PageRouteBuilder(pageBuilder: (_, __, ___) => const NoteEditorPage(), transitionsBuilder: (_, __, ___, child) => child, transitionDuration: Duration.zero)).then((_) => setState(() => _currentIndex = 3)); }
      else if (index == 3) { if (!_isViewingSelf) { Navigator.push(context, PageRouteBuilder(pageBuilder: (_, __, ___) => const ProfilePage(isMainPage: true), transitionsBuilder: (_, __, ___, child) => child, transitionDuration: Duration.zero)).then((_) => setState(() => _currentIndex = 3)); } }
    }, context: context);
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
        _buildResearchDirections(_profile!),
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

  Widget _buildResearchDirections(UserProfile profile) {
    final directions = profile.researchDirections;
    final scheme = Theme.of(context).colorScheme;
    final cardColor = scheme.surfaceVariant;
    final textColor = scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('研究方向', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
        ]),
        const SizedBox(height: 8),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 3))]),
          child: directions.isEmpty
              ? Text('还没有填写研究方向', style: TextStyle(color: textColor.withOpacity(0.6)))
              : Wrap(spacing: 8, runSpacing: 8, children: directions.map((d) => _buildDirectionChip(d, scheme)).toList()),
        ),
      ]),
    );
  }

  Widget _buildDirectionChip(String label, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: scheme.surface.withOpacity(0.8), border: Border.all(color: scheme.primary.withOpacity(0.6), width: 1), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: scheme.onSurface, fontSize: 14)),
    );
  }
}

