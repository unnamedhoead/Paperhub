import 'package:flutter_test/flutter_test.dart';
import 'package:test/models/notification_model.dart';

void main() {
  group('NotificationItem', () {
    test('fromJson parses basic notification', () {
      final json = {
        'id': 'notif-1',
        'actor': {
          'id': 'user-1',
          'name': 'Alice',
          'avatar': 'https://example.com/avatar.png',
          'isFollowed': true,
        },
        'type': 'POST_LIKE',
        'content': '点赞了你的帖子',
        'post': {'id': 'post-1', 'title': 'Test Post'},
        'read': false,
        'createdAt': '2026-01-01T12:00:00.000Z',
      };

      final item = NotificationItem.fromJson(json);

      expect(item.id, 'notif-1');
      expect(item.actor.id, 'user-1');
      expect(item.actor.name, 'Alice');
      expect(item.actor.avatar, 'https://example.com/avatar.png');
      expect(item.actor.isFollowed, true);
      expect(item.type, NotificationType.postLike);
      expect(item.content, '点赞了你的帖子');
      expect(item.post?.id, 'post-1');
      expect(item.post?.title, 'Test Post');
      expect(item.read, false);
      expect(item.createdAt, DateTime.parse('2026-01-01T12:00:00.000Z'));
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 42,
        'actor': {'id': 1, 'name': 'Bob'},
        'type': 'FOLLOW',
        'content': '关注了你',
        'read': true,
        'createdAt': '2026-06-01T00:00:00.000Z',
      };

      final item = NotificationItem.fromJson(json);

      expect(item.id, '42');
      expect(item.actor.avatar, isNull);
      expect(item.type, NotificationType.follow);
      expect(item.post, isNull);
      expect(item.comment, isNull);
    });

    test('fromJson handles numeric id as String', () {
      final json = {
        'id': 123,
        'actor': {'id': 456, 'name': 'Charlie'},
        'type': 'COMMENT_LIKE',
        'content': '赞了你的评论',
        'read': false,
        'createdAt': '2026-06-01T00:00:00.000Z',
      };

      final item = NotificationItem.fromJson(json);

      expect(item.id, '123');
      expect(item.actor.id, '456');
    });
  });

  group('NotificationType', () {
    test('fromString maps all types correctly', () {
      expect(NotificationType.fromString('POST_LIKE'), NotificationType.postLike);
      expect(NotificationType.fromString('POST_FAVORITE'), NotificationType.postFavorite);
      expect(NotificationType.fromString('COMMENT_LIKE'), NotificationType.commentLike);
      expect(NotificationType.fromString('COMMENT'), NotificationType.comment);
      expect(NotificationType.fromString('MENTION'), NotificationType.mention);
      expect(NotificationType.fromString('FOLLOW'), NotificationType.follow);
    });

    test('fromString is case-insensitive', () {
      expect(NotificationType.fromString('post_like'), NotificationType.postLike);
      expect(NotificationType.fromString('Follow'), NotificationType.follow);
    });

    test('fromString defaults to comment for unknown type', () {
      expect(NotificationType.fromString('UNKNOWN_TYPE'), NotificationType.comment);
      expect(NotificationType.fromString(''), NotificationType.comment);
    });
  });

  group('UnreadCount', () {
    test('fromJson parses all fields', () {
      final json = {
        'likes': 5,
        'follows': 3,
        'comments': 2,
      };

      final count = UnreadCount.fromJson(json);

      expect(count.likes, 5);
      expect(count.follows, 3);
      expect(count.comments, 2);
    });

    test('fromJson defaults missing fields to 0', () {
      final json = {'likes': 1};

      final count = UnreadCount.fromJson(json);

      expect(count.likes, 1);
      expect(count.follows, 0);
      expect(count.comments, 0);
    });

    test('field values are correct', () {
      final a = UnreadCount(likes: 1, follows: 2, comments: 3);

      expect(a.likes, 1);
      expect(a.follows, 2);
      expect(a.comments, 3);
    });
  });

  group('ActorInfo', () {
    test('fromJson extracts isFollowed from various keys', () {
      final json1 = {'id': '1', 'name': 'User', 'isFollowed': true};
      expect(ActorInfo.fromJson(json1).isFollowed, true);

      final json2 = {'id': '1', 'name': 'User', 'is_followed': false};
      expect(ActorInfo.fromJson(json2).isFollowed, false);

      final json3 = {'id': '1', 'name': 'User', 'isFollowing': true};
      expect(ActorInfo.fromJson(json3).isFollowed, true);

      final json4 = {'id': '1', 'name': 'User'};
      expect(ActorInfo.fromJson(json4).isFollowed, isNull);
    });

    test('fromJson parses numeric follow flag', () {
      final json = {'id': '1', 'name': 'User', 'isFollowed': 1};
      expect(ActorInfo.fromJson(json).isFollowed, true);

      final json2 = {'id': '1', 'name': 'User', 'isFollowed': 0};
      expect(ActorInfo.fromJson(json2).isFollowed, false);
    });

    test('fromJson parses string follow flag', () {
      final json = {'id': '1', 'name': 'User', 'is_following': 'true'};
      expect(ActorInfo.fromJson(json).isFollowed, true);

      final json2 = {'id': '1', 'name': 'User', 'is_following': '0'};
      expect(ActorInfo.fromJson(json2).isFollowed, false);
    });
  });
}
