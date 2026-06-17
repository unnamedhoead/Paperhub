/// 单条浏览历史记录的数据模型。
///
/// 从 [BrowseHistoryService] 中抽取为独立模型文件，
/// 供 service、测试和 UI 层复用。
class BrowseHistoryItem {
  final String postId;
  final String title;
  /// 浏览时间的毫秒时间戳（since epoch）。
  final int timestamp;

  BrowseHistoryItem({
    required this.postId,
    required this.title,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'title': title,
      'timestamp': timestamp,
    };
  }

  factory BrowseHistoryItem.fromMap(Map<String, dynamic> map) {
    return BrowseHistoryItem(
      postId: map['postId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}
