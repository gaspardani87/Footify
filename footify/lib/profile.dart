// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'common_layout.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'John Doe', // Replace with actual name
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
              const Text(
                '@johndoe', // Replace with actual username
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const Text(
                'Member since: January 2022', // Replace with actual join date
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Name Card
          Card(
            child: ListTile(
              leading: const Icon(Icons.person, color: Colors.black),
              title: const Text('Name', style: TextStyle(color: Colors.black)),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.black),
                onPressed: () {
                  // Add edit functionality here
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Username Card
          Card(
            child: ListTile(
              leading: const Icon(Icons.alternate_email, color: Colors.black),
              title: const Text('Username', style: TextStyle(color: Colors.black)),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.black),
                onPressed: () {
                  // Add edit functionality here
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Password Card
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock, color: Colors.black),
              title: const Text('Password', style: TextStyle(color: Colors.black)),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.black),
                onPressed: () {
                  // Add edit functionality here
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // E-Mail Card
          Card(
            child: ListTile(
              leading: const Icon(Icons.email, color: Colors.black),
              title: const Text('E-Mail', style: TextStyle(color: Colors.black)),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.black),
                onPressed: () {
                  // Add edit functionality here
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Phone Card
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone, color: Colors.black),
              title: const Text('Phone', style: TextStyle(color: Colors.black)),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.black),
                onPressed: () {
                  // Add edit functionality here
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Favorite Team Card
          Card(
            child: ListTile(
              leading: const Icon(Icons.sports_soccer, color: Colors.black),
              title: const Text('Favorite Team', style: TextStyle(color: Colors.black)),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.black),
                onPressed: () {
                  // Add edit functionality here
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Favorite League Card
          Card(
            child: ListTile(
              leading: const Icon(Icons.emoji_events, color: Colors.black),
              title: const Text('Favorite League', style: TextStyle(color: Colors.black)),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.black),
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