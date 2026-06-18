/// 语音消息气泡内容组件
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/message_model.dart';
import 'message_bubble.dart';
import 'text_bubble.dart';

class AudioBubbleContent extends StatefulWidget {
  final Message message;

  const AudioBubbleContent({Key? key, required this.message}) : super(key: key);

  @override
  State<AudioBubbleContent> createState() => _AudioBubbleContentState();
}

class _AudioBubbleContentState extends State<AudioBubbleContent> {
  AudioPlayer? _audioPlayer;
  bool _isPlayingAudio = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceUrl =
        widget.message.fileUrl ?? widget.message.mediaUrls.firstOrNull ?? '';
    if (voiceUrl.isEmpty) {
      return TextBubbleContent(message: widget.message);
    }

    return GestureDetector(
      onTap: () => _toggleAudioPlayback(voiceUrl),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              widget.message.isMe ? const Color(0xFF1976D2) : Colors.white,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomLeft: widget.message.isMe
                ? const Radius.circular(18)
                : const Radius.circular(4),
            bottomRight: widget.message.isMe
                ? const Radius.circular(4)
                : const Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPlayingAudio ? Icons.pause : Icons.play_arrow,
              color: widget.message.isMe
                  ? Colors.white
                  : const Color(0xFF1976D2),
              size: 20,
            ),
            const SizedBox(width: 8),
            Container(
              width: 80,
              height: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  5,
                  (index) => Container(
                    width: 2,
                    height: 12 + (index % 3) * 4,
                    decoration: BoxDecoration(
                      color: widget.message.isMe
                          ? Colors.white
                          : Colors.grey[400],
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              BubbleHelpers.formatDuration(
                  _isPlayingAudio ? _audioPosition : _audioDuration),
              style: TextStyle(
                color:
                    widget.message.isMe ? Colors.white70 : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAudioPlayback(String audioUrl) async {
    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
      _audioPlayer!.onDurationChanged.listen((duration) {
        if (mounted) {
          setState(() {
            _audioDuration = duration;
          });
        }
      });
      _audioPlayer!.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() {
            _audioPosition = position;
          });
        }
      });
      _audioPlayer!.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
            _audioPosition = Duration.zero;
          });
        }
      });
    }

    try {
      if (_isPlayingAudio) {
        await _audioPlayer!.pause();
        setState(() {
          _isPlayingAudio = false;
        });
      } else {
        await _audioPlayer!.play(UrlSource(audioUrl));
        setState(() {
          _isPlayingAudio = true;
        });
      }
    } catch (e) {
      // ignore playback errors
    }
  }
}
