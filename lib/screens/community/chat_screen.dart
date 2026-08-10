import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/chat_service.dart';

class ChatScreen extends StatelessWidget {
  final String chatId;
  final String currentUserId;
  final String currentUserName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    final ChatService chatService = ChatService();
    final TextEditingController messageController = TextEditingController();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community & Batch Chat'),
      ),
      body: Column(
        children: [
          // Message List Stream with Lazy Loading
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatService.getMessages(chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start the conversation!'),
                  );
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true, // Start from bottom like modern chat apps
                  itemCount: messages.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    bool isMe = data['sender_id'] == currentUserId;
                    String senderName = data['sender_name'] ?? 'User';
                    String messageText = data['message'] ?? '';
                    String imageUrl = data['image_url'] ?? '';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                senderName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            if (!isMe) const SizedBox(height: 4),
                            if (messageText.isNotEmpty)
                              Text(
                                messageText,
                                style: TextStyle(
                                  color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                                ),
                              ),
                            if (imageUrl.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(imageUrl, height: 150, width: double.infinity, fit: BoxFit.cover),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Message Input Bar
          Container(
            padding: const EdgeInsets.all(8.0),
            color: theme.colorScheme.surface,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: () {
                    // Hook into Cloudinary free API for image picking & uploading
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cloudinary Image Attachment integration point.')),
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: theme.colorScheme.primary,
                  onPressed: () {
                    if (messageController.text.trim().isNotEmpty) {
                      chatService.sendMessage(
                        chatId: chatId,
                        senderId: currentUserId,
                        senderName: currentUserName,
                        message: messageController.text.trim(),
                      );
                      messageController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
