import 'package:flutter_test/flutter_test.dart';
import 'package:test/models/user_summary.dart';
import 'package:test/screens/follow_controller.dart';

void main() {
  group('FollowController', () {
    test('initial state is correct', () {
      final controller = FollowController(
        userId: 'user-1',
        type: 'following',
      );

      expect(controller.userId, 'user-1');
      expect(controller.type, 'following');
      expect(controller.users, isEmpty);
      expect(controller.isFetching, false);
      expect(controller.hasMore, true);
      expect(controller.page, 0);
      expect(controller.pageSize, 20);
      expect(controller.forbiddenMessage, isNull);
    });

    test('handleLocalChange inserts new user at top', () {
      final controller = FollowController(
        userId: 'user-1',
        type: 'following',
      );

      final user = UserSummary(
        id: 'u1',
        displayName: 'New User',
        avatar: '',
        isFollowing: true,
      );

      controller.handleLocalChange(user);

      expect(controller.users.length, 1);
      expect(controller.users.first.id, 'u1');
    });

    test('handleLocalChange removes user that no longer matches type', () {
      final controller = FollowController(
        userId: 'user-1',
        type: 'following',
      );

      final user = UserSummary(
        id: 'u1',
        displayName: 'User',
        avatar: '',
        isFollowing: true,
      );
      controller.users = [user];

      // Now unfollow — should remove from following tab
      final unfollowed = user.copyWith(isFollowing: false);
      controller.handleLocalChange(unfollowed);

      expect(controller.users, isEmpty);
    });

    test('handleLocalChange respects followers tab filtering', () {
      final controller = FollowController(
        userId: 'user-1',
        type: 'followers',
      );

      // A user with isFollower=true should be added
      final follower = UserSummary(
        id: 'u1',
        displayName: 'Follower',
        avatar: '',
        isFollower: true,
      );
      controller.handleLocalChange(follower);
      expect(controller.users.length, 1);

      // A user with isFollower=false and not originally in list should not be added
      final nonFollower = UserSummary(
        id: 'u2',
        displayName: 'Non-follower',
        avatar: '',
        isFollower: false,
      );
      controller.handleLocalChange(nonFollower);
      expect(controller.users.length, 1);
    });

    test('handleLocalChange respects mutual tab filtering', () {
      final controller = FollowController(
        userId: 'user-1',
        type: 'mutual',
      );

      final mutualUser = UserSummary(
        id: 'u1',
        displayName: 'Mutual',
        avatar: '',
        isFollowing: true,
        isFollower: true,
      );
      controller.handleLocalChange(mutualUser);
      expect(controller.users.length, 1);

      final oneWayUser = UserSummary(
        id: 'u2',
        displayName: 'One way',
        avatar: '',
        isFollowing: true,
        isFollower: false,
      );
      controller.handleLocalChange(oneWayUser);
      expect(controller.users.length, 1);
    });

    test('applyExternalUpdate ignores non-displaying user not in list', () {
      final controller = FollowController(
        userId: 'user-1',
        type: 'following',
      );

      // User is not in list and not following — should be ignored
      final externalUser = UserSummary(
        id: 'u1',
        displayName: 'External',
        avatar: '',
        isFollowing: false,
      );

      controller.applyExternalUpdate(externalUser);
      expect(controller.users, isEmpty);
    });

    test('applyExternalUpdate adds user that should now display', () {
      final controller = FollowController(
        userId: 'user-1',
        type: 'following',
      );

      final user = UserSummary(
        id: 'u1',
        displayName: 'New Follower',
        avatar: '',
        isFollowing: true,
      );

      controller.applyExternalUpdate(user);
      expect(controller.users.length, 1);
      expect(controller.users.first.id, 'u1');
    });

    test('reload clears forbidden message', () {
      final controller = FollowController(
        userId: 'user-1',
        type: 'following',
      );
      controller.users = [
        UserSummary(id: 'u1', displayName: 'Existing', avatar: ''),
      ];
      controller.hasMore = false;
      controller.forbiddenMessage = 'hidden';

      controller.reload();

      expect(controller.forbiddenMessage, isNull);
    });
  });
}
