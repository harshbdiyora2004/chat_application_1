import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';

class LocalStorageService {
  static const String _offlineMessagesKey = 'offline_messages';
  static const String _lastSyncTimestampKey = 'last_sync_timestamp';

  // Save message to local storage
  static Future<void> saveOfflineMessage(MessageModel message) async {
    final prefs = await SharedPreferences.getInstance();
    final offlineMessages = await getOfflineMessages();

    offlineMessages.add(message);

    final messagesJson =
        offlineMessages.map((msg) => jsonEncode(msg.toMap())).toList();

    await prefs.setStringList(_offlineMessagesKey, messagesJson);
  }

  // Get all offline messages
  static Future<List<MessageModel>> getOfflineMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final messagesJson = prefs.getStringList(_offlineMessagesKey) ?? [];

    return messagesJson
        .map((json) => MessageModel.fromMap(jsonDecode(json)))
        .toList();
  }

  // Remove message from offline storage
  static Future<void> removeOfflineMessage(String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    final offlineMessages = await getOfflineMessages();

    offlineMessages.removeWhere((msg) => msg.id == messageId);

    final messagesJson =
        offlineMessages.map((msg) => jsonEncode(msg.toMap())).toList();

    await prefs.setStringList(_offlineMessagesKey, messagesJson);
  }

  // Update message status
  static Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final offlineMessages = await getOfflineMessages();

    final index = offlineMessages.indexWhere((msg) => msg.id == messageId);
    if (index != -1) {
      offlineMessages[index] = offlineMessages[index].copyWith(status: status);

      final messagesJson =
          offlineMessages.map((msg) => jsonEncode(msg.toMap())).toList();

      await prefs.setStringList(_offlineMessagesKey, messagesJson);
    }
  }

  // Save last sync timestamp
  static Future<void> saveLastSyncTimestamp(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncTimestampKey, timestamp.toIso8601String());
  }

  // Get last sync timestamp
  static Future<DateTime?> getLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampStr = prefs.getString(_lastSyncTimestampKey);
    if (timestampStr == null) return null;
    return DateTime.parse(timestampStr);
  }

  // Clear all offline messages
  static Future<void> clearOfflineMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offlineMessagesKey);
  }
}
