import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final supabase = Supabase.instance.client;

  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final bioController = TextEditingController();
  String? avatarUrl;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = supabase.auth.currentUser;

    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', user!.id)
        .maybeSingle();

    if (data != null) {
      avatarUrl = data['avatar_url'];
      nameController.text = data['fullname'] ?? '';
      usernameController.text = data['username'] ?? '';
      bioController.text = data['bio'] ?? '';
      setState(() {});
    }
  }

  Future<String?> uploadImage(File file) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final fileExt = file.path.split('.').last;
    final fileName = '${user.id}.$fileExt';

    final path = 'images/$fileName';

    await supabase.storage
        .from('image')
        .upload(path, file, fileOptions: const FileOptions(upsert: true));

    final imageUrl = supabase.storage.from('image').getPublicUrl(path);

    return imageUrl;
  }

  Future<void> updateProfile() async {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  setState(() => isLoading = true);

  String? imageUrl;

  if (selectedImage != null) {
    imageUrl = await uploadImage(File(selectedImage!.path));
  }

  await supabase.from('profiles').update({
    'fullname': nameController.text.trim(),
    'username': usernameController.text.trim(),
    'bio': bioController.text.trim(),
    if (imageUrl != null) 'avatar_url': imageUrl,
  }).eq('id', user.id);

  if (!mounted) return; // 🔥 IMPORTANT

  setState(() => isLoading = false);

  Navigator.pop(context);
}

  final ImagePicker picker = ImagePicker();
  XFile? selectedImage;

  Future<void> pickImage(ImageSource source) async {
    final image = await picker.pickImage(source: source);

    if (image != null) {
      setState(() {
        selectedImage = image;
      });
    }
  }

  void showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Camera"),
                onTap: () {
                  Navigator.pop(context);
                  pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text("Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  pickImage(ImageSource.gallery); // ✅ correct
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        actions: [
          TextButton(
            onPressed: isLoading ? null : updateProfile,
            child: const Text(""),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              /// 🔥 Profile Image
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: selectedImage != null
                        ? FileImage(File(selectedImage!.path))
                        : (avatarUrl != null && avatarUrl!.isNotEmpty
                                  ? NetworkImage(avatarUrl!)
                                  : const NetworkImage(
                                      "https://via.placeholder.com/150",
                                    ))
                              as ImageProvider,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blue,
                      child: IconButton(
                        icon: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          showImagePicker();
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              /// 🔹 Username
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: "Username",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// 🔹 Bio
              TextField(
                controller: bioController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Bio",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              /// 🔥 Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : updateProfile,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Changes"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
