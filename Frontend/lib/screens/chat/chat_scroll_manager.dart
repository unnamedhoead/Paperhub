/// 聊天页滚动管理器
///
/// 把"滚到底部 / 是否接近底部 / 上滑分页加载 / 触底标记已读"这一组滚动相关
/// 逻辑从 ChatScreen 的 State 中抽离，作为可独立测试的协作对象（非 Widget、
/// 非 extension）。State 只负责创建它、转发 scroll 监听并提供回调。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';

class ChatScrollManager {
  final ScrollController scrollController;
  final ChatService chatService;

  /// 当前会话 id（可能尚未确定，返回 null 表示跳过分页/已读）。
  final String? Function() conversationId;

  /// State 是否仍挂载，用于异步回调前的安全检查。
  final bool Function() isMounted;

  bool _userHasScrolled = false;
  bool get userHasScrolled => _userHasScrolled;

  ChatScrollManager({
    required this.scrollController,
    required this.chatService,
    required this.conversationId,
    required this.isMounted,
  });

  bool isNearBottom() {
    if (!scrollController.hasClients) return true;
    final position = scrollController.position;
    return position.maxScrollExtent - position.pixels < 100;
  }

  /// 绑定到 ScrollController 的监听：记录用户滚动、触底标记已读、上滑分页。
  void onScroll() {
    if (scrollController.hasClients &&
        scrollController.position.userScrollDirection !=
            ScrollDirection.idle) {
      _userHasScrolled = true;
    }

    final id = conversationId();
    if (id != null &&
        scrollController.offset >=
            scrollController.position.maxScrollExtent - 100) {
      chatService.markAsRead(id);
    }

    if (scrollController.hasClients && scrollController.offset <= 100) {
      _loadMoreMessagesIfNeeded();
    }
  }

  Future<void> _loadMoreMessagesIfNeeded() async {
    final id = conversationId();
    if (id == null) return;

    if (chatService.hasMoreMessages && !chatService.isLoadingMoreMessages) {
      double distanceFromBottom = 0;
      if (scrollController.hasClients) {
        final maxExtent = scrollController.position.maxScrollExtent;
        distanceFromBottom = maxExtent - scrollController.offset;
      }

      final int beforeMessageCount = chatService.messages.length;
      await chatService.loadMessages(id, page: chatService.currentPage + 1);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isMounted() || !scrollController.hasClients) return;
        final int afterMessageCount = chatService.messages.length;
        final int loadedMessageCount = afterMessageCount - beforeMessageCount;
        if (loadedMessageCount > 0) {
          final newMaxExtent = scrollController.position.maxScrollExtent;
          final double newOffset = newMaxExtent - distanceFromBottom;
          scrollController.jumpTo(newOffset.clamp(0.0, newMaxExtent));
        }
      });
    }
  }

  /// 滚动到底部。[force] 为 false 且用户已手动滚动过时不强制滚动。
  void scrollToBottom({bool force = false}) {
    if (!isMounted()) return;
    if (!force && _userHasScrolled) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!isMounted() || !scrollController.hasClients) return;

      final hasVoiceMessages =
          chatService.messages.any((msg) => msg.type == MessageType.voice);
      final int maxRetries = hasVoiceMessages ? 5 : 3;

      double previousMaxExtent = 0;
      int stableFrameCount = 0;

      for (int retry = 0; retry < maxRetries; retry++) {
        await Future.delayed(Duration(
            milliseconds:
                hasVoiceMessages ? 150 * (retry + 1) : 100 * (retry + 1)));

        if (!isMounted() || !scrollController.hasClients) return;

        final maxExtent = scrollController.position.maxScrollExtent;
        if (maxExtent > 0) {
          scrollController.jumpTo(maxExtent);
        }

        if (scrollController.hasClients) {
          final currentMaxExtent = scrollController.position.maxScrollExtent;
          if ((currentMaxExtent - previousMaxExtent).abs() < 1.0) {
            stableFrameCount++;
          } else {
            stableFrameCount = 0;
          }
          previousMaxExtent = currentMaxExtent;

          final position = scrollController.position;
          final isAtBottom = position.maxScrollExtent - position.pixels <= 10;
          if (isAtBottom && stableFrameCount >= 2) {
            break;
          }
        }
      }
    });
  }
}
