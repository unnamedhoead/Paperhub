import 'package:flutter_test/flutter_test.dart';
import 'package:test/models/user_profile.dart';
import 'package:test/screens/profile/profile_controller.dart';

void main() {
  group('UserRole enum', () {
    test('fromString returns USER for null', () {
      expect(UserRole.fromString(null), UserRole.USER);
    });

    test('fromString returns USER for empty string', () {
      expect(UserRole.fromString(''), UserRole.USER);
    });

    test('fromString parses ADMIN', () {
      expect(UserRole.fromString('ADMIN'), UserRole.ADMIN);
    });

    test('fromString parses SUPER_ADMIN', () {
      expect(UserRole.fromString('SUPER_ADMIN'), UserRole.SUPER_ADMIN);
    });

    test('fromString is case-insensitive', () {
      expect(UserRole.fromString('admin'), UserRole.ADMIN);
      expect(UserRole.fromString('Admin'), UserRole.ADMIN);
    });

    test('isAdmin returns true for ADMIN and SUPER_ADMIN', () {
      expect(UserRole.USER.isAdmin, false);
      expect(UserRole.ADMIN.isAdmin, true);
      expect(UserRole.SUPER_ADMIN.isAdmin, true);
    });

    test('toUpperCase backward-compat returns name', () {
      expect(UserRole.USER.toUpperCase(), 'USER');
      expect(UserRole.ADMIN.toUpperCase(), 'ADMIN');
    });
  });

  group('UserStatus enum', () {
    test('fromString returns NORMAL for null', () {
      expect(UserStatus.fromString(null), UserStatus.NORMAL);
    });

    test('fromString parses MUTED', () {
      expect(UserStatus.fromString('MUTED'), UserStatus.MUTED);
    });

    test('fromString parses BANNED', () {
      expect(UserStatus.fromString('BANNED'), UserStatus.BANNED);
    });

    test('fromString defaults to NORMAL for unknown value', () {
      expect(UserStatus.fromString('UNKNOWN'), UserStatus.NORMAL);
    });

    test('toUpperCase backward-compat returns name', () {
      expect(UserStatus.NORMAL.toUpperCase(), 'NORMAL');
      expect(UserStatus.MUTED.toUpperCase(), 'MUTED');
    });
  });

  group('UserProfile fromJson with enums', () {
    test('parses role and status into enums', () {
      final json = {
        'id': 1,
        'email': 'test@example.com',
        'role': 'ADMIN',
        'status': 'MUTED',
        'displayName': 'Test User',
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.role, UserRole.ADMIN);
      expect(profile.status, UserStatus.MUTED);
    });

    test('defaults role to USER and status to NORMAL when missing', () {
      final json = {
        'id': 1,
        'email': 'test@example.com',
        'displayName': 'Test User',
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.role, UserRole.USER);
      expect(profile.status, UserStatus.NORMAL);
    });
  });

  group('ProfileController PostListResult', () {
    test('PostListResult stores posts and total', () {
      final result = PostListResult(posts: const [], total: 42);
      expect(result.posts, isEmpty);
      expect(result.total, 42);
    });
  });

  group('ProfileController LikeResult', () {
    test('LikeResult stores likesCount and isLiked', () {
      final result = LikeResult(likesCount: 10, isLiked: true);
      expect(result.likesCount, 10);
      expect(result.isLiked, true);
    });

    test('LikeResult allows null fields', () {
      final result = LikeResult();
      expect(result.likesCount, isNull);
      expect(result.isLiked, isNull);
    });
  });
}
