// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/presence_service.dart';
import 'dart:async';
import 'image_viewer_screen.dart';

class IndividualChatScreen extends StatefulWidget {
  final String receiverUid;
  final String receiverName;
  final String? receiverProfilePic;

  const IndividualChatScreen({
    super.key,
    required this.receiverUid,
    required this.receiverName,
    this.receiverProfilePic,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  late String _currentUid = '';
  late String _chatId = '';
  bool _isSending = false;
  bool _isInitialized = false;
  bool _isUploadingImage = false;
  String? _pendingImageBase64;
  String? _pendingImageCaption;
  StreamSubscription<QuerySnapshot>? _messageSubscription;
  List<DocumentSnapshot> _messages = [];
  bool _isLoading = true;
  bool _hasMoreMessages = true;
  final int _pageSize = 20;
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  static const int _maxLoadedMessages = 100;
  DateTime? _oldestLoadedMessageDate;

  @override
  void initState() {
    super.initState();
    _initUidAndChatId();
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 100) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (!_hasMoreMessages || _isLoadingMore || _messages.isEmpty) return;

    setState(() => _isLoadingMore = true);

    try {
      if (_oldestLoadedMessageDate != null &&
          DateTime.now().difference(_oldestLoadedMessageDate!).inDays > 30) {
        await _archiveOldMessages();
      }

      final query = FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMoreMessages = false;
          _isLoadingMore = false;
        });
        return;
      }

      setState(() {
        _messages.insertAll(0, snapshot.docs.reversed);
        _lastDocument = snapshot.docs.last;
        if (snapshot.docs.isNotEmpty) {
          _oldestLoadedMessageDate =
              (snapshot.docs.last.data()['timestamp'] as Timestamp).toDate();
        }
        _isLoadingMore = false;
      });

