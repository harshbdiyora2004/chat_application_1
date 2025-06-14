import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'individual_chat_screen.dart';
import 'dart:async';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  String? _currentUid;
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _chatsSubscription;
  List<DocumentSnapshot> _chats = [];

  @override
  void initState() {
    super.initState();
    _loadUid();
  }

  Future<void> _loadUid() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    if (uid != null) {
      setState(() {
        _currentUid = uid;
      });
      _setupChatsListener();
    }
  }

  void _setupChatsListener() {
    _chatsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUid)
        .collection('chats')
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .listen((snapshot) async {
      if (mounted) {
        List<DocumentSnapshot> validChats = [];

        // Check each chat for messages
        for (var doc in snapshot.docs) {
          final chatData = doc.data();
          final chatId = chatData['chatId'] as String;

          // Check if there are any messages in this chat
          final messagesSnapshot = await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .limit(1)
              .get();

          // If no messages exist, remove the chat entry for both users
          if (messagesSnapshot.docs.isEmpty) {
            final participant = chatData['participant'] as Map<String, dynamic>;
            final otherUserId = participant['uid'] as String;

            // Remove chat entry for current user
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUid)
                .collection('chats')
                .doc(chatId)
                .delete();

            // Remove chat entry for other user
            await FirebaseFirestore.instance
                .collection('users')
                .doc(otherUserId)
                .collection('chats')
                .doc(chatId)
                .delete();
          } else {
            // Only add chats that have messages to the valid chats list
            validChats.add(doc);
          }
        }

        setState(() {
          _chats = validChats;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color textColor = Colors.black87;
    const Color dividerColor = Color(0xFFE0E0E0);

    if (_currentUid == null) {
      // Try to reload UID after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _loadUid();
      });
      return const Center(child: CircularProgressIndicator());
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chats.isEmpty) {
      return const Center(child: Text('No chats yet'));
    }

    return ListView.builder(
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index].data() as Map<String, dynamic>;
        final participant = chat['participant'] ?? {};
        final lastMessage = chat['lastMessage'] ?? '';
        final lastMessageTime = chat['lastMessageTime'] as Timestamp?;

        if (participant['uid'] == _currentUid) {
          // Skip showing chat with self
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            ListTile(
              leading: participant['profilePic'] != null &&
                      participant['profilePic'] != ''
                  ? CircleAvatar(
                      backgroundImage:
                          MemoryImage(base64Decode(participant['profilePic'])),
                    )
                  : const CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                participant['uid'] == _currentUid
                    ? '${participant['name']} (you)'
                    : participant['name'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              subtitle: Text(
                lastMessage,
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lastMessageTime != null)
                    Text(
                      DateFormat('hh:mm a').format(lastMessageTime.toDate()),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  if ((chat['unreadCount'] ?? 0) > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${chat['unreadCount']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IndividualChatScreen(
                      receiverUid: participant['uid'],
                      receiverName: participant['name'] ?? '',
                      receiverProfilePic: participant['profilePic'],
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 1, color: dividerColor),
          ],
        );
      },
    );
  }
}
