import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/presence_service.dart';
import 'login_screen.dart';
import 'chats_screen.dart';
import 'status_screen.dart';
import 'calls_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Custom colors
  final Color _primaryColor = const Color(0xFF1A237E); // Deep Blue
  final Color _accentColor = const Color(0xFF2196F3); // Light Blue
  final Color _backgroundColor = Colors.white;
  final Color _textColor = Colors.black87;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild when tab changes
    });
    _initPresence();
  }

  Future<void> _initPresence() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phoneNumber');
    if (phone == null) return;
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('phoneNumber', isEqualTo: phone)
        .get();
    if (query.docs.isNotEmpty) {
      PresenceService.initialize();
      await PresenceService.setOnline();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    PresenceService.setOffline();
    PresenceService.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.person, color: _accentColor),
              title: Text(
                'Profile',
                style: TextStyle(color: _textColor),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings, color: _accentColor),
              title: Text(
                'Settings',
                style: TextStyle(color: _textColor),
              ),
              onTap: () {
                Navigator.pop(context);
                // Handle settings navigation
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: _accentColor),
              title: Text(
                'Logout',
                style: TextStyle(color: _textColor),
              ),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  IconData _getFloatingActionButtonIcon() {
    switch (_tabController.index) {
      case 0:
        return Icons.chat;
      case 1:
        return Icons.camera_alt;
      case 2:
        return Icons.call;
      default:
        return Icons.chat;
    }
  }

  void _handleFloatingActionButtonPress() {
    switch (_tabController.index) {
      case 0:
        // Navigate to contacts screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ContactsScreen()),
        );
        break;
      case 1:
        // Handle new status
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New status feature coming soon!')),
        );
        break;
      case 2:
        // Handle new call
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New call feature coming soon!')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  border: InputBorder.none,
                ),
              )
            : const Text(
                'Chat App',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.more_vert,
              color: Colors.white,
            ),
            onPressed: _showOptionsMenu,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'CHATS'),
            Tab(text: 'STATUS'),
            Tab(text: 'CALLS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ChatsScreen(),
          StatusScreen(),
          CallsScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleFloatingActionButtonPress,
        backgroundColor: _primaryColor,
        child: Icon(
          _getFloatingActionButtonIcon(),
          color: Colors.white,
        ),
      ),
    );
  }
}
