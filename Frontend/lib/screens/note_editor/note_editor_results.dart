// lib/screens/note_editor/note_editor_results.dart
//
// 笔记编辑器业务方法的返回值类型。Controller 完成校验 / 上传 / 网络请求后
// 返回这些值对象，由 screen 负责弹 SnackBar、关闭加载框、导航等副作用，
// 从而让 Controller 完全不持有 BuildContext。

import '../../models/post_model.dart';

/// 上传文件类型枚举（Bug Fix 1：替换 String fileType 参数）
enum UploadFileType { image, pdf }

/// 笔记发布管线的结果种类。
enum NoteSubmitKind {
  /// 前置校验未通过（标题 / 正文 / 图片 / 分区为空）。
  validationFailed,

  /// Web 端选了 PDF 但缺少字节数据。
  pdfDataError,

  /// 后端返回 2xx，且为编辑模式（应 pop 上一页）。
  editSuccess,

  /// 后端返回 2xx，且为新建模式（应跳转首页）。
  createSuccess,

  /// 后端返回非 2xx。
  failure,

  /// 网络异常 / 其它异常。
  error,
}

/// 发布 / 编辑笔记管线的返回结果。
class NoteSubmitResult {
  const NoteSubmitResult(
    this.kind, {
    this.message,
    this.createdPost,
    this.createdPostRaw,
    this.successMessage,
  });

  final NoteSubmitKind kind;

  /// 提示文本（校验失败 / 后端错误 / 异常）。
  final String? message;

  /// 新建成功时解析出的帖子（可能为 null）。
  final Post? createdPost;

  /// 新建成功时缓存的原始 JSON（用于首页临时置顶）。
  final Map<String, dynamic>? createdPostRaw;

  /// 成功时展示给用户的文案。
  final String? successMessage;

  const NoteSubmitResult.validationFailed(String message)
      : this(NoteSubmitKind.validationFailed, message: message);

  const NoteSubmitResult.pdfDataError(String message)
      : this(NoteSubmitKind.pdfDataError, message: message);

  const NoteSubmitResult.failure(String message)
      : this(NoteSubmitKind.failure, message: message);

  const NoteSubmitResult.error(String message)
      : this(NoteSubmitKind.error, message: message);

  bool get isSuccess =>
      kind == NoteSubmitKind.editSuccess ||
      kind == NoteSubmitKind.createSuccess;
}

/// arXiv 拉取结果（由 screen 决定弹什么颜色的 SnackBar）。
enum ArxivFetchStatus { success, failure }

class ArxivFetchResult {
  const ArxivFetchResult(this.status, this.message);

  final ArxivFetchStatus status;
  final String message;

  bool get isSuccess => status == ArxivFetchStatus.success;
}
