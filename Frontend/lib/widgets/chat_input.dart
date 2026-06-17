/// 聊天输入框组件 — 主入口（组合组件）
///
/// 组合以下子组件：
/// - AttachmentPicker  附件选择 + 上传
/// - AudioRecorderButton  长按录音
///
/// 自身负责：文本输入 + 表情按钮 + 发送按钮 + 布局
import 'package:flutter/material.dart';
import 'attachment_picker.dart';
import 'audio_recorder_button.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final Function(List<String> mediaUrls, String messageType, String fileName,
      int fileSize)? onSendMedia;
  final String hintText;
  final bool enabled;
  final int maxLines;

  const ChatInput({
    Key? key,
    required this.controller,
    required this.onSend,
    this.onSendMedia,
    this.hintText = '输入消息...',
    this.enabled = true,
    this.maxLines = 5,
  }) : super(key: key);

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  bool _isComposing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text.trim();
    setState(() {
      _isComposing = text.isNotEmpty;
    });
  }

  void _onFocusChanged() {
    // 获得焦点时的处理（预留）
  }

  void _handleSend() {
    final text = widget.controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSend(text);
  }

  void _handleEmojiButton() {
    _showEmojiPicker();
  }

  void _handleAttachmentButton() {
    if (widget.onSendMedia != null) {
      AttachmentPicker.showAttachmentOptions(
        context,
        onSendMedia: widget.onSendMedia!,
      );
    }
  }

  void _showEmojiPicker() {
    final emojis = [
      '😀', '😃', '😄', '😁', '😅', '😂', '🤣', '😊', '😇', '🙂',
      '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚', '😋', '😛',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '选择表情',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: emojis.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      widget.controller.text += emojis[index];
                      Navigator.pop(ctx);
                      _focusNode.requestFocus();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          emojis[index],
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildIconButton(
            icon: Icons.emoji_emotions_outlined,
            onPressed: _handleEmojiButton,
          ),
          _buildIconButton(
            icon: Icons.add_circle_outline,
            onPressed: _handleAttachmentButton,
          ),
          Expanded(
            child: Container(
              constraints:
                  const BoxConstraints(minHeight: 40, maxHeight: 120),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                maxLines: widget.maxLines,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 16),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                style: TextStyle(fontSize: 16, color: scheme.onSurface),
                onSubmitted: (text) {
                  if (_isComposing) {
                    _handleSend();
                  }
                },
              ),
            ),
          ),
          _buildSendOrMicButton(),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: Icon(icon, color: scheme.onSurfaceVariant, size: 24),
        onPressed: widget.enabled ? onPressed : null,
        splashRadius: 20,
      ),
    );
  }

  Widget _buildSendOrMicButton() {
    if (_isComposing) {
      return Container(
        margin: const EdgeInsets.only(left: 4, right: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                widget.enabled ? const Color(0xFF1976D2) : Colors.grey[300],
            borderRadius: BorderRadius.circular(20),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF1976D2).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: IconButton(
            icon: Icon(
              Icons.send,
              color: widget.enabled ? Colors.white : Colors.grey[600],
              size: 20,
            ),
            onPressed: widget.enabled ? _handleSend : null,
            splashRadius: 20,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(left: 4, right: 8),
      child: AudioRecorderButton(
        enabled: widget.enabled,
        onSendMedia: widget.onSendMedia,
      ),
    );
  }
}
