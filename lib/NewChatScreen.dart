import 'package:flutter/material.dart';
import 'package:vibechat/main.dart';

class NewChatScreen extends StatelessWidget {
  const NewChatScreen({super.key});

  Future<List> getUsers() async {
    return await supabase.from('profiles').select();
  }

Future<void> createChat(
  BuildContext context,
  String otherUserId,
  String username,
) async {
  final currentUser = supabase.auth.currentUser!;
  final navigator = Navigator.of(context); // ✅ store early

  final myChats = await supabase
      .from('conversation_participants')
      .select('conversation_id')
      .eq('user_id', currentUser.id);

  for (var chat in myChats) {
    final convoId = chat['conversation_id'];

    final exists = await supabase
        .from('conversation_participants')
        .select()
        .eq('conversation_id', convoId)
        .eq('user_id', otherUserId);

    if (exists.isNotEmpty) {
      if (!context.mounted) return; // 🔥 VERY IMPORTANT

      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: convoId,
            username: username,
          ),
        ),
      );
      return;
    }
  }

  final convo = await supabase
      .from('conversations')
      .insert({})
      .select()
      .single();

  final conversationId = convo['id'];

  await supabase.from('conversation_participants').insert([
    {
      'conversation_id': conversationId,
      'user_id': currentUser.id,
    },
    {
      'conversation_id': conversationId,
      'user_id': otherUserId,
    },
  ]);

  if (!context.mounted) return; // 

  navigator.pushReplacement(
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        conversationId: conversationId,
        username: username,
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final currentUser = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Select User")),
      body: FutureBuilder(
        future: getUsers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data as List;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];

              /// ❌ don't show yourself
              if (user['id'] == currentUser?.id) {
                return const SizedBox.shrink();
              }

              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(user['username'] ?? "User"),
                onTap: () => createChat(context, user['id'],user['username']??"user"),
              );
            },
          );
        },
      ),
    );
  }
}