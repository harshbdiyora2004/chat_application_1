import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/terminal_colors.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate unique ID
  String generateUniqueId() {
    return _firestore.collection('users').doc().id;
  }

  // Check if user exists by phone number
  Future<bool> checkUserExists(String phoneNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        TerminalColors.info('User found with phone number: $phoneNumber');
      } else {
        TerminalColors.warning('No user found with phone number: $phoneNumber');
      }
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      TerminalColors.error('Error checking user existence: $e');
      rethrow;
    }
  }

  // Generate OTP
  String generateOTP() {
    Random random = Random();
    String otp = List.generate(6, (_) => random.nextInt(10)).join();
    TerminalColors.info('Generated OTP: $otp');
    return otp;
  }

  // Store user data with unique ID
  Future<void> storeUserData(UserModel user, String uid) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        ...user.toMap(),
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      TerminalColors.success('User data stored successfully with UID: $uid');
    } catch (e) {
      TerminalColors.error('Error storing user data: $e');
      rethrow;
    }
  }

  // Get user data by UID
  Future<UserModel?> getUserDataByUid(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        TerminalColors.success('User data retrieved for UID: $uid');
        return UserModel.fromMap(doc.data()!);
      }
      TerminalColors.warning('No user data found for UID: $uid');
      return null;
    } catch (e) {
      TerminalColors.error('Error getting user data: $e');
      rethrow;
    }
  }

  // Store base64 image in database with UID
  Future<void> storeBase64Image(String uid, String base64Image) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'profilePictureBase64': base64Image,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      TerminalColors.success('Updated profile picture for UID: $uid');
    } catch (e) {
      TerminalColors.error('Error storing profile picture: $e');
      rethrow;
    }
  }

  // Get user by phone number
  Future<Map<String, dynamic>?> getUserByPhoneNumber(String phoneNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        TerminalColors.success('User found with phone number: $phoneNumber');
        return userData;
      }
      TerminalColors.warning('No user found with phone number: $phoneNumber');
      return null;
    } catch (e) {
      TerminalColors.error('Error getting user by phone number: $e');
      rethrow;
    }
  }
}
