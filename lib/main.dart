import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibechat/NewChatScreen.dart';
import 'package:vibechat/editProfile.dart';
import 'package:vibechat/login_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jjwszsjaikwypeqeaksf.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impqd3N6c2phaWt3eXBlcWVha3NmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcwNzM5MjksImV4cCI6MjA5MjY0OTkyOX0.ocFejm3r0D2jJFvIQ22S6hstCBcMqLo29Hiv3eeoYbE',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      home: StreamBuilder<AuthState>(
        stream: supabase.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = snapshot.data?.session;

          if (session == null) {
            return const LoginScreen();
          } else {
            return const MainScreen();
          }
        },
      ),
    );
  }
}

/// ================= MAIN SCREEN =================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: currentIndex == 0
          ? ChatListScreen(onAccountTap: () => setState(() => currentIndex = 1))
          : AccountScreen(onHomeTap: () => setState(() => currentIndex = 0)),
    );
  }
}

/// ================= CHAT LIST =================
class ChatListScreen extends StatelessWidget {
  final VoidCallback onAccountTap;

  const ChatListScreen({super.key, required this.onAccountTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      /// 🔹 APP BAR
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text("VibeChat", style: TextStyle(color: Colors.black)),
        actions: const [
          Icon(Icons.search, color: Colors.black),
          SizedBox(width: 16),
        ],
      ),

      /// 🔹 BODY
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _storySection(),
          const SizedBox(height: 10),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text("Chats"),
          ),

          Expanded(child: _chatList(context)),
        ],
      ),

      /// 🔹 BOTTOM BAR (OLD STYLE)
      bottomNavigationBar: _bottomBar(context),
    );
  }

  /// ================= STORIES =================
  ///
  Widget _storySection() {
    return FutureBuilder(
      future: supabase
          .from('stories')
          .select()
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 90,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final stories = snapshot.data as List;

        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: stories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _addStory(context);
              }

              final story = stories[index - 1];
              final isVideo = story['type'] == 'video';
              final url = story['media_url'] ?? story['image_url'];
              if (url == null || url.isEmpty) {
                return const SizedBox(); // avoid crash
              }
              return GestureDetector(
                onTap: () {
                  if (isVideo) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoStoryScreen(url: url),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ImageStoryScreen(url: url),
                      ),
                    );
                  }
                },

                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage:
                            (!isVideo && url != null && url.isNotEmpty)
                            ? NetworkImage(url)
                            : null,
                        child: isVideo
                            ? const Icon(Icons.play_arrow)
                            : (url == null || url.isEmpty
                                  ? const Icon(Icons.image_not_supported)
                                  : null),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isVideo ? "Video" : "Image",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> addVideoStory(BuildContext context) async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);

    if (video == null) return;

    final file = File(video.path);
    final user = supabase.auth.currentUser;

    final path = "${user!.id}/${DateTime.now().millisecondsSinceEpoch}.mp4";

    await supabase.storage.from('stories').upload(path, file);

    final url = supabase.storage.from('stories').getPublicUrl(path);

    await supabase.from('stories').insert({
      'user_id': user.id,
      'media_url': url,
      'type': 'video',
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Video story uploaded")));
  }

  Future<void> addStory(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final file = File(image.path);
    final user = supabase.auth.currentUser;

    if (user == null) return;

    final path = "${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg";

    // upload
    await supabase.storage.from('stories').upload(path, file);

    final url = supabase.storage.from('stories').getPublicUrl(path);

    // save to DB
    await supabase.from('stories').insert({
      'user_id': user.id,
      'image_url': url,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Story uploaded")));
  }

  Widget _addStory(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text("Upload Image"),
                onTap: () {
                  Navigator.pop(context);
                  addImageStory(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_call),
                title: const Text("Upload Video"),
                onTap: () {
                  Navigator.pop(context);
                  addVideoStory(context);
                },
              ),
            ],
          ),
        );
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey[300],
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 6),
          const Text("Add Story", style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> addImageStory(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final file = File(image.path);
    final user = supabase.auth.currentUser;

    final path = "${user!.id}/${DateTime.now().millisecondsSinceEpoch}.jpg";

    await supabase.storage.from('stories').upload(path, file);

    final url = supabase.storage.from('stories').getPublicUrl(path);

    await supabase.from('stories').insert({
      'user_id': user.id,
      'media_url': url,
      'type': 'image',
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Image story uploaded")));
  }

  Widget _storyItem(String name) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        children: [
          const CircleAvatar(radius: 28),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  /// ================= CHAT LIST (SUPABASE DATA) =================
  Widget _chatList(BuildContext context) {
    final currentUser = supabase.auth.currentUser;

    return FutureBuilder(
      future: supabase
          .from('conversation_participants')
          .select('''
        conversation_id,
        profiles ( id, username,avatar_url  ),
        conversations ( last_message, last_message_time )
      ''')
          .neq('user_id', currentUser!.id)
          .order(
            'last_message_time',
            ascending: false,
            referencedTable: 'conversations',
          ), // exclude current user
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = (snapshot.data ?? []) as List;

        if (chats.isEmpty) {
          return const Center(child: Text("No chats yet"));
        }

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];

            final profile = chat['profiles'];
            final message = chat['conversations']?['messages'] ?? [];
            String lastMessage = "No messages yet";
            if (message.isNotEmpty) {
              final last = message.last;
              lastMessage = last['content'] ?? '';
            }
            final avatar = profile?['avatar_url'];
            return ListTile(
              leading: CircleAvatar(
                radius: 28,
                backgroundImage:
                    (avatar != null && avatar.toString().isNotEmpty)
                    ? NetworkImage(avatar)
                    : const NetworkImage("https://via.placeholder.com/150"),
              ),

              title: Text(profile?['username'] ?? 'User'),

              subtitle: Text(
                chat['conversations']?['last_message'] ?? 'No messages',
              ),

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      conversationId: chat['conversation_id'],
                      username: profile?['username'] ?? 'User',
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// ================= BOTTOM BAR =================
  Widget _bottomBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          height: 65,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(35),
            boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Icon(Icons.home),

              /// 🔥 CENTER BUTTON
              GestureDetector(
                onTap: () => _showBottomSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 18),
                      SizedBox(width: 5),
                      Text("New Chat", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),

              IconButton(
                icon: const Icon(Icons.person),
                onPressed: onAccountTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ================= BOTTOM SHEET =================
  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text("New Chat"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewChatScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.person_add),
              title: Text("New Contact"),
            ),
            ListTile(leading: Icon(Icons.group), title: Text("New Community")),
            SizedBox(height: 10),
          ],
        );
      },
    );
  }
}

