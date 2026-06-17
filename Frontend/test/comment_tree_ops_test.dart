import 'package:flutter_test/flutter_test.dart';
import 'package:test/models/post_model.dart';
import 'package:test/screens/post_detail/comment_tree_ops.dart';

Author _author(String id) => Author(id: id, name: 'u$id', avatar: '');

Comment _comment(
  String id, {
  String? parentId,
  int likesCount = 0,
  bool isLiked = false,
  List<Comment>? replies,
}) {
  return Comment(
    id: id,
    author: _author('a$id'),
    content: 'c$id',
    parentId: parentId,
    likesCount: likesCount,
    isLiked: isLiked,
    replies: replies ?? <Comment>[],
    createdAt: DateTime(2020, 1, 1),
  );
}

void main() {
  group('CommentTreeOps.exists', () {
    test('finds top-level id', () {
      final list = [_comment('1'), _comment('2')];
      expect(CommentTreeOps.exists(list, '2'), isTrue);
      expect(CommentTreeOps.exists(list, '9'), isFalse);
    });

    test('finds nested reply id', () {
      final list = [
        _comment('1', replies: [_comment('1a', parentId: '1')]),
      ];
      expect(CommentTreeOps.exists(list, '1a'), isTrue);
    });
  });

  group('CommentTreeOps.insertCreated', () {
    test('inserts top-level at head and returns 1', () {
      final list = [_comment('1')];
      final delta = CommentTreeOps.insertCreated(list, _comment('2'));
      expect(delta, 1);
      expect(list.first.id, '2'); // 插入到顶部
      expect(list.length, 2);
    });

    test('appends reply to its parent and returns 1', () {
      final list = [_comment('1', replies: <Comment>[])];
      final delta =
          CommentTreeOps.insertCreated(list, _comment('1a', parentId: '1'));
      expect(delta, 1);
      expect(list.first.replies.single.id, '1a');
    });

    test('dedups existing id and returns 0', () {
      final list = [_comment('1')];
      final delta = CommentTreeOps.insertCreated(list, _comment('1'));
      expect(delta, 0);
      expect(list.length, 1);
    });

    test('falls back to top-level when parent missing', () {
      final list = [_comment('1')];
      final delta = CommentTreeOps.insertCreated(
        list,
        _comment('9a', parentId: 'missing'),
      );
      expect(delta, 1);
      expect(list.first.id, '9a');
    });
  });

  group('CommentTreeOps.applyUpdated', () {
    test('updates top-level content but keeps old replies', () {
      final list = [
        _comment('1', replies: [_comment('1a', parentId: '1')]),
      ];
      final updated = Comment(
        id: '1',
        author: _author('a1'),
        content: 'new-content',
        likesCount: 5,
        createdAt: DateTime(2020, 1, 1),
      );
      final hit = CommentTreeOps.applyUpdated(list, updated);
      expect(hit, isTrue);
      expect(list.first.content, 'new-content');
      expect(list.first.likesCount, 5);
      expect(list.first.replies.single.id, '1a'); // 保留旧 replies
    });

    test('updates a nested reply', () {
      final list = [
        _comment('1', replies: [_comment('1a', parentId: '1')]),
      ];
      final updated = Comment(
        id: '1a',
        author: _author('a1a'),
        content: 'edited',
        parentId: '1',
        createdAt: DateTime(2020, 1, 1),
      );
      expect(CommentTreeOps.applyUpdated(list, updated), isTrue);
      expect(list.first.replies.single.content, 'edited');
    });

    test('returns false when id not present', () {
      final list = [_comment('1')];
      expect(CommentTreeOps.applyUpdated(list, _comment('9')), isFalse);
    });
  });

  group('CommentTreeOps.removeDeleted', () {
    test('removes top-level and counts itself + replies', () {
      final list = [
        _comment('1', replies: [
          _comment('1a', parentId: '1'),
          _comment('1b', parentId: '1'),
        ]),
        _comment('2'),
      ];
      final delta = CommentTreeOps.removeDeleted(list, '1');
      expect(delta, 3); // 1 + 2 replies
      expect(list.map((c) => c.id), ['2']);
    });

    test('removes a reply and returns 1', () {
      final list = [
        _comment('1', replies: [_comment('1a', parentId: '1')]),
      ];
      final delta = CommentTreeOps.removeDeleted(list, '1a');
      expect(delta, 1);
      expect(list.first.replies, isEmpty);
    });

    test('returns 0 when id not found', () {
      final list = [_comment('1')];
      expect(CommentTreeOps.removeDeleted(list, '9'), 0);
      expect(list.length, 1);
    });
  });

  group('CommentTreeOps.removeReply', () {
    test('removes the matching reply from its parent', () {
      final parent = _comment('1', replies: [
        _comment('1a', parentId: '1'),
        _comment('1b', parentId: '1'),
      ]);
      final list = [parent];
      final hit = CommentTreeOps.removeReply(list, parent, '1a');
      expect(hit, isTrue);
      expect(list.first.replies.map((r) => r.id), ['1b']);
    });

    test('returns false when parent not in list', () {
      final orphanParent = _comment('99');
      final list = [_comment('1')];
      expect(CommentTreeOps.removeReply(list, orphanParent, 'x'), isFalse);
    });
  });

  group('CommentTreeOps.applyLikeUpdate', () {
    test('applies like fields to a top-level comment', () {
      final list = [_comment('1', likesCount: 2, isLiked: false)];
      final hit = CommentTreeOps.applyLikeUpdate(list, '1', {
        'likesCount': 7,
        'isLiked': true,
      });
      expect(hit, isTrue);
      expect(list.first.likesCount, 7);
      expect(list.first.isLiked, isTrue);
    });

    test('applies like fields to a nested reply', () {
      final list = [
        _comment('1', replies: [
          _comment('1a', parentId: '1', likesCount: 0),
        ]),
      ];
      final hit = CommentTreeOps.applyLikeUpdate(list, '1a', {
        'likesCount': 3,
      });
      expect(hit, isTrue);
      expect(list.first.replies.single.likesCount, 3);
    });

    test('returns false when comment id not found', () {
      final list = [_comment('1')];
      expect(CommentTreeOps.applyLikeUpdate(list, '9', const {}), isFalse);
    });
  });

  group('CommentTreeOps payload extractors', () {
    test('extractCommentJson reads comment/payload/data keys', () {
      expect(
        CommentTreeOps.extractCommentJson({'comment': {'id': 'x'}}),
        {'id': 'x'},
      );
      expect(
        CommentTreeOps.extractCommentJson({'payload': {'id': 'y'}}),
        {'id': 'y'},
      );
      expect(
        CommentTreeOps.extractCommentJson({'data': {'id': 'z'}}),
        {'id': 'z'},
      );
      expect(CommentTreeOps.extractCommentJson({'other': 1}), isNull);
    });

    test('extractDeletedId reads commentId/id/payload.id', () {
      expect(CommentTreeOps.extractDeletedId({'commentId': 'a'}), 'a');
      expect(CommentTreeOps.extractDeletedId({'id': 'b'}), 'b');
      expect(
        CommentTreeOps.extractDeletedId({
          'payload': {'id': 'c'},
        }),
        'c',
      );
      expect(CommentTreeOps.extractDeletedId({'x': 1}), isNull);
    });
  });

  group('CommentTreeOps copy helpers', () {
    test('copyWithReplies swaps replies, keeps other fields', () {
      final c = _comment('1', likesCount: 4, isLiked: true);
      final newReplies = [_comment('1a', parentId: '1')];
      final copy = CommentTreeOps.copyWithReplies(c, newReplies);
      expect(copy.id, '1');
      expect(copy.likesCount, 4);
      expect(copy.isLiked, isTrue);
      expect(copy.replies, newReplies);
    });

    test('copyFromUpdated uses updated fields + given replies', () {
      final updated = _comment('1', likesCount: 9);
      final oldReplies = [_comment('1a', parentId: '1')];
      final copy = CommentTreeOps.copyFromUpdated(updated, oldReplies);
      expect(copy.id, '1');
      expect(copy.likesCount, 9);
      expect(copy.replies, oldReplies);
    });
  });
}
