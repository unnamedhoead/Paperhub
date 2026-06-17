import 'package:flutter/material.dart';

/// Pure presentation/formatting helpers for the admin panel.
///
/// Extracted from [AdminController] so the controller stays focused on state +
/// orchestration. [AdminController] re-exposes these as static methods for
/// backwards compatibility, so callers may use either entry point.

/// Extracts a display name from a user map.
/// Uses name first, falls back to email (trimmed before '@'), then empty.
String adminGetUserDisplayName(Map<String, dynamic>? user) {
  if (user == null) return '';
  final String? name = user['name']?.toString();
  if (name != null && name.isNotEmpty) return name.split('@').first;
  final String? email = user['email']?.toString();
  if (email != null && email.isNotEmpty) return email.split('@').first;
  return '';
}

String adminFormatPostTime(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  try {
    final dt = DateTime.parse(raw).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  } catch (_) {
    return raw;
  }
}

String adminTruncateTitle(String title) {
  const maxLen = 20;
  if (title.runes.length <= maxLen) return title;
  return String.fromCharCodes(title.runes.take(maxLen)) + '...';
}

String adminFormatReportedTarget(Map<String, dynamic> r) {
  final targetType = r['targetType']?.toString() ?? '';
  if (targetType == 'POST') {
    return 'POST ${r['postId'] ?? ''}';
  } else if (targetType == 'COMMENT') {
    return 'COMMENT ${r['commentId'] ?? ''}';
  } else if (targetType == 'USER') {
    final user = r['reportedUser'] as Map<String, dynamic>?;
    return 'U${user?['id'] ?? ''} / ${user?['name'] ?? ''}';
  }
  return '';
}

/// Builds a colored status chip for user statuses.
Widget adminBuildStatusChip(String? rawStatus) {
  final status = (rawStatus ?? 'NORMAL').toUpperCase();
  Color bg;
  String label;
  switch (status) {
    case 'AUDIT':
      bg = Colors.blue;
      label = '待审核';
      break;
    case 'BANNED':
      bg = Colors.redAccent;
      label = '封禁中';
      break;
    case 'MUTE':
    case 'SILENT': // 兼容旧数据
      bg = Colors.orange;
      label = '禁言中';
      break;
    default:
      bg = Colors.green;
      label = '正常';
      break;
  }
  return Chip(
    label: Text(label),
    backgroundColor: bg,
    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
  );
}

/// Builds a colored status chip for post statuses.
Widget adminBuildPostStatusChip(String? rawStatus) {
  if (rawStatus == null || rawStatus.isEmpty) {
    return const Text('-', style: TextStyle(color: Colors.grey));
  }
  final status = rawStatus.toUpperCase();
  Color bg;
  String label;
  switch (status) {
    case 'NORMAL':
      bg = Colors.green;
      label = '正常';
      break;
    case 'AUDIT':
      bg = Colors.orange;
      label = '审核中';
      break;
    case 'DRAFT':
      bg = Colors.blue;
      label = '打回草稿';
      break;
    case 'REMOVED':
      bg = Colors.red;
      label = '下架';
      break;
    default:
      bg = Colors.grey;
      label = rawStatus;
      break;
  }
  return Chip(
    label: Text(label),
    backgroundColor: bg,
    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
  );
}
