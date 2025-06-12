// ignore_for_file: deprecated_member_use

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String otp;
  final bool isRegistration;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    required this.otp,
    required this.isRegistration,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Custom colors
  final Color _primaryColor = const Color(0xFF1A237E); // Deep Blue
  final Color _accentColor = const Color(0xFF2196F3); // Light Blue
  final Color _backgroundColor = Colors.white;
  final Color _cardColor = Colors.white;
  final Color _textColor = Colors.black87;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _verifyOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_otpController.text == widget.otp) {
        // Store login state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('phoneNumber', widget.phoneNumber);

        // Fetch UID from Firestore and store in SharedPreferences
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('phoneNumber', isEqualTo: widget.phoneNumber)
            .get();
        if (query.docs.isNotEmpty) {
          final uid = query.docs.first['uid'];
          await prefs.setString('uid', uid);
          log('DEBUG: Saved UID to SharedPreferences: $uid');
        }

        if (!mounted) return;

        if (widget.isRegistration) {
          // For registration, return true to ProfileSetupScreen
          Navigator.pop(context, true);
        } else {
          // For login, navigate to home screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid OTP')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      // App Logo
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.security,
                            size: 60,
                            color: _accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // OTP Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'OTP Verification',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: _textColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter the OTP sent to ${widget.phoneNumber}',
                              style: TextStyle(
                                fontSize: 16,
                                color: _textColor.withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _otpController,
                              style: TextStyle(color: _textColor),
                              decoration: InputDecoration(
                                hintText: 'Enter 6-digit OTP',
                                hintStyle: TextStyle(
                                    color: _textColor.withOpacity(0.5)),
                                prefixIcon: Icon(Icons.lock_outline,
                                    color: _accentColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: _primaryColor.withOpacity(0.2)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: _primaryColor.withOpacity(0.2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: _accentColor),
                                ),
                                filled: true,
                                fillColor: _backgroundColor,
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter OTP';
                                }
                                if (value.length != 6) {
                                  return 'OTP must be 6 digits';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Verify Button
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _accentColor.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOTP,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Verify',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
