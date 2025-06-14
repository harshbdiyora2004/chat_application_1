import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'individual_chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  Set<String> _registeredNumbers = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, Map<String, dynamic>> _userDataCache = {};
  StreamSubscription<QuerySnapshot>? _usersSubscription;
  final int _pageSize = 20;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;

  // Custom colors
  final Color _primaryColor = const Color(0xFF1A237E);
  final Color _accentColor = const Color(0xFF2196F3);
  final Color _backgroundColor = Colors.white;
  final Color _textColor = Colors.black87;

  // Add a variable to store the current user's phone number
  String? _currentUserPhone;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserPhone();
    _fetchContactsAndUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _usersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchContactsAndUsers() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch contacts
      List<Contact> contacts = [];
      if (await FlutterContacts.requestPermission()) {
        contacts = await FlutterContacts.getContacts(withProperties: true);
      }

      // 2. Setup users stream
      _setupUsersStream();

      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contacts: $e')),
        );
      }
    }
  }

  void _setupUsersStream() {
    _usersSubscription?.cancel();
    _usersSubscription = FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          // Clear existing data to prevent duplicates
          _registeredNumbers.clear();

          for (var doc in snapshot.docs) {
            final userData = doc.data();
            final phoneNumber = userData['phoneNumber'] as String?;
            if (phoneNumber != null) {
              final normalizedNumber = _normalizePhone(phoneNumber);
              // Ensure UID and profilePictureBase64 are present in userData
              _userDataCache[normalizedNumber] = {
                ...userData,
                'uid': doc.id,
                'profilePictureBase64':
                    (userData['profilePictureBase64'] as String?) ?? '',
              };
              _registeredNumbers.add(normalizedNumber);
            }
          }

          if (snapshot.docs.isNotEmpty) {
            _lastDocument = snapshot.docs.last;
            _hasMoreData = snapshot.docs.length >= _pageSize;
          } else {
            _hasMoreData = false;
          }
        });
      }
    });
  }

  void _loadMoreUsers() {
    if (!_hasMoreData || _lastDocument == null) return;

    _usersSubscription?.cancel();
    _usersSubscription = FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(_pageSize)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final newUsers = snapshot.docs;
        if (newUsers.isEmpty) {
          setState(() => _hasMoreData = false);
          return;
        }

        _lastDocument = newUsers.last;
        final newUserData = Map.fromEntries(
          newUsers.map((doc) => MapEntry(
                _normalizePhone(doc['phoneNumber'] ?? ''),
                doc.data(),
              )),
        );

        setState(() {
          _userDataCache.addAll(newUserData);
          _registeredNumbers = _userDataCache.keys.toSet();
        });
      }
    });
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _filterContacts(String query) {
    setState(() {
      _filteredContacts = _contacts.where((contact) {
        final name = contact.displayName.toLowerCase();
        final phones = contact.phones.map((p) => p.number).join(' ');
        return name.contains(query.toLowerCase()) ||
            phones.contains(query.toLowerCase());
      }).toList();
    });
  }

  bool _isRegistered(Contact contact) {
    if (contact.phones.isEmpty) return false;

    for (var phone in contact.phones) {
      final normalizedNumber = _normalizePhone(phone.number);
      if (_registeredNumbers.contains(normalizedNumber)) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic>? _getUserData(Contact contact) {
    if (contact.phones.isEmpty) return null;
    for (var p in contact.phones) {
      final normalized = _normalizePhone(p.number);
      if (_userDataCache.containsKey(normalized)) {
        return _userDataCache[normalized];
      }
    }
    return null;
  }

  Widget _buildProfilePicture(String? base64Image, String name) {
    if (base64Image == null || base64Image.isEmpty) {
      return CircleAvatar(
        backgroundColor: _accentColor,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return CircleAvatar(
      backgroundColor: _accentColor,
      backgroundImage: MemoryImage(base64Decode(base64Image)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredContacts = _filteredContacts;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: const Text('Contacts', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterContacts,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? _buildShimmerLoading()
                : filteredContacts.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = filteredContacts[index];
                          final isRegistered = _isRegistered(contact);
                          final userData = _getUserData(contact);

                          // Don't show current user in the contacts list
                          if (contact.phones.isNotEmpty &&
                              contact.phones.any((phone) =>
                                  _normalizePhone(phone.number) ==
                                  _normalizePhone(_currentUserPhone ?? ''))) {
                            return const SizedBox.shrink();
                          }

                          // Prevent messaging self
                          if (userData != null &&
                              userData['uid'] == _currentUserPhone) {
                            return const SizedBox.shrink();
                          }

                          return ListTile(
                            leading: isRegistered && userData != null
                                ? _buildProfilePicture(
                                    userData['profilePictureBase64'],
                                    contact.displayName)
                                : CircleAvatar(
                                    backgroundColor: _accentColor,
                                    child: Text(
                                      contact.displayName[0].toUpperCase(),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                            title: Text(contact.displayName),
                            subtitle: Text(
                              contact.phones.isNotEmpty
                                  ? contact.phones.first.number
                                  : 'No number',
                            ),
                            trailing: isRegistered
                                ? IconButton(
                                    icon: const Icon(Icons.message),
                                    onPressed: () {
                                      if (userData != null &&
                                          userData['uid'] != null &&
                                          userData['uid'] !=
                                              _currentUserPhone) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                IndividualChatScreen(
                                              receiverUid: userData['uid'],
                                              receiverName:
                                                  (userData['firstName'] ??
                                                          '') +
                                                      ' ' +
                                                      (userData['lastName'] ??
                                                          ''),
                                              receiverProfilePic: userData[
                                                  'profilePictureBase64'],
                                            ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'User data is incomplete.')),
                                        );
                                      }
                                    },
                                  )
                                : TextButton(
                                    onPressed: () {
                                      // Handle invite functionality
                                      // You can implement sharing invite link here
                                    },
                                    child: const Text('Invite'),
                                  ),
                            onTap: isRegistered &&
                                    userData != null &&
                                    userData['uid'] != null &&
                                    userData['uid'] != _currentUserPhone
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            IndividualChatScreen(
                                          receiverUid: userData['uid'],
                                          receiverName:
                                              (userData['firstName'] ?? '') +
                                                  ' ' +
                                                  (userData['lastName'] ?? ''),
                                          receiverProfilePic:
                                              userData['profilePictureBase64'],
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 120,
                      height: 12,
                      color: Colors.white,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: _textColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No contacts found',
            style: TextStyle(
              fontSize: 18,
              color: _textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCurrentUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserPhone = prefs.getString('phoneNumber');
    });
  }
}
