// lib/screens/follow/follow_action_button.dart
/// 关注操作按钮（支持关注/回关/互关提示）
import 'package:flutter/material.dart';
import '../../models/user_summary.dart';
import '../../services/api_service.dart';
import '../../utils/dialog_utils.dart';

/// 关注操作按钮（支持关注/回关/互关提示）
class FollowActionButton extends StatefulWidget {
  final UserSummary user;
  final String listType;
  final VoidCallback? onStateChanged;
  final ValueChanged<UserSummary>? onFollowChanged;

  const FollowActionButton({
    Key? key,
    required this.user,
    required this.listType,
    this.onStateChanged,
    this.onFollowChanged,
  }) : super(key: key);

  @override
  State<FollowActionButton> createState() => _FollowActionButtonState();
}

class _FollowActionButtonState extends State<FollowActionButton> {
  late bool _isFollowing;
  late bool _isFollower;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant FollowActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.isFollowing != widget.user.isFollowing ||
        oldWidget.user.isFollower != widget.user.isFollower ||
        oldWidget.listType != widget.listType) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    _isFollowing = widget.user.isFollowing ??
        (widget.user.isMutual == true ? true : null) ??
        (widget.listType == 'following' || widget.listType == 'mutual');
    _isFollower = widget.user.isFollower ??
        (widget.user.isMutual == true ? true : null) ??
        (widget.listType == 'followers' || widget.listType == 'mutual');
  }

  bool get _isMutual => _isFollowing && _isFollower;
  bool get _needsFollowBack => !_isFollowing && _isFollower;

  Future<void> _handlePressed() async {
    if (_isProcessing || widget.user.id.isEmpty) return;
    if (_isFollowing) {
      final confirmed = await _confirmUnfollow();
      if (confirmed != true) return;
      await _performUnfollow();
    } else {
      await _performFollow();
    }
  }

  Future<void> _performFollow() async {
    setState(() => _isProcessing = true);
    try {
      final resp = await ApiService.followUser(widget.user.id);
      if (resp['statusCode'] != 200) {
        final message = (resp['body'] as Map<String, dynamic>?)?['message'] ?? '操作失败';
        throw Exception(message);
      }
      if (!mounted) return;
      setState(() {
        _isFollowing = true;
        _isProcessing = false;
      });
      _emitChange();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    }
  }

  Future<void> _performUnfollow() async {
    setState(() => _isProcessing = true);
    try {
      final resp = await ApiService.unfollowUser(widget.user.id);
      if (resp['statusCode'] != 200) {
        final message = (resp['body'] as Map<String, dynamic>?)?['message'] ?? '操作失败';
        throw Exception(message);
      }
      if (!mounted) return;
      setState(() {
        _isFollowing = false;
        _isProcessing = false;
      });
      _emitChange();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    }
  }

  Future<bool?> _confirmUnfollow() async {
    return DialogUtils.showUnfollowConfirmDialog(
      context: context,
      userName: widget.user.displayName,
    );
  }

  ButtonStyle _buttonStyle(ColorScheme scheme) {
    final baseShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
    if (_needsFollowBack) {
      return OutlinedButton.styleFrom(
        backgroundColor: scheme.primary.withOpacity(0.1),
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        shape: baseShape,
      );
    }
    if (_isMutual) {
      return OutlinedButton.styleFrom(
        backgroundColor: scheme.surfaceVariant,
        foregroundColor: scheme.onSurfaceVariant,
        side: BorderSide(color: scheme.outline.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: baseShape,
      );
    }
    if (_isFollowing) {
      return OutlinedButton.styleFrom(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurfaceVariant,
        side: BorderSide(color: scheme.outline.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: baseShape,
      );
    }
    return OutlinedButton.styleFrom(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      side: BorderSide(color: scheme.primary),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      shape: baseShape,
    );
  }

  String get _label {
    if (_isMutual) return '互相关注';
    if (_needsFollowBack) return '回关';
    if (_isFollowing) return '已关注';
    return '关注';
  }

  void _emitChange() {
    final updated = widget.user.copyWith(
      isFollowing: _isFollowing,
      isFollower: _isFollower,
      isMutual: _isMutual,
    );
    widget.onFollowChanged?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.id.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: _isProcessing ? null : _handlePressed,
        style: _buttonStyle(scheme),
        child: _isProcessing
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              )
            : Text(
                _label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
