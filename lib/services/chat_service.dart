import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import 'local_storage_service.dart';
import 'connectivity_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectivityService _connectivityService = ConnectivityService();

  // Send message with offline support
  Future<void> sendMessage(MessageModel message) async {
    try {
      if (_connectivityService.isConnected) {
        // Send message to Firestore
        await _firestore
            .collection('chats')
            .doc(message.id)
            .collection('messages')
            .doc(message.id)
            .set({
          ...message.toMap(),
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Update chat metadata
        await _updateChatMetadata(message);

        // Update message status
        await LocalStorageService.updateMessageStatus(
          message.id,
          MessageStatus.sent,
        );
      } else {
        // Save to offline storage with current timestamp
        await LocalStorageService.saveOfflineMessage(
          message.copyWith(
            status: MessageStatus.sending,
            isOffline: true,
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      // If sending fails, save to offline storage
      await LocalStorageService.saveOfflineMessage(
        message.copyWith(
          status: MessageStatus.failed,
          isOffline: true,
          timestamp: DateTime.now(),
        ),
      );
      rethrow;
    }
  }

  // Update chat metadata
  Future<void> _updateChatMetadata(MessageModel message) async {
    try {
      final chatId = message.id;
      final timestamp = FieldValue.serverTimestamp();

      // Get user names
      final senderDoc =
          await _firestore.collection('users').doc(message.senderId).get();
      final receiverDoc =
          await _firestore.collection('users').doc(message.receiverId).get();

      final senderName = senderDoc.exists
          ? '${senderDoc.data()?['firstName'] ?? ''} ${senderDoc.data()?['lastName'] ?? ''}'
              .trim()
          : 'Unknown User';

      final receiverName = receiverDoc.exists
          ? '${receiverDoc.data()?['firstName'] ?? ''} ${receiverDoc.data()?['lastName'] ?? ''}'
              .trim()
          : 'Unknown User';

      final senderProfilePic = senderDoc.exists
          ? (senderDoc.data()?['profilePictureBase64'] as String?) ?? ''
          : '';
      final receiverProfilePic = receiverDoc.exists
          ? (receiverDoc.data()?['profilePictureBase64'] as String?) ?? ''
          : '';

      // Update sender's chat metadata
      await _firestore
          .collection('users')
          .doc(message.senderId)
          .collection('chats')
          .doc(chatId)
          .set({
        'lastMessage': message.content,
        'lastMessageTime': timestamp,
        'unreadCount': 0,
        'participant': {
          'uid': message.receiverId,
          'name': receiverName,
          'profilePic': receiverProfilePic,
        },
      });

      // Update receiver's chat metadata
      await _firestore
          .collection('users')
          .doc(message.receiverId)
          .collection('chats')
          .doc(chatId)
          .set({
        'lastMessage': message.content,
        'lastMessageTime': timestamp,
        'unreadCount': FieldValue.increment(1),
        'participant': {
          'uid': message.senderId,
          'name': senderName,
          'profilePic': senderProfilePic,
        },
      });
    } catch (e) {
      print('Error updating chat metadata: $e');
      rethrow;
    }
  }

  // Sync offline messages when connection is restored
  Future<void> syncOfflineMessages() async {
    if (!_connectivityService.isConnected) return;

    try {
      final offlineMessages = await LocalStorageService.getOfflineMessages();
      for (final message in offlineMessages) {
        try {
          await sendMessage(message);
          await LocalStorageService.removeOfflineMessage(message.id);
        } catch (e) {
          print('Error syncing message ${message.id}: $e');
          continue;
        }
      }
    } catch (e) {
      print('Error syncing offline messages: $e');
    }
  }

  // Get messages stream
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data()))
          .toList();
    });
  }

  // Mark message as read
  Future<void> markMessageAsRead(String chatId, String messageId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'status': MessageStatus.read.toString()});
    } catch (e) {
      print('Error marking message as read: $e');
      rethrow;
    }
  }
}
