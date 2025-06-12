import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _firebaseService = FirebaseService();
  File? _imageFile;
  String? _phoneNumber;
  String? _uid;
  bool _isLoading = true;
  String? _profilePictureBase64;
  bool _isEditMode = false;

  // Custom colors
  final Color _primaryColor = const Color(0xFF1A237E);
  final Color _accentColor = const Color(0xFF2196F3);
  final Color _backgroundColor = Colors.white;
  final Color _textColor = Colors.black87;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phoneNumber');
    if (phone == null) {
      setState(() => _isLoading = false);
      return;
    }
    final userData = await _firebaseService.getUserByPhoneNumber(phone);
    if (userData != null) {
      setState(() {
        _phoneNumber = userData['phoneNumber'];
        _uid = userData['uid'];
        _firstNameController.text = userData['firstName'] ?? '';
        _lastNameController.text = userData['lastName'] ?? '';
        _bioController.text = userData['bio'] ?? '';
        _profilePictureBase64 = userData['profilePictureBase64'];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        cropStyle: CropStyle.circle,
        compressQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: _primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
            resetAspectRatioEnabled: false,
            rotateButtonsHidden: true,
            resetButtonHidden: true,
          ),
        ],
      );
      if (croppedFile != null) {
        setState(() {
          _imageFile = File(croppedFile.path);
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() ||
        _uid == null ||
        _phoneNumber == null) return;
    setState(() => _isLoading = true);
    try {
      String? base64Image = _profilePictureBase64;
      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        base64Image = base64Encode(bytes);
      }
      final user = UserModel(
        phoneNumber: _phoneNumber!,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        bio: _bioController.text.trim(),
        profilePictureUrl: base64Image,
      );
      await _firebaseService.storeUserData(user, _uid!);
      if (base64Image != null) {
        await _firebaseService.storeBase64Image(_uid!, base64Image);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        setState(() {
          _isEditMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: \\${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isEditMode ? Icons.close : Icons.edit,
                color: Colors.white),
            tooltip: _isEditMode ? 'Cancel' : 'Edit',
            onPressed: () {
              setState(() {
                if (_isEditMode) {
                  // Cancel edit: reload profile
                  _isEditMode = false;
                  _loadProfile();
                } else {
                  _isEditMode = true;
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _accentColor,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryColor.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _imageFile != null
                                  ? Image.file(
                                      _imageFile!,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    )
                                  : (_profilePictureBase64 != null
                                      ? Image.memory(
                                          base64Decode(_profilePictureBase64!),
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: _backgroundColor,
                                          child: Icon(
                                            Icons.add_a_photo,
                                            size: 40,
                                            color: _accentColor,
                                          ),
                                        )),
                            ),
                          ),
                          if (_isEditMode)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _accentColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _primaryColor.withOpacity(0.2),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                  ),
                                  onPressed: _isEditMode ? _pickImage : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _firstNameController,
                      style: TextStyle(color: _textColor),
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        labelStyle: TextStyle(color: _textColor),
                        hintText: 'Enter your first name',
                        hintStyle:
                            TextStyle(color: _textColor.withOpacity(0.5)),
                        prefixIcon: Icon(Icons.person, color: _primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: _primaryColor.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: _primaryColor.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _accentColor),
                        ),
                        filled: true,
                        fillColor: _backgroundColor,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your first name';
                        }
                        return null;
                      },
                      enabled: _isEditMode,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      style: TextStyle(color: _textColor),
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        labelStyle: TextStyle(color: _textColor),
                        hintText: 'Enter your last name',
                        hintStyle:
                            TextStyle(color: _textColor.withOpacity(0.5)),
                        prefixIcon: Icon(Icons.person, color: _primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: _primaryColor.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: _primaryColor.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _accentColor),
                        ),
                        filled: true,
                        fillColor: _backgroundColor,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your last name';
                        }
                        return null;
                      },
                      enabled: _isEditMode,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      style: TextStyle(color: _textColor),
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        labelStyle: TextStyle(color: _textColor),
                        hintText: 'Tell us about yourself',
                        hintStyle:
                            TextStyle(color: _textColor.withOpacity(0.5)),
                        prefixIcon:
                            Icon(Icons.info_outline, color: _primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: _primaryColor.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: _primaryColor.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _accentColor),
                        ),
                        filled: true,
                        fillColor: _backgroundColor,
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your bio';
                        }
                        return null;
                      },
                      enabled: _isEditMode,
                    ),
                    const SizedBox(height: 24),
                    if (_isEditMode)
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
                          onPressed: !_isLoading ? _saveProfile : null,
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
                                  'Save',
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
    );
  }
}
