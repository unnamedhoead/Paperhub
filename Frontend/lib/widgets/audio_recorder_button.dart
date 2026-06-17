/// 录音按钮 — 长按录音 + 上传语音消息
///
/// 支持 Web (WebAudioRecorder) 和 native (record 包) 双平台录音。
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'attachment_picker.dart';
import 'web_audio_recorder.dart' if (dart.library.io) 'web_audio_recorder_stub.dart';

class AudioRecorderButton extends StatefulWidget {
  final bool enabled;
  final Function(List<String> mediaUrls, String messageType, String fileName,
      int fileSize)? onSendMedia;

  const AudioRecorderButton({
    Key? key,
    this.enabled = true,
    this.onSendMedia,
  }) : super(key: key);

  @override
  State<AudioRecorderButton> createState() => _AudioRecorderButtonState();
}

class _AudioRecorderButtonState extends State<AudioRecorderButton> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  WebAudioRecorder? _webAudioRecorder;
  bool _isRecording = false;
  String? _recordingPath;
  Uint8List? _webRecordingData;

  @override
  void dispose() {
    _audioRecorder.dispose();
    _webAudioRecorder?.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (kIsWeb) {
      try {
        _webAudioRecorder = WebAudioRecorder();
        if (!await _webAudioRecorder!.hasPermission()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('需要麦克风权限才能录音')),
            );
          }
          return;
        }
        _webAudioRecorder!.onStop.listen((data) {
          _webRecordingData = data;
        });
        await _webAudioRecorder!.start();
        setState(() => _isRecording = true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('录音失败: $e')),
          );
        }
      }
      return;
    }

    if (!await _audioRecorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要麦克风权限才能录音')),
        );
      }
      return;
    }

    try {
      final path =
          '${Directory.systemTemp.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() {
        _isRecording = true;
        _recordingPath = path;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音失败: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    setState(() => _isRecording = false);

    if (kIsWeb) {
      await _webAudioRecorder?.stop();
      await Future.delayed(const Duration(milliseconds: 100));

      if (_webRecordingData == null || _webRecordingData!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('录音失败，请重试')),
          );
        }
        return;
      }

      final bytes = _webRecordingData!;
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.webm';

      if (bytes.length < 1000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('录音时间太短')),
          );
        }
        _webRecordingData = null;
        return;
      }

      await _uploadAndSend(bytes, fileName);
      _webRecordingData = null;
      return;
    }

    final path = await _audioRecorder.stop();
    if (path != null) {
      final file = File(path);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('录音文件不存在')),
          );
        }
        return;
      }

      final bytes = await file.readAsBytes();
      final fileName = path.split('/').last;

      if (bytes.length < 1000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('录音时间太短')),
          );
        }
        file.delete();
        return;
      }

      await _uploadAndSend(bytes, fileName);
      file.delete();
    }
  }

  Future<void> _uploadAndSend(List<int> bytes, String fileName) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final url =
          await AttachmentPicker.uploadFileBytes(bytes, fileName);
      if (mounted) Navigator.pop(context);

      if (url != null && widget.onSendMedia != null) {
        widget.onSendMedia!([url], 'VOICE', fileName, bytes.length);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('语音上传失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音上传失败: $e')),
        );
      }
    }
  }

  void cancelRecording() {
    if (_isRecording) {
      if (kIsWeb) {
        _webAudioRecorder?.stop();
      } else {
        _audioRecorder.stop();
      }
      setState(() => _isRecording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      onLongPressCancel: cancelRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _isRecording ? 48 : 32,
        height: _isRecording ? 48 : 32,
        decoration: BoxDecoration(
          color: _isRecording
              ? Colors.red
              : (widget.enabled
                  ? const Color(0xFF1976D2)
                  : Colors.grey[300]),
          borderRadius:
              BorderRadius.circular(_isRecording ? 24 : 16),
          boxShadow: _isRecording
              ? [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.mic,
          color: widget.enabled ? Colors.white : Colors.grey[600],
          size: _isRecording ? 24 : 16,
        ),
      ),
    );
  }
}
