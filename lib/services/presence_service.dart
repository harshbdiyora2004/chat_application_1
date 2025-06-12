import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class PresenceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Map<String, StreamController<String>> _statusControllers = {};
  static final Map<String, String> _statusCache = {};
  static Timer? _heartbeatTimer;
  static bool _isOnline = false;

  static void initialize() {
    _setupHeartbeat();
    _setupPresenceListener();
  }

  static void _setupHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_auth.currentUser != null) {
        _updatePresence(true);
      }
    });
  }

  static void _setupPresenceListener() {
    _firestore
        .collection('users')
        .doc(_auth.currentUser?.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          final isOnline = data['isOnline'] ?? false;
          _isOnline = isOnline;
          _notifyStatusChange(
              _auth.currentUser?.uid ?? '', isOnline ? 'online' : 'offline');
        }
      }
    });
  }

  static Future<void> _updatePresence(bool isOnline) async {
    if (_auth.currentUser == null) return;

    final userRef = _firestore.collection('users').doc(_auth.currentUser?.uid);
    final timestamp = FieldValue.serverTimestamp();

    await userRef.update({
      'isOnline': isOnline,
      'lastSeen': timestamp,
    });
  }

  static void _notifyStatusChange(String userId, String status) {
    _statusCache[userId] = status;
    _statusControllers[userId]?.add(status);
  }

  static Stream<String> getUserStatusStream(String userId) {
    if (!_statusControllers.containsKey(userId)) {
      _statusControllers[userId] = StreamController<String>.broadcast();

      // Initialize with cached value if available
      if (_statusCache.containsKey(userId)) {
        _statusControllers[userId]?.add(_statusCache[userId]!);
      }

      // Listen to user's online status
      _firestore.collection('users').doc(userId).snapshots().listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null) {
            final isOnline = data['isOnline'] ?? false;
            _notifyStatusChange(userId, isOnline ? 'online' : 'offline');
          }
        }
      });
    }
    return _statusControllers[userId]!.stream;
  }

  static Future<void> setOnline() async {
    if (!_isOnline) {
      await _updatePresence(true);
      _isOnline = true;
    }
  }

  static Future<void> setOffline() async {
    if (_isOnline) {
      await _updatePresence(false);
      _isOnline = false;
    }
  }

  static void dispose() {
    _heartbeatTimer?.cancel();
    for (var controller in _statusControllers.values) {
      controller.close();
    }
    _statusControllers.clear();
    _statusCache.clear();
  }
}
