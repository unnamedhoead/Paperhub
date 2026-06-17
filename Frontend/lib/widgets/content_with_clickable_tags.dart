import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// 在纯文本中渲染可点击的 #标签
class ContentWithClickableTags extends StatelessWidget {
  final String content;
  final List<String> subTags;
  final void Function(String) onTagTap;

  const ContentWithClickableTags({
    super.key,
    required this.content,
    required this.subTags,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    // 如果内容为空，返回空容器
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    // 使用正则表达式分割文本和标签
    final regex = RegExp(r'(#([^\s#]+))');
    final matches = regex.allMatches(content);

    if (matches.isEmpty) {
      // 没有标签，直接返回文本
      return Text(content, style: const TextStyle(fontSize: 14, height: 1.6));
    }

    // 构建富文本
    final textSpans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // 添加匹配前的普通文本
      if (match.start > lastEnd) {
        textSpans.add(
          TextSpan(
            text: content.substring(lastEnd, match.start),
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
        );
      }

      // 添加可点击的标签
      final tag = match.group(2)!; // 获取#后面的标签内容
      textSpans.add(
        TextSpan(
          text: match.group(1), // 完整的#标签文本
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Colors.blue,
            fontWeight: FontWeight.w500,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              onTagTap(tag);
            },
        ),
      );

      lastEnd = match.end;
    }

    // 添加剩余的文本
    if (lastEnd < content.length) {
      textSpans.add(
        TextSpan(
          text: content.substring(lastEnd),
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        children: textSpans,
        style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black),
      ),
    );
  }
}
