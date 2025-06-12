import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus {
  sending, // Message is being sent
  sent, // Message has been sent to server
  delivered, // Message has been delivered to recipient
  read, // Message has been read by recipient
  failed // Message failed to send
}

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final MessageStatus status;
  final bool isOffline;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.sending,
    this.isOffline = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': timestamp,
      'status': status.toString(),
      'isOffline': isOffline,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    // Handle timestamp conversion safely
    DateTime messageTimestamp;
    if (map['timestamp'] is Timestamp) {
      messageTimestamp = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is String) {
      messageTimestamp = DateTime.parse(map['timestamp']);
    } else {
      messageTimestamp = DateTime.now();
    }

    // Handle status conversion safely
    MessageStatus messageStatus;
    try {
      messageStatus = MessageStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => MessageStatus.sending,
      );
    } catch (e) {
      messageStatus = MessageStatus.sending;
    }

    return MessageModel(
      id: map['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: map['senderId']?.toString() ?? '',
      receiverId: map['receiverId']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      timestamp: messageTimestamp,
      status: messageStatus,
      isOffline: map['isOffline'] as bool? ?? false,
    );
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    DateTime? timestamp,
    MessageStatus? status,
    bool? isOffline,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}