class AccountScreen extends StatelessWidget {
  final VoidCallback onHomeTap;

  const AccountScreen({super.key, required this.onHomeTap});

  Future<Map<String, dynamic>?> getProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) return null;

    return await supabase.from('profiles').select().eq('id', user.id).single();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      /// 🔹 APP BAR
      appBar: AppBar(
        title: const Text("Account"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),

      body: FutureBuilder(
        future: getProfile(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data;

          return Column(
            children: [
              const SizedBox(height: 20),

              /// 🔥 PROFILE SECTION
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      child: Icon(Icons.person, size: 40),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      profile?['username'] ?? "User",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "VibeChat User",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// 🔥 MENU LIST
              _menuItem(
                Icons.person,
                "Edit Profile",
                onTap: () async {
                  try {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EditProfileScreen()),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Some Error')));
                  }
                },
              ),
              _menuItem(Icons.lock, "Privacy"),
              _menuItem(Icons.notifications, "Notifications"),
              _menuItem(Icons.storage, "Storage & Data"),

              /// 🔥 LOGOUT
              _menuItem(
                Icons.logout,
                "Logout",
                isRed: true,
                onTap: () async {
                  try {
                    await supabase.auth.signOut();

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Logout failed: $e")),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),

      /// 🔹 OLD STYLE BOTTOM BAR
      bottomNavigationBar: _bottomBar(),
    );
  }

  /// ================= MENU ITEM =================
  Widget _menuItem(
    IconData icon,
    String title, {
    bool isRed = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: ListTile(
          leading: Icon(icon, color: isRed ? Colors.red : Colors.black),
          title: Text(
            title,
            style: TextStyle(color: isRed ? Colors.red : Colors.black),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
      ),
    );
  }

  /// ================= BOTTOM BAR =================
  Widget _bottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          height: 65,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(35),
            boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.home, color: Colors.grey),
                onPressed: onHomeTap,
              ),
              const SizedBox(width: 80),
              const Icon(Icons.person, color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String username;
  final String conversationId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.username,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();

  Stream<List<Map<String, dynamic>>> getMessages() {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .order('created_at');
  }

  Future<void> sendMessage() async {
    final user = supabase.auth.currentUser;

    if (controller.text.trim().isEmpty) return;

    await supabase.from('messages').insert({
      'conversation_id': widget.conversationId,
      'sender_id': user?.id,
      'content': controller.text.trim(),
    });

    await supabase
        .from('conversations')
        .update({
          'last_message': controller.text.trim(),
          'last_message_time': DateTime.now().toIso8601String(),
        })
        .eq('id', widget.conversationId);

    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],

      /// 🔹 APP BAR
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(widget.username),
      ),

      body: Column(
        children: [
          /// 🔥 MESSAGES
          Expanded(
            child: StreamBuilder(
              stream: getMessages(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == currentUser?.id;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 250),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          msg['content'] ?? "",
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          /// 🔥 INPUT BOX
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                /// SEND BUTTON
                GestureDetector(
                  onTap: sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ImageStoryScreen extends StatelessWidget {
  final String url;

  const ImageStoryScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: Image.network(url)),
    );
  }
}

class VideoStoryScreen extends StatefulWidget {
  final String url;

  const VideoStoryScreen({super.key, required this.url});

  @override
  State<VideoStoryScreen> createState() => _VideoStoryScreenState();
}

class _VideoStoryScreenState extends State<VideoStoryScreen> {
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() {});
        controller.play();
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
