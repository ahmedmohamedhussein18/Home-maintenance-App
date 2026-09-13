import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class RequestChatScreen extends StatefulWidget {
  final bool isEnglish;
  final String requestId;
  final String otherPartyName;

  const RequestChatScreen({
    super.key,
    required this.isEnglish,
    required this.requestId,
    required this.otherPartyName,
  });

  @override
  State<RequestChatScreen> createState() => _RequestChatScreenState();
}

class _RequestChatScreenState extends State<RequestChatScreen> {
  late final DatabaseReference _messagesRef;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _messagesRef = FirebaseDatabase.instance
        .ref('service_requests')
        .child(widget.requestId)
        .child('messages');
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _messageController.clear();

    await _messagesRef.push().set({
      'senderId': userId,
      'text': text,
      'sentAt': DateTime.now().millisecondsSinceEpoch,
    });

    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherPartyName), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _messagesRef.onValue,
              builder: (context, snapshot) {
                final List<Map<String, dynamic>> messages = [];
                final data = snapshot.data?.snapshot.value;
                if (data != null && data is Map) {
                  data.forEach((key, value) {
                    messages.add(Map<String, dynamic>.from(value as Map));
                  });
                }
                messages.sort((a, b) {
                  final aTime = a['sentAt'] as int? ?? 0;
                  final bTime = b['sentAt'] as int? ?? 0;
                  return bTime.compareTo(aTime);
                });

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      widget.isEnglish
                          ? 'No messages yet. Say hello!'
                          : 'مفيش رسائل لسه. ابدأ المحادثة!',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMine = msg['senderId'] == myId;
                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Colors.blue
                              : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          msg['text'] ?? '',
                          style: TextStyle(color: isMine ? Colors.white : null),
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
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: widget.isEnglish
                            ? 'Type a message...'
                            : 'اكتب رسالة...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
