import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/models/conversation_model.dart';
import 'package:test/screens/message/conversation_list.dart';

void main() {
  testWidgets('ConversationList shows loading indicator when isLoading is true',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationList(
            conversations: [],
            isLoading: true,
            isSearching: false,
            onRefresh: () async {},
            onReload: () {},
            onConversationTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('加载中...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
      'ConversationList shows empty view when conversations is empty',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationList(
            conversations: [],
            isLoading: false,
            isSearching: false,
            onRefresh: () async {},
            onReload: () {},
            onConversationTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('暂无聊天记录'), findsOneWidget);
    expect(find.text('开始与同学聊天吧'), findsOneWidget);
    expect(find.text('重新加载'), findsOneWidget);
  });

  testWidgets(
      'ConversationList shows search empty view when isSearching is true',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationList(
            conversations: [],
            isLoading: false,
            isSearching: true,
            onRefresh: () async {},
            onReload: () {},
            onConversationTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('没有找到相关聊天'), findsOneWidget);
    expect(find.text('尝试其他关键词'), findsOneWidget);
    expect(find.text('重新加载'), findsNothing);
  });
}
