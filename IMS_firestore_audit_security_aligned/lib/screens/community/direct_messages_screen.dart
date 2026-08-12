import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/conversation_service.dart';

class DirectMessagesScreen extends StatelessWidget {
  const DirectMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final service = ConversationService();
    return Scaffold(
      appBar: AppBar(title: const Text('Direct Messages')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserSearchScreen()),
              ),
              icon: const Icon(Icons.person_search),
              label: const Text('Start a conversation'),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: service.conversations(userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final conversations = snapshot.data!.docs.toList()
                  ..sort(
                    (a, b) =>
                        ((b.data()['lastMessageTime'] as Timestamp?)
                                    ?.millisecondsSinceEpoch ??
                                0)
                            .compareTo(
                              (a.data()['lastMessageTime'] as Timestamp?)
                                      ?.millisecondsSinceEpoch ??
                                  0,
                            ),
                  );
                if (conversations.isEmpty) {
                  return const Center(child: Text('No conversations yet.'));
                }
                return ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final data = conversations[index].data();
                    final peerId = (data['participants'] as List)
                        .cast<String>()
                        .firstWhere((id) => id != userId, orElse: () => userId);
                    return FutureBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(peerId)
                          .get(),
                      builder: (context, peer) {
                        final peerData = peer.data?.data() ?? {};
                        final name = peerData['name'] ?? 'Member';
                        final hasUnread = data['lastSender'] != userId;
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              name.toString().isEmpty
                                  ? 'M'
                                  : name.toString()[0].toUpperCase(),
                            ),
                          ),
                          title: Text(name),
                          subtitle: Text(data['lastMessage'] ?? ''),
                          trailing: hasUnread
                              ? const Badge(
                                  child: Icon(Icons.mark_chat_unread_outlined),
                                )
                              : null,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ConversationScreen(
                                peerId: peerId,
                                peerName: name.toString(),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class UserSearchScreen extends StatelessWidget {
  const UserSearchScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Start Conversation')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data!.docs
              .where((doc) => doc.id != currentUserId)
              .toList();
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final data = user.data();
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(data['name'] ?? 'Member'),
                subtitle: Text(data['role'] ?? ''),
                trailing: const Icon(Icons.chat_bubble_outline),
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConversationScreen(
                      peerId: user.id,
                      peerName: (data['name'] ?? 'Member').toString(),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.peerId,
    required this.peerName,
  });
  final String peerId;
  final String peerName;
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _service = ConversationService();
  final _controller = TextEditingController();
  late final String _me;
  late final String _conversationId;
  @override
  void initState() {
    super.initState();
    _me = FirebaseAuth.instance.currentUser!.uid;
    _conversationId = _service.idFor(_me, widget.peerId);
  }

  @override
  void dispose() {
    _service.setTyping(_conversationId, _me, false);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.peerName)),
    body: Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _service.messages(_conversationId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                // When conversation doc does not exist yet or permission pending
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No messages yet. Send the first message!',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data?.docs ?? [];

              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No messages yet. Send the first message!',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }

              _service.markRead(_conversationId, _me);

              return ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final data = messages[index].data();
                  final mine = data['senderId'] == _me;
                  return Align(
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Card(
                      color: mine
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(data['text'] ?? ''),
                            if (mine)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Icon(
                                  data['read'] == true
                                      ? Icons.done_all
                                      : Icons.done,
                                  size: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: (value) => _service.setTyping(
                      _conversationId,
                      _me,
                      value.isNotEmpty,
                    ),
                    decoration: const InputDecoration(hintText: 'Message'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    await _service.send(
                      senderId: _me,
                      recipientId: widget.peerId,
                      text: _controller.text,
                    );
                    _controller.clear();
                    await _service.setTyping(_conversationId, _me, false);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
