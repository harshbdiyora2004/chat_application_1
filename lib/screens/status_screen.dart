import 'package:flutter/material.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF1A237E); // AppBar Deep Blue
    const Color textColor = Colors.black87;
    const Color dividerColor = Color(0xFFE0E0E0);

    return ListView(
      children: [
        // My Status
        ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: accentColor.withOpacity(0.1),
                child: const Icon(Icons.person, color: accentColor, size: 35),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          title: const Text(
            'My Status',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          subtitle: Text(
            'Tap to add status update',
            style: TextStyle(
              color: textColor.withOpacity(0.7),
            ),
          ),
        ),
        const Divider(height: 1, color: dividerColor),
        // Recent Updates
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Recent Updates',
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Status List
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          itemBuilder: (context, index) {
            return Column(
              children: [
                ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: accentColor.withOpacity(0.1),
                        child: const Icon(Icons.person,
                            color: accentColor, size: 30),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: index % 2 == 0 ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    'User ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    '${index + 1} hour${index == 0 ? '' : 's'} ago',
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(index + 1) * 2} views',
                      style: const TextStyle(
                        color: accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, color: dividerColor),
              ],
            );
          },
        ),
      ],
    );
  }
}
