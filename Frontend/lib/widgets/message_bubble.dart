/// 消息气泡组件 — 重导出入口
///
/// 实际实现已按消息类型拆分到 `widgets/message/` 子目录：
/// - message_bubble.dart  主布局 + 分发器
/// - text_bubble.dart     文本消息
/// - image_bubble.dart    图片消息
/// - video_bubble.dart    视频消息
/// - audio_bubble.dart    语音消息
/// - file_bubble.dart     文件消息
/// - system_bubble.dart   系统消息
/// - share_bubble.dart    分享帖子消息
library;

export 'message/message_bubble.dart';
export 'message/text_bubble.dart';
export 'message/image_bubble.dart';
export 'message/video_bubble.dart';
export 'message/audio_bubble.dart';
export 'message/file_bubble.dart';
export 'message/system_bubble.dart';
export 'message/share_bubble.dart';
