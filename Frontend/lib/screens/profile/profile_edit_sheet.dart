import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user_profile.dart';

class ProfileEditResult {
  final String displayName;
  final String? bio;
  final List<String> researchDirections;
  final Uint8List? avatarBytes;
  final String? avatarFileName;
  final Uint8List? backgroundBytes;
  final String? backgroundFileName;

  ProfileEditResult({
    required this.displayName,
    required this.researchDirections,
    this.bio,
    this.avatarBytes,
    this.avatarFileName,
    this.backgroundBytes,
    this.backgroundFileName,
  });
}

/// Bottom sheet for editing profile fields.
class ProfileEditSheet extends StatefulWidget {
  final UserProfile profile;
  const ProfileEditSheet({super.key, required this.profile});

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  final TextEditingController _directionController = TextEditingController();
  final FocusNode _directionFocus = FocusNode();
  late List<String> _directions;
  Uint8List? _avatarPreview;
  String? _avatarFileName;
  Uint8List? _backgroundPreview;
  String? _backgroundFileName;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _directions = [...widget.profile.researchDirections];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _directionController.dispose();
    _directionFocus.dispose();
    super.dispose();
  }

  ImageProvider<Object> _initialAvatar() {
    final avatar = widget.profile.avatar;
    if (avatar.startsWith('http')) return NetworkImage(avatar);
    if (avatar.startsWith('assets/')) return AssetImage(avatar);
    return AssetImage(avatar);
  }

  ImageProvider<Object> _initialBackground() {
    final bg = widget.profile.backgroundImage;
    if (bg.startsWith('http')) return NetworkImage(bg);
    if (bg.startsWith('assets/')) return AssetImage(bg);
    return AssetImage(bg);
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null) return;

    final ext = picked.name.split('.').last.toLowerCase();
    const allowed = ['png', 'jpg', 'jpeg', 'gif', 'webp'];
    if (!allowed.contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('仅支持 png/jpg/jpeg/gif/webp 格式')),
        );
      }
      return;
    }

    final bytes = await picked.readAsBytes();
    setState(() {
      _avatarPreview = bytes;
      _avatarFileName = picked.name;
    });
  }

  Future<void> _pickBackground() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;
    final ext = picked.name.split('.').last.toLowerCase();
    const allowed = ['png', 'jpg', 'jpeg', 'gif', 'webp'];
    if (!allowed.contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('仅支持 png/jpg/jpeg/gif/webp 格式')),
        );
      }
      return;
    }
    final bytes = await picked.readAsBytes();
    setState(() {
      _backgroundPreview = bytes;
      _backgroundFileName = picked.name;
    });
  }

  void _addDirection() {
    final value = _directionController.text.trim();
    if (value.isEmpty) return;
    if (_directions.contains(value)) {
      _directionController.clear();
      return;
    }
    setState(() {
      _directions.add(value);
      _directionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 20, bottom: bottomInset + 20),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('编辑个人资料',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: scheme.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 7 / 3,
                      child: _backgroundPreview != null
                          ? Image.memory(_backgroundPreview!, fit: BoxFit.cover)
                          : Image(
                              image: _initialBackground(), fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: ElevatedButton.icon(
                        onPressed: _pickBackground,
                        icon: const Icon(Icons.image),
                        label: const Text('更换背景'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: _avatarPreview != null
                          ? MemoryImage(_avatarPreview!)
                          : _initialAvatar(),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                style: TextStyle(color: scheme.onSurface),
                decoration: InputDecoration(
                  labelText: '昵称',
                  labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                  border: OutlineInputBorder(
                      borderSide: BorderSide(color: scheme.outline)),
                  enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: scheme.outline.withOpacity(0.5))),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: scheme.primary)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bioController,
                maxLines: 3,
                style: TextStyle(color: scheme.onSurface),
                decoration: InputDecoration(
                  labelText: '一句话简介',
                  hintText: '介绍一下自己吧',
                  labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                  hintStyle: TextStyle(
                      color: scheme.onSurfaceVariant.withOpacity(0.6)),
                  border: OutlineInputBorder(
                      borderSide: BorderSide(color: scheme.outline)),
                  enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: scheme.outline.withOpacity(0.5))),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: scheme.primary)),
                ),
              ),
              const SizedBox(height: 16),
              Text('研究方向',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: scheme.onSurface)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _directions
                    .map((e) => Chip(
                          label: Text(e,
                              style: TextStyle(color: scheme.onSurface)),
                          backgroundColor: scheme.surfaceContainerHighest,
                          deleteIconColor: scheme.onSurfaceVariant,
                          onDeleted: () =>
                              setState(() => _directions.remove(e)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _directionController,
                      focusNode: _directionFocus,
                      style: TextStyle(color: scheme.onSurface),
                      decoration: InputDecoration(
                        hintText: '新增方向',
                        hintStyle: TextStyle(
                            color:
                                scheme.onSurfaceVariant.withOpacity(0.6)),
                        border: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: scheme.outline)),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: scheme.outline.withOpacity(0.5))),
                        focusedBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: scheme.primary)),
                      ),
                      onSubmitted: (_) => _addDirection(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                      onPressed: _addDirection, child: const Text('添加')),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('昵称不能为空')));
                      return;
                    }
                    Navigator.of(context).pop(ProfileEditResult(
                      displayName: name,
                      bio: _bioController.text.trim().isEmpty
                          ? null
                          : _bioController.text.trim(),
                      researchDirections: _directions,
                      avatarBytes: _avatarPreview,
                      avatarFileName: _avatarFileName,
                      backgroundBytes: _backgroundPreview,
                      backgroundFileName: _backgroundFileName,
                    ));
                  },
                  child: const Text('保存修改'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for editing research directions only.
class DirectionsEditSheet extends StatefulWidget {
  final List<String> directions;
  const DirectionsEditSheet({super.key, required this.directions});

  @override
  State<DirectionsEditSheet> createState() => _DirectionsEditSheetState();
}

class _DirectionsEditSheetState extends State<DirectionsEditSheet> {
  final TextEditingController _controller = TextEditingController();
  late List<String> _directions;

  @override
  void initState() {
    super.initState();
    _directions = [...widget.directions];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addDirection() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_directions.contains(text)) {
      _controller.clear();
      return;
    }
    setState(() {
      _directions.add(text);
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 20, bottom: bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('管理研究方向',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface)),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: scheme.onSurface),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _directions
                .map((e) => Chip(
                      label: Text(e,
                          style: TextStyle(color: scheme.onSurface)),
                      backgroundColor: scheme.surfaceContainerHighest,
                      deleteIconColor: scheme.onSurfaceVariant,
                      onDeleted: () =>
                          setState(() => _directions.remove(e)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: TextStyle(color: scheme.onSurface),
                  decoration: InputDecoration(
                    hintText: '新增方向',
                    hintStyle: TextStyle(
                        color: scheme.onSurfaceVariant.withOpacity(0.6)),
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: scheme.outline)),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: scheme.outline.withOpacity(0.5))),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: scheme.primary)),
                  ),
                  onSubmitted: (_) => _addDirection(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                  onPressed: _addDirection, child: const Text('添加')),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_directions),
              child: const Text('保存标签'),
            ),
          ),
        ],
      ),
    );
  }
}
