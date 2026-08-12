import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'group_info_screen.dart';

class AppChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;

  const AppChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
  });

  @override
  State<AppChatScreen> createState() => _AppChatScreenState();
}

class _AppChatScreenState extends State<AppChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _updateTypingStatus(false);
    super.dispose();
  }

  void _onTextChanged() {
    if (_messageController.text.isNotEmpty && !_isTyping) {
      _updateTypingStatus(true);
    } else if (_messageController.text.isEmpty && _isTyping) {
      _updateTypingStatus(false);
    }
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    if (currentUser == null) return;
    _isTyping = isTyping;
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set(
      {'typing_${currentUser!.uid}': isTyping},
      SetOptions(merge: true),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || currentUser == null) return;

    String text = _messageController.text.trim();
    _messageController.clear();
    _updateTypingStatus(false);

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
          'sender_id': currentUser!.uid,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'sent',
        });
  }

  void _markAsRead(String messageId) {
    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(messageId)
        .update({'status': 'read'});
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) return 'Today';
    if (msgDate == yesterday) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupInfoScreen(
                  groupId: widget.chatId,
                  groupName: widget.chatName,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chatName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.chatId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return Text(
                        'Tap here for group info',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      );
                    }

                    var data = snapshot.data!.data() as Map<String, dynamic>;
                    bool someoneIsTyping = data.entries.any(
                      (entry) =>
                          entry.key.startsWith('typing_') &&
                          entry.key != 'typing_${currentUser?.uid}' &&
                          entry.value == true,
                    );

                    if (someoneIsTyping) {
                      return Text(
                        'typing...',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      );
                    }
                    return Text(
                      'Tap here for group info',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
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
                          size: 64,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msg = messages[index].data() as Map<String, dynamic>;
                    String msgId = messages[index].id;
                    bool isMe = msg['sender_id'] == currentUser?.uid;
                    String status = msg['status'] ?? 'sent';

                    DateTime? currentDate = msg['timestamp'] != null
                        ? (msg['timestamp'] as Timestamp).toDate()
                        : null;
                    bool showDateHeader = false;

                    if (index == messages.length - 1) {
                      showDateHeader = true;
                    } else if (currentDate != null) {
                      var olderMsg =
                          messages[index + 1].data() as Map<String, dynamic>;
                      DateTime? olderDate = olderMsg['timestamp'] != null
                          ? (olderMsg['timestamp'] as Timestamp).toDate()
                          : null;

                      if (olderDate != null) {
                        if (currentDate.day != olderDate.day ||
                            currentDate.month != olderDate.month ||
                            currentDate.year != olderDate.year) {
                          showDateHeader = true;
                        }
                      }
                    }

                    if (!isMe && status != 'read') _markAsRead(msgId);

                    return Column(
                      children: [
                        if (showDateHeader && currentDate != null)
                          Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 8,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _getDateLabel(currentDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        _buildMessageBubble(msg, isMe, status, theme),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(theme),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    bool isMe,
    String status,
    ThemeData theme,
  ) {
    DateTime? time = msg['timestamp'] != null
        ? (msg['timestamp'] as Timestamp).toDate()
        : null;
    String timeString = time != null ? DateFormat('HH:mm').format(time) : '...';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe
                  ? const Radius.circular(16)
                  : const Radius.circular(4),
              bottomRight: isMe
                  ? const Radius.circular(4)
                  : const Radius.circular(16),
            ),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            alignment: WrapAlignment.end,
            children: [
              Text(
                msg['text'] ?? '',
                style: TextStyle(
                  fontSize: 15,
                  color: isMe
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeString,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? theme.colorScheme.onPrimary.withOpacity(0.7)
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildTickIcon(status, theme),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTickIcon(String status, ThemeData theme) {
    if (status == 'read') {
      return Icon(Icons.done_all, size: 14, color: theme.colorScheme.onPrimary);
    } else if (status == 'delivered') {
      return Icon(
        Icons.done_all,
        size: 14,
        color: theme.colorScheme.onPrimary.withOpacity(0.5),
      );
    } else {
      return Icon(
        Icons.done,
        size: 14,
        color: theme.colorScheme.onPrimary.withOpacity(0.5),
      );
    }
  }

  Widget _buildMessageInput(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 5,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              radius: 24,
              child: IconButton(
                icon: Icon(Icons.send, color: theme.colorScheme.onPrimary),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