      _cleanupOldMessages();
    } catch (e) {
      setState(() => _isLoadingMore = false);
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading more messages: $e')),
          );
        });
      }
    }
  }

  void _setupMessageListener() {
    if (_chatId.isEmpty) {
      log('Error: Chat ID is empty');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to initialize chat. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        });
      }
      return;
    }

    _messageSubscription?.cancel();

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    _messageSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('timestamp', descending: true)
        .limit(_pageSize)
        .snapshots()
        .listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            _messages = snapshot.docs.reversed.toList();
            _lastDocument =
                snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
            if (snapshot.docs.isNotEmpty) {
              _oldestLoadedMessageDate =
                  (snapshot.docs.last.data()['timestamp'] as Timestamp)
                      .toDate();
            }
            _isLoading = false;
          });
          _updateMessageStatuses();
          _cleanupOldMessages();
          if (_messages.isNotEmpty) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _scrollToBottom());
          }
        }
      },
      onError: (error) {
        log('Error in message listener: $error');
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading messages: $error'),
                backgroundColor: Colors.red,
              ),
            );
          });
        }
      },
    );
  }

  void _updateMessageStatuses() {
    for (final doc in _messages) {
      _updateMessageStatus(doc);
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _inputFocusNode.dispose();
    _resetUnreadCount();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _resetUnreadCount() async {
    // ignore: unnecessary_null_comparison
    if (_currentUid != null && _chatId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('chats')
          .doc(_chatId)
          .set({'unreadCount': 0}, SetOptions(merge: true));
    }
  }

  Future<void> _initUidAndChatId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (uid == null || uid.isEmpty) {
        throw Exception('User ID not found');
      }

      if (widget.receiverUid.isEmpty) {
        throw Exception('Receiver ID is empty');
      }

      setState(() {
        _currentUid = uid;
        _chatId = _getChatId(_currentUid, widget.receiverUid);
        _isInitialized = true;
      });

      log('DEBUG: _currentUid = $_currentUid');
      log('DEBUG: receiverUid = ${widget.receiverUid}');
      log('DEBUG: chatId = $_chatId');

      if (_chatId.isEmpty) {
        throw Exception('Failed to generate chat ID');
      }

      // Reset unread count when opening chat
      await _resetUnreadCount();
      // Only now, after _chatId is set, set up the message listener
      _setupMessageListener();
    } catch (e) {
      log('Error initializing chat: $e');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to initialize chat. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        });
      }
    }
  }

  String _getChatId(String uid1, String uid2) {
    if (uid1.isEmpty || uid2.isEmpty) {
      return '';
    }
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_pendingImageBase64 != null) {
      final imageToSend = _pendingImageBase64!;
      final captionToSend = _pendingImageCaption;
      setState(() {
        _pendingImageBase64 = null;
        _pendingImageCaption = null;
      });
      await _sendImageMessageBase64(imageToSend, captionToSend);
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });
    _messageController.clear();

    try {
      final timestamp = Timestamp.now();
      final messageRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .doc();

      // Fetch current user's info from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .get();
      final userData = userDoc.data() ?? {};
      final myName =
          ((userData['firstName'] ?? '') + ' ' + (userData['lastName'] ?? ''))
              .trim();
      final myProfilePic = userData['profilePictureBase64'] ?? '';

      // Optimize by using a single batch write
      final batch = FirebaseFirestore.instance.batch();

      // Add message
      batch.set(messageRef, {
        'senderId': _currentUid,
        'receiverId': widget.receiverUid,
        'text': text,
        'timestamp': timestamp,
        'status': 'sent',
      });

      // Update chat metadata
      final myChatRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('chats')
          .doc(_chatId);
      final theirChatRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.receiverUid)
          .collection('chats')
          .doc(_chatId);

      batch.set(
          myChatRef,
          {
            'chatId': _chatId,
            'lastMessage': text,
            'lastMessageTime': timestamp,
            'participant': {
              'uid': widget.receiverUid,
              'name': widget.receiverName,
              'profilePic': widget.receiverProfilePic ?? '',
            },
            'unreadCount': 0,
          },
          SetOptions(merge: true));

      batch.set(
          theirChatRef,
          {
            'chatId': _chatId,
            'lastMessage': text,
            'lastMessageTime': timestamp,
            'participant': {
              'uid': _currentUid,
              'name': myName,
              'profilePic': myProfilePic,
            },
            'unreadCount': FieldValue.increment(1),
          },
          SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      log('Error sending message: $e');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send message: $e'),
              backgroundColor: Colors.red,
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
      _scrollToBottom();
    }
  }

  void _updateMessageStatus(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    if (data['receiverId'] == _currentUid && data['status'] == 'sent') {
      final msgRef = doc.reference;
      await msgRef.update({'status': 'delivered'});
    }
    if (data['receiverId'] == _currentUid && data['status'] == 'delivered') {
      final msgRef = doc.reference;
      await msgRef.update({'status': 'read'});
    }
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final pickedFile = await picker.pickImage(
        source: source, imageQuality: 80, maxWidth: 1200);
    if (pickedFile == null) return;
    setState(() => _isUploadingImage = true);
    try {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Show preview screen with direct send functionality
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImagePreviewScreen(
            base64Image: base64Image,
            onSend: (imageBase64, caption) async {
              await _sendImageMessageBase64(imageBase64, caption);
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select image: $e')),
      );
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _sendImageMessageBase64(String base64Image,
      [String? caption]) async {
    final timestamp = Timestamp.now();
    final messageRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .doc();
    try {
      await messageRef.set({
        'senderId': _currentUid,
        'receiverId': widget.receiverUid,
        'imageBase64': base64Image,
        'caption': caption ?? '',
        'timestamp': timestamp,
        'status': 'sent',
        'type': 'image',
      });
      // Fetch current user's info from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .get();
      final userData = userDoc.data() ?? {};
      final myName =
          ((userData['firstName'] ?? '') + ' ' + (userData['lastName'] ?? ''))
              .trim();
      final myProfilePic = userData['profilePictureBase64'] ?? '';
      // Update chat metadata for both users
      final myChatRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('chats')
          .doc(_chatId);
      final theirChatRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.receiverUid)
          .collection('chats')
          .doc(_chatId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final theirChatSnap = await transaction.get(theirChatRef);
        int unreadCount = 0;
        if (theirChatSnap.exists &&
            theirChatSnap.data() != null &&
            theirChatSnap.data()!.containsKey('unreadCount')) {
          unreadCount = theirChatSnap['unreadCount'] ?? 0;
        }
        transaction.set(myChatRef, {
          'chatId': _chatId,
          'lastMessage': '[Image]',
          'lastMessageTime': timestamp,
          'participant': {
            'uid': widget.receiverUid,
            'name': widget.receiverName,
            'profilePic': widget.receiverProfilePic ?? '',
          },
          'unreadCount': 0,
        });
        transaction.set(theirChatRef, {
          'chatId': _chatId,
          'lastMessage': '[Image]',
          'lastMessageTime': timestamp,
          'participant': {
            'uid': _currentUid,
            'name': myName,
            'profilePic': myProfilePic,
          },
          'unreadCount': unreadCount + 1,
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send image: $e')),
      );
    }
  }

  Future<void> _deleteMessageForMe(DocumentSnapshot messageDoc) async {
    try {
      final data = messageDoc.data() as Map<String, dynamic>;
      List<String> deletedFor = List<String>.from(data['deletedFor'] ?? []);
      deletedFor.add(_currentUid);
      await messageDoc.reference.update({
        'deletedFor': deletedFor,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $e')),
        );
      }
    }
  }

  Future<void> _deleteMessageForEveryone(DocumentSnapshot messageDoc) async {
    try {
      await messageDoc.reference.delete();

      // Check if this was the last message and update chat metadata
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messagesSnapshot.docs.isEmpty) {
        // If no messages left, delete chat entries for both users
        final batch = FirebaseFirestore.instance.batch();

        batch.delete(FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUid)
            .collection('chats')
            .doc(_chatId));

        batch.delete(FirebaseFirestore.instance
            .collection('users')
            .doc(widget.receiverUid)
            .collection('chats')
            .doc(_chatId));

        await batch.commit();
      } else {
        // Update last message in chat metadata for both users
        final lastMessage = messagesSnapshot.docs.first.data();
        final batch = FirebaseFirestore.instance.batch();

        final updateData = {
          'lastMessage':
              lastMessage['type'] == 'image' ? '[Image]' : lastMessage['text'],
          'lastMessageTime': lastMessage['timestamp'],
        };

        batch.update(
            FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUid)
                .collection('chats')
                .doc(_chatId),
            updateData);

        batch.update(
            FirebaseFirestore.instance
                .collection('users')
                .doc(widget.receiverUid)
                .collection('chats')
                .doc(_chatId),
            updateData);

        await batch.commit();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $e')),
        );
      }
    }
  }

  void _showDeleteDialog(DocumentSnapshot messageDoc) {
    final data = messageDoc.data() as Map<String, dynamic>;
    final isMe = data['senderId'] == _currentUid;
    final messageTime = (data['timestamp'] as Timestamp).toDate();
    final now = DateTime.now();
    final difference = now.difference(messageTime);
    final canDeleteForEveryone = isMe &&
        difference.inHours <
            24; // Can delete for everyone if message is less than 24 hours old

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canDeleteForEveryone)
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text('Delete for Everyone'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessageForEveryone(messageDoc);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete for Me'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessageForMe(messageDoc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, DocumentSnapshot doc) {
    // Check if message is deleted for current user
    final List<String> deletedFor = List<String>.from(data['deletedFor'] ?? []);
    if (deletedFor.contains(_currentUid)) {
      return const SizedBox.shrink(); // Don't show deleted messages
    }

    final status = data['status'] ?? 'sent';
    IconData? tickIcon;
    Color? tickColor;
    if (data['senderId'] == _currentUid) {
      if (status == 'sent') {
        tickIcon = Icons.check;
        tickColor = Colors.grey;
      } else if (status == 'delivered') {
        tickIcon = Icons.done_all;
        tickColor = Colors.grey;
      } else if (status == 'read') {
        tickIcon = Icons.done_all;
        tickColor = Colors.blue;
      }
    }
    String timeString = '';
    if (data['timestamp'] != null) {
      final ts = data['timestamp'];
      DateTime dt;
      if (ts is Timestamp) {
        dt = ts.toDate();
      } else if (ts is DateTime) {
        dt = ts;
      } else {
        dt = DateTime.now();
      }
      timeString = DateFormat('hh:mm a').format(dt);
    }
    final isImage = data['type'] == 'image' && data['imageBase64'] != null;
    final isMe = data['senderId'] == _currentUid;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _showDeleteDialog(doc),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              padding: isImage
                  ? const EdgeInsets.all(6)
                  : const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF1A237E) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMe
                      ? const Radius.circular(18)
                      : const Radius.circular(6),
                  bottomRight: isMe
                      ? const Radius.circular(6)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isImage
                  ? Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ImageViewerScreen(
                                  base64Image: data['imageBase64'],
                                  caption: data['caption'],
                                  senderName:
                                      isMe ? 'You' : widget.receiverName,
                                  timestamp:
                                      (data['timestamp'] as Timestamp).toDate(),
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(data['imageBase64']),
                              width: 180,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if ((data['caption'] ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 6, left: 4, right: 4),
                            child: Text(
                              data['caption'],
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            data['text'] ?? '',
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (isMe && tickIcon != null) ...[
                          const SizedBox(width: 8),
                          Icon(tickIcon, size: 18, color: tickColor),
                        ]
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 2),
            child: Text(
              timeString,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to start the conversation',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFe3eafc), Color(0xFFf5f7fa)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
        ),
      ),
    );
  }

  String _getDateHeader(DateTime messageDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDay =
        DateTime(messageDate.year, messageDate.month, messageDate.day);

    if (messageDay == today) {
      return 'Today';
    } else if (messageDay == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, y').format(messageDate);
    }
  }

  Widget _buildDateSeparator(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Colors.grey.withOpacity(0.3),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: Colors.grey.withOpacity(0.3),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  void _cleanupOldMessages() {
    if (_messages.length > _maxLoadedMessages) {
      _messages =
          _messages.skip(_messages.length - _maxLoadedMessages).toList();
      _oldestLoadedMessageDate =
          (_messages.first.data() as Map<String, dynamic>)['timestamp']
              .toDate();
    }
  }

  Future<void> _archiveOldMessages() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final oldMessages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      if (oldMessages.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in oldMessages.docs) {
        final archiveRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(_chatId)
            .collection('archived_messages')
            .doc(doc.id);

        batch.set(archiveRef, doc.data());
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      log('Error archiving old messages: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFFe3eafc),
        body: _buildLoadingState(),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        await _resetUnreadCount();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A237E),
          elevation: 0,
          title: Row(
            children: [
              widget.receiverProfilePic != null
                  ? CircleAvatar(
                      backgroundImage: MemoryImage(
                        base64Decode(widget.receiverProfilePic!),
                      ),
                      radius: 22,
                    )
                  : const CircleAvatar(radius: 22, child: Icon(Icons.person)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.receiverName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  StreamBuilder<String>(
                    stream:
                        PresenceService.getUserStatusStream(widget.receiverUid),
                    builder: (context, snapshot) {
                      final isOnline = snapshot.data == 'online';
                      return isOnline
                          ? Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const Text(
                                  'Online',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFe3eafc), Color(0xFFf5f7fa)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 100),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _messages.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount:
                                _messages.length + (_hasMoreMessages ? 1 : 0),
                            padding: const EdgeInsets.only(bottom: 16, top: 8),
                            itemBuilder: (context, index) {
                              if (index == 0 && _hasMoreMessages) {
                                return _isLoadingMore
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    : const SizedBox.shrink();
                              }

                              final actualIndex =
                                  index - (_hasMoreMessages ? 1 : 0);
                              final messageDoc = _messages[actualIndex];
                              final data =
                                  messageDoc.data() as Map<String, dynamic>;
                              final currentMessageDate =
                                  (data['timestamp'] as Timestamp).toDate();

                              // Show date separator if this is the first message or if the date changes
                              Widget? dateSeparator;
                              if (actualIndex == 0) {
                                dateSeparator = _buildDateSeparator(
                                    _getDateHeader(currentMessageDate));
                              } else {
                                final previousData = _messages[actualIndex - 1]
                                    .data() as Map<String, dynamic>;
                                final previousDate =
                                    (previousData['timestamp'] as Timestamp)
                                        .toDate();
                                if (DateTime(
                                        currentMessageDate.year,
                                        currentMessageDate.month,
                                        currentMessageDate.day) !=
                                    DateTime(previousDate.year,
                                        previousDate.month, previousDate.day)) {
                                  dateSeparator = _buildDateSeparator(
                                      _getDateHeader(currentMessageDate));
                                }
                              }

                              return Column(
                                children: [
                                  if (dateSeparator != null) dateSeparator,
                                  _buildMessageBubble(data, messageDoc),
                                ],
                              );
                            },
                          ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                color: Colors.transparent,
                child: Row(
                  children: [
                    IconButton(
                      icon: _isUploadingImage
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo, color: Color(0xFF1A237E)),
                      onPressed: _isUploadingImage ? null : _pickAndSendImage,
                    ),
                    if (_pendingImageBase64 != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                base64Decode(_pendingImageBase64!),
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _pendingImageBase64 = null;
                                _pendingImageCaption = null;
                              }),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          focusNode: _inputFocusNode,
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 18, vertical: 14),
                          ),
                          minLines: 1,
                          maxLines: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap:
                          _isSending || _isUploadingImage ? null : _sendMessage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isSending || _isUploadingImage
                              ? Colors.grey
                              : const Color(0xFF1A237E),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _isSending || _isUploadingImage
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.send,
                                color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImagePreviewScreen extends StatefulWidget {
  final String base64Image;
  final Function(String, String?) onSend;

  const ImagePreviewScreen({
    super.key,
    required this.base64Image,
    required this.onSend,
  });

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Image.memory(
                  base64Decode(widget.base64Image),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Container(
              color: Colors.black,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _captionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add a caption (optional)...',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.7)),
                        border: InputBorder.none,
                        prefixIcon:
                            const Icon(Icons.edit, color: Colors.white54),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending
                        ? null
                        : () {
                            setState(() => _isSending = true);
                            widget.onSend(
                              widget.base64Image,
                              _captionController.text.trim(),
                            );
                            Navigator.pop(context);
                          },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isSending ? Colors.grey : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
