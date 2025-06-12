import 'package:flutter/material.dart';

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF1A237E); // AppBar Deep Blue
    const Color textColor = Colors.black87;
    const Color dividerColor = Color(0xFFE0E0E0);

    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        final bool isOutgoing = index % 2 == 0;
        final Color callColor = isOutgoing ? Colors.green : Colors.red;

        return Column(
          children: [
            ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: accentColor.withOpacity(0.1),
                    child:
                        const Icon(Icons.person, color: accentColor, size: 30),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: index % 3 == 0 ? Colors.green : Colors.grey,
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
              subtitle: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: callColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOutgoing ? Icons.call_made : Icons.call_received,
                          size: 14,
                          color: callColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOutgoing ? 'Outgoing' : 'Incoming',
                          style: TextStyle(
                            color: callColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(index + 1) * 2} min',
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.call,
                  color: accentColor,
                  size: 20,
                ),
              ),
              onTap: () {
                // Handle call
              },
            ),
            const Divider(height: 1, color: dividerColor),
          ],
        );
      },
    );
  }
}
