import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test/screens/admin/admin_controller.dart';

void main() {
  group('AdminController.getUserDisplayName', () {
    test('returns name before @ when name is set', () {
      final user = {'name': 'john@example.com', 'email': 'john@test.com'};
      expect(AdminController.getUserDisplayName(user), 'john');
    });

    test('returns full name when no @ in name', () {
      final user = {'name': 'Alice', 'email': 'alice@test.com'};
      expect(AdminController.getUserDisplayName(user), 'Alice');
    });

    test('falls back to email when name is missing', () {
      final user = {'email': 'bob@example.com'};
      expect(AdminController.getUserDisplayName(user), 'bob');
    });

    test('returns empty string for null user', () {
      expect(AdminController.getUserDisplayName(null), '');
    });

    test('returns empty string when all fields empty', () {
      final user = <String, dynamic>{};
      expect(AdminController.getUserDisplayName(user), '');
    });
  });

  group('AdminController.formatPostTime', () {
    test('formats ISO 8601 datetime to yyyy-MM-dd HH:mm', () {
      // Use a fixed UTC time and format to ensure test works across timezones
      final formatted =
          AdminController.formatPostTime('2025-06-15T14:30:00Z');
      // Just check that it produces a reasonable output (non-empty, contains
      // date-like structure)
      expect(formatted, isNotEmpty);
      expect(formatted, contains('2025'));
      expect(formatted, contains('06'));
      expect(formatted, contains('15'));
    });

    test('returns empty string for null', () {
      expect(AdminController.formatPostTime(null), '');
    });

    test('returns empty string for empty', () {
      expect(AdminController.formatPostTime(''), '');
    });

    test('returns raw string on parse failure', () {
      expect(AdminController.formatPostTime('not-a-date'), 'not-a-date');
    });
  });

  group('AdminController.truncateTitle', () {
    test('returns short title unchanged', () {
      expect(AdminController.truncateTitle('Hello'), 'Hello');
    });

    test('truncates long title with ellipsis', () {
      final result =
          AdminController.truncateTitle('This is a very long title that exceeds twenty characters');
      expect(result.length, lessThanOrEqualTo(23)); // 20 chars + '...'
      expect(result.endsWith('...'), isTrue);
    });

    test('handles exactly 20 characters', () {
      // "12345678901234567890" = 20 chars
      final twenty = List.filled(20, 'a').join();
      expect(AdminController.truncateTitle(twenty), twenty);
    });
  });

  group('AdminController.buildStatusChip', () {
    test('returns Chip for AUDIT status', () {
      final chip = AdminController.buildStatusChip('AUDIT');
      expect(chip, isA<Chip>());
    });

    test('returns Chip for BANNED status', () {
      final chip = AdminController.buildStatusChip('BANNED');
      expect(chip, isA<Chip>());
    });

    test('returns Chip for MUTE status', () {
      final chip = AdminController.buildStatusChip('MUTE');
      expect(chip, isA<Chip>());
    });

    test('returns Chip for null status (defaults to NORMAL)', () {
      final chip = AdminController.buildStatusChip(null);
      expect(chip, isA<Chip>());
    });
  });

  group('AdminController.buildPostStatusChip', () {
    test('returns Text for null status', () {
      final result = AdminController.buildPostStatusChip(null);
      expect(result, isA<Text>());
    });

    test('returns Chip for NORMAL status', () {
      final result = AdminController.buildPostStatusChip('NORMAL');
      expect(result, isA<Chip>());
    });

    test('returns Chip for AUDIT status', () {
      final result = AdminController.buildPostStatusChip('AUDIT');
      expect(result, isA<Chip>());
    });

    test('returns Chip for REMOVED status', () {
      final result = AdminController.buildPostStatusChip('REMOVED');
      expect(result, isA<Chip>());
    });
  });
}
