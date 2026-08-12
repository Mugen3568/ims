import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;
  String _currentUserName = 'Unknown';

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  // Fetch the sender's name once to attach it to their messages
  Future<void> _fetchUserName() async {
    if (currentUser != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _currentUserName = doc.data()?['name'] ?? 'User';
        });
      }
    }
  }

  void _sendMessage() async {
    String text = _messageController.text.trim();
    if (text.isEmpty || currentUser == null) return;

    _messageController.clear();

    // Store message INSIDE the specific group's subcollection
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .add({
      'text': text,
      'senderId': currentUser!.uid,
      'senderName': _currentUserName,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent', // For the double-tick UI
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.groupName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Text('Batch Chat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'Batch Members',
            onPressed: () {
              // Optional: Show batch members list
              _showBatchMembers();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // MESSAGES LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // CRITICAL: Order by timestamp descending to put recent messages at the bottom
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.groupId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Start the discussion!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                var messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true, // Forces the list to start from the bottom
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var data = messages[index].data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == currentUser?.uid;
                    String text = data['text'] ?? '';
                    String senderName = data['senderName'] ?? 'User';
                    Timestamp? time = data['timestamp'] as Timestamp?;
                    String timeStr = time != null ? DateFormat('hh:mm a').format(time.toDate()) : 'Now';

                    return _buildMessageBubble(text, senderName, timeStr, isMe, theme);
                  },
                );
              },
            ),
          ),

          // INPUT FIELD AREA
          _buildInputArea(theme),
        ],
      ),
    );
  }

  // E-Sekula Styled Message Bubble
  Widget _buildMessageBubble(String text, String senderName, String time, bool isMe, ThemeData theme) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMe ? theme.colorScheme.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(24),
            topRight: const Radius.circular(24),
            bottomLeft: isMe ? const Radius.circular(24) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(24),
          ),
          border: isMe ? null : Border.all(color: theme.colorScheme.primary, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Text(
                senderName,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.black : theme.colorScheme.onSurface,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: isMe ? Colors.black54 : Colors.grey,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all, size: 14, color: Colors.black54), // Double-tick read receipt
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  // E-Sekula Pill-Shaped Input (No Paperclip)
  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12).copyWith(bottom: 24),
      color: theme.scaffoldBackgroundColor,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primary,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _showBatchMembers() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var groupData = snapshot.data!.data() as Map<String, dynamic>?;
            List<dynamic> memberIds = groupData?['members'] ?? [];

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Batch Members (${memberIds.length})',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: memberIds.length,
                      itemBuilder: (context, index) {
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(memberIds[index])
                              .get(),
                          builder: (context, userSnap) {
                            if (!userSnap.hasData) {
                              return const ListTile(
                                leading: CircleAvatar(child: Icon(Icons.person)),
                                title: Text('Loading...'),
                              );
                            }

                            var userData = userSnap.data!.data() as Map<String, dynamic>?;
                            String name = userData?['name'] ?? 'Unknown';
                            String role = userData?['role'] ?? 'student';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Text(
                                  name[0].toUpperCase(),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(name),
                              subtitle: Text(role.toUpperCase()),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
