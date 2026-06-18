import 'package:flutter/material.dart';

import 'profile_header.dart';

/// Full-screen zoomable viewer for the profile avatar.
///
/// Use as the body of a [showDialog] call:
/// `showDialog(barrierColor: Colors.black87, builder: (_) => AvatarViewerDialog(avatar: url))`.
class AvatarViewerDialog extends StatelessWidget {
  final String? avatar;

  const AvatarViewerDialog({super.key, required this.avatar});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, insetPadding: EdgeInsets.zero,
      child: Stack(children: [
        Center(child: InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: Image(image: ProfileHeader.resolveAvatar(avatar), fit: BoxFit.contain))),
        Positioned(top: 20, left: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.of(context).pop())),
      ]),
    );
  }
}

/// Full-screen zoomable viewer for the profile background image.
///
/// When [onReplaceBackground] is non-null, a "更换背景图" action is shown; it
/// pops the dialog before invoking the callback, matching the original flow.
class BackgroundViewerDialog extends StatelessWidget {
  final String? background;
  final VoidCallback? onReplaceBackground;

  const BackgroundViewerDialog({
    super.key,
    required this.background,
    this.onReplaceBackground,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, insetPadding: EdgeInsets.zero,
      child: Stack(children: [
        Center(child: InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: Image(image: ProfileHeader.resolveBackground(background), fit: BoxFit.contain))),
        if (onReplaceBackground != null) Positioned(bottom: 20, left: 0, right: 0, child: Center(child: FloatingActionButton.extended(
          onPressed: () { Navigator.of(context).pop(); onReplaceBackground!(); },
          backgroundColor: Colors.white.withOpacity(0.9),
          icon: const Icon(Icons.image, color: Colors.black87),
          label: const Text('更换背景图', style: TextStyle(color: Colors.black87)),
        ))),
        Positioned(top: 20, left: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.of(context).pop())),
      ]),
    );
  }
}
