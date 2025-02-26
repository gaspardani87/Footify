import 'package:flutter/material.dart';
import 'common_layout.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return CommonLayout(
      selectedIndex: 3,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profile Picture and Info
          Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: AssetImage('assets/images/profile_picture.png'), // Replace with actual image path
              ),
              const SizedBox(height: 10),
              Text(
                'John Doe', // Replace with actual name
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 24),
              ),
              Text(
                '@johndoe', // Replace with actual username
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16),
              ),
              Text(
                'Member since: January 2022', // Replace with actual join date
                style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Name Card
          Card(
            color: isDarkMode ? Colors.grey[850] : Colors.white,
            child: ListTile(
              leading: Icon(Icons.person, color: isDarkMode ? Colors.white : Colors.black),
              title: Text('Name', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
              trailing: IconButton(
                icon: Icon(Icons.edit, color: isDarkMode ? Colors.white : Colors.black),
                onPressed: () {
                  // Add edit functionality here
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Username Card
          Card(
            color: isDarkMode ? Colors.grey[850] : Colors.white,
            child: ListTile(
              leading: Icon(Icons.alternate_email, color: isDarkMode ? Colors.white : Colors.black),
              title: Text('Username', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
              trailing: IconButton(
                icon: Icon(Icons.edit, color: isDarkMode ? Colors.white : Colors.black),
                onPressed: () {
                  // Add edit functionality here
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Password Card
          Card(
            color: isDarkMode ? Colors.grey[850] : Colors.white,
            child: ListTile(
              leading: Icon(Icons.lock, color: isDarkMode ? Colors.white : Colors.black),
              title: Text('Password', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
              trailing: IconButton(
                icon: Icon(Icons.edit, color: isDarkMode ? Colors.white : Colors.black),
                onPressed: () {
                  // Add edit functionality here
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // E-Mail Card
          Card(
            color: isDarkMode ? Colors.grey[850] : Colors.white,
            child: ListTile(
              leading: Icon(Icons.email, color: isDarkMode ? Colors.white : Colors.black),
              title: Text('E-Mail', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
              trailing: IconButton(
                icon: Icon(Icons.edit, color: isDarkMode ? Colors.white : Colors.black),
                onPressed: () {
                  // Add edit functionality here
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Phone Card
          Card(
            color: isDarkMode ? Colors.grey[850] : Colors.white,
            child: ListTile(
              leading: Icon(Icons.phone, color: isDarkMode ? Colors.white : Colors.black),
              title: Text('Phone', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
              trailing: IconButton(
                icon: Icon(Icons.edit, color: isDarkMode ? Colors.white : Colors.black),
                onPressed: () {
                  // Add edit functionality here
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Favorite Team Card
          Card(
            color: isDarkMode ? Colors.grey[850] : Colors.white,
            child: ListTile(
              leading: Icon(Icons.sports_soccer, color: isDarkMode ? Colors.white : Colors.black),
              title: Text('Favorite Team', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
              trailing: IconButton(
                icon: Icon(Icons.edit, color: isDarkMode ? Colors.white : Colors.black),
                onPressed: () {
                  // Add edit functionality here
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Favorite League Card
          Card(
            color: isDarkMode ? Colors.grey[850] : Colors.white,
            child: ListTile(
              leading: Icon(Icons.emoji_events, color: isDarkMode ? Colors.white : Colors.black),
              title: Text('Favorite League', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
              trailing: IconButton(
                icon: Icon(Icons.edit, color: isDarkMode ? Colors.white : Colors.black),
                onPressed: () {
                  // Add edit functionality here
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Delete Account Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text('Delete Account', style: TextStyle(color: Colors.white)),
            onPressed: () {
              // Add delete account functionality here
            },
          ),
        ],
      ),
    );
  }
}