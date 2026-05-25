import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _aboutController = TextEditingController();
  String? _photo;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _aboutController.text = user?.about ?? '';
    _photo = user?.photo;
  }

  @override
  void dispose() {
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.first.bytes;
    if (bytes == null) return;
    setState(() {
      _photo = base64Encode(bytes);
    });
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<AuthProvider>().updateProfile(
      photo: _photo,
      about: _aboutController.text.trim(),
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Profile berhasil diperbarui' : 'Gagal update profile',
        ),
      ),
    );
    if (ok) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: _ProfileAvatar(photo: _photo, radius: 52)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.photo_camera),
            label: const Text('Pilih Foto Profile'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _aboutController,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'About',
              hintText: 'Ceritakan tentang diri kamu...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  final String? photo;
  final double radius;

  const ProfileAvatar({super.key, required this.photo, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    return _ProfileAvatar(photo: photo, radius: radius);
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? photo;
  final double radius;

  const _ProfileAvatar({required this.photo, required this.radius});

  @override
  Widget build(BuildContext context) {
    final raw = photo;
    if (raw != null && raw.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(base64Decode(raw)),
        );
      } catch (_) {}
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF6366F1),
      child: Icon(Icons.person, size: radius, color: Colors.white),
    );
  }
}
