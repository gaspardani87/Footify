import 'package:flutter/material.dart';
import 'common_layout.dart';
import 'services/message_service.dart';

class PopupDemoPage extends StatelessWidget {
  const PopupDemoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return CommonLayout(
      selectedIndex: 0,
      showBackButton: true,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Message Popup Demo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34A853), // Green
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                MessageService.showMessage(
                  context,
                  message: 'Operation completed successfully!',
                  type: MessageType.success,
                );
              },
              child: const Text('Show Success Message'),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA4335), // Red
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                MessageService.showMessage(
                  context,
                  message: 'An error occurred. Please try again.',
                  type: MessageType.error,
                );
              },
              child: const Text('Show Error Message'),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFBBC05), // Amber
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                MessageService.showMessage(
                  context,
                  message: 'Warning: This action cannot be ununundone!',
                  type: MessageType.warning,
                );
              },
              child: const Text('Show Warning Message'),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4), // Blue
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                MessageService.showMessage(
                  context,
                  message: 'Login successful! Welcome back.',
                  type: MessageType.info,
                );
              },
              child: const Text('Show Info Message'),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                foregroundColor: isDarkMode ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                MessageService.showMessage(
                  context,
                  message: 'This is a very long message that might span multiple lines. We need to make sure it displays properly and wraps text as needed.',
                  type: MessageType.info,
                  duration: const Duration(seconds: 5),
                );
              },
              child: const Text('Show Long Message'),
            ),
          ],
        ),
      ),
    );
  }
} 