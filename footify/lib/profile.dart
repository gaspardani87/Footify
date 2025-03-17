import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_layout.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'providers/firebase_provider.dart';
import 'package:flutter/services.dart';
import 'services/football_api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'language_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for email availability check
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for Timestamp
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
// Import for web support
// We'll use a different approach for conditional imports

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color goldColor = Color(0xFFFFE6AC);
  static const Color darkColor = Color(0xFF2C2C2C);

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoadingImage = false;

  // Track the temporary image path for web
  String? _webImagePath;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FirebaseProvider>(context);
    final userData = provider.userData;
    final String displayName = userData?['displayName'] ?? 'User';
    final String? bio = userData?['bio'];
    final String? favoriteTeam = userData?['favoriteTeam'];
    
    // Handle the joinDate which could be either DateTime or Timestamp
    String joinDate = 'Loading...';
    if (userData != null && userData.containsKey('joinDate')) {
      final dynamic joinDateValue = userData['joinDate'];
      if (joinDateValue is Timestamp) {
        joinDate = DateFormat('MMMM d, yyyy').format(joinDateValue.toDate());
      } else if (joinDateValue is DateTime) {
        joinDate = DateFormat('MMMM d, yyyy').format(joinDateValue);
      }
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editProfile(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: userData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => _showImageOptions(context),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        _buildProfileAvatar(),
                        IconButton(
                          icon: Icon(Icons.camera_alt, size: 20, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                          onPressed: () => _pickImage(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '@${userData['username'] ?? 'username'}',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFFE6AC) : Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Joined $joinDate',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.black54,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: Theme.of(context).brightness == Brightness.dark ? const Color.fromARGB(255, 32, 32, 32) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileItem(
                            context,
                            'Email',
                            userData['email'] ?? 'No email provided',
                            Icons.email,
                            Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          ),
                          const Divider(color: Color(0xFFFFE6AC)),
                          _buildProfileItem(
                            context,
                            AppLocalizations.of(context)!.profileName,
                            userData['name'] ?? 'No name provided',
                            Icons.person,
                            Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          ),
                          const Divider(color: Color(0xFFFFE6AC)),
                          _buildProfileItem(
                            context,
                            AppLocalizations.of(context)!.favTeam,
                            userData['favoriteTeam'] ?? 'No team selected',
                            Icons.sports_soccer,
                            Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          ),
                          const Divider(color: Color(0xFFFFE6AC)),
                          _buildProfileItem(
                            context,
                            AppLocalizations.of(context)!.favLeague,
                            userData['favoriteLeague'] ?? 'No league selected',
                            Icons.emoji_events,
                            Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  ImageProvider? _getProfileImageProvider() {
    final provider = Provider.of<FirebaseProvider>(context, listen: false);
    final userData = provider.userData;
    
    // Extra verification of user data
    if (userData == null) {
      print('WARNING: userData is null in _getProfileImageProvider');
      return null;
    }
    
    // Get the exact profilePictureUrl as stored in Firebase
    final profileUrl = userData['profilePictureUrl'];
    
    print('VERIFICATION: Getting profile image provider with URL: $profileUrl');
    
    // If image is being loaded from local selection (non-web)
    if (!kIsWeb && _profileImage != null) {
      print('Using local file image from: ${_profileImage!.path}');
      return FileImage(_profileImage!);
    }
    
    // If we have a web temporary image
    if (kIsWeb && _webImagePath != null) {
      print('Using web temporary image from: $_webImagePath');
      return NetworkImage(_webImagePath!);
    }
    
    // If we have an existing profile picture URL
    if (profileUrl != null && profileUrl.isNotEmpty) {
      // Use the exact URL as stored in Firestore, without modifications
      print('Loading profile image from Firebase URL: $profileUrl');
      return NetworkImage(profileUrl);
    }
    
    print('No valid profile image source found, returning null');
    // Return null to let the CircleAvatar display the default icon in the child parameter
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Refresh user data when the profile page is loaded
    _refreshUserData();
  }

  // Add method to verify Firebase data
  void _verifyFirebaseData() {
    // Get the provider
    final provider = Provider.of<FirebaseProvider>(context, listen: false);
    final userData = provider.userData;
    
    // Debug output of all user data to verify
    print('------- FIREBASE USER DATA VERIFICATION -------');
    if (userData != null) {
      userData.forEach((key, value) {
        print('$key: $value');
      });
      
      // Specifically check the profile picture URL
      final profileUrl = userData['profilePictureUrl'];
      print('Profile Picture URL: $profileUrl');
      
      if (profileUrl == null) {
        print('WARNING: profilePictureUrl is NULL in Firebase data');
      } else if (profileUrl.isEmpty) {
        print('WARNING: profilePictureUrl is EMPTY in Firebase data');
      } else {
        print('Profile picture URL appears valid, length: ${profileUrl.length}');
      }
    } else {
      print('WARNING: userData is NULL - no user data loaded from Firebase');
    }
    print('--------------------------------------------');
  }

  // Add a method to refresh user data and precache the profile image
  Future<void> _refreshUserData() async {
    if (!mounted) return;
    
    try {
      final provider = Provider.of<FirebaseProvider>(context, listen: false);
      await provider.refreshUserData();
      
      // Verify the data once it's loaded
      if (mounted) {
        _verifyFirebaseData();
      }
      
      // After user data is loaded, check for the profile image URL
      if (provider.userData != null) {
        final profileUrl = provider.userData!['profilePictureUrl'];
        
        if (profileUrl != null && profileUrl.isNotEmpty) {
          print('Profile image URL found in user data: $profileUrl');
          
          // Don't use precacheImage on web as it can cause issues
          if (!kIsWeb) {
            try {
              // Only precache on mobile/desktop platforms
              await precacheImage(
                NetworkImage(profileUrl),
                context,
              ).timeout(const Duration(seconds: 3), onTimeout: () {
                print('Precaching timed out after 3 seconds');
                return;
              });
              print('Profile image precached successfully');
            } catch (e) {
              print('Warning: Error precaching image: $e');
            }
          } else {
            print('On web platform - skipping precacheImage');
          }
        } else {
          print('No profile picture URL found in user data');
        }
      }
    } catch (e) {
      print('Error refreshing user data: $e');
    }
  }

  @override
  void dispose() {
    // Clean up resources
    _profileImage = null;
    _webImagePath = null;
    super.dispose();
  }

  Future<void> _pickImage(BuildContext context) async {
    // Store the scaffold messenger and provider before any async operation
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<FirebaseProvider>(context, listen: false);
    
    try {
      // Use image picker to select an image from the device
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75, // Reduce quality to improve performance
        maxWidth: 800,    // Limit dimensions to reduce file size
      );
      
      if (image == null) {
        // User canceled the picker
        return;
      }
      
      if (!mounted) return; // Check if widget is still mounted
      
      setState(() {
        _isLoadingImage = true;
        if (!kIsWeb) {
          _profileImage = File(image.path);
        } else {
          // For web, we'll keep the XFile path for reference
          _webImagePath = image.path;
        }
      });
      
      if (!mounted) return; // Check again after setState
      
      // Show uploading message
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Uploading profile picture...')),
      );
      
      try {
        String? imageUrl;
        
        if (!kIsWeb) {
          // For mobile/desktop, upload to Firebase Storage
          imageUrl = await provider.uploadProfileImage(_profileImage!);
        } else {
          // For web, use web-specific approach
          final bytes = await image.readAsBytes();
          imageUrl = await provider.uploadProfileImageBytes(bytes, 'jpg');
        }
        
        if (imageUrl == null || imageUrl.isEmpty) {
          throw Exception("Failed to upload image to storage");
        }
        
        // Update Firestore with the image URL
        await provider.updateProfilePictureUrl(imageUrl);
        
        // Refresh user data
        await provider.refreshUserData();
        
        if (!mounted) return; // Check if mounted before showing success
        
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully')),
        );
      } catch (e) {
        print('Profile picture upload error: $e');
        
        if (mounted) { // Only show error if still mounted
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Failed to upload profile picture: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingImage = false;
          });
        }
      }
    } catch (e) {
      print('Image picker error: $e');
      
      // Only try to show errors if we're still mounted
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error selecting image: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildProfileItem(BuildContext context, String label, String value, IconData icon, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: goldColor, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRegistrationFlow(BuildContext context) async {
    // Step 1: Collect Email and Password
    final credentials = await _showEmailPasswordDialog(context);
    if (credentials == null) return;
    final email = credentials['email']!;
    final password = credentials['password']!;

    // Step 2: Collect Full Name
    final name = await _showNameDialog(context);
    if (name == null) return;

    // Step 3: Collect Username
    final username = await _showUsernameDialog(context);
    if (username == null) return;

    // Step 4: Collect Favorite Team
    final team = await _showTeamSelectionDialog(context);
    if (team == null) return;

    // Step 5: Collect Favorite League
    final league = await _showLeagueSelectionDialog(context);
    if (league == null) return;

    // Complete Registration with all collected data
    if (context.mounted) {
      final firebaseProvider = Provider.of<FirebaseProvider>(context, listen: false);
      try {
        final success = await firebaseProvider.completeSignUp(
          email: email,
          password: password,
          name: name,
          username: username,
          favoriteTeam: team['name'] ?? '',
          favoriteTeamId: team['id'] ?? '',
          favoriteLeague: league['name'] ?? '',
        );
        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration completed successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<Map<String, String>?> _showEmailPasswordDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                enabled: !isLoading,
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                enabled: !isLoading,
              ),
              TextField(
                controller: confirmPasswordController,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
                enabled: !isLoading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (passwordController.text != confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Passwords do not match')),
                        );
                        return;
                      }

                      setState(() => isLoading = true);
                      try {
                        final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(emailController.text);
                        if (methods.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Email already in use')),
                          );
                          setState(() => isLoading = false);
                          return;
                        }
                        Navigator.pop(context, {
                          'email': emailController.text,
                          'password': passwordController.text,
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error checking email: $e')),
                        );
                        setState(() => isLoading = false);
                      }
                    },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showNameDialog(BuildContext context) async {
    final nameController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Full Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showUsernameDialog(BuildContext context) async {
    final usernameController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Username'),
        content: TextField(
          controller: usernameController,
          decoration: const InputDecoration(
            labelText: 'Username',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () {
              if (usernameController.text.isNotEmpty) {
                Navigator.pop(context, usernameController.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a username')),
                );
              }
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>?> _showTeamSelectionDialog(BuildContext context) async {
    List<Map<String, String>>? teams;
    Map<String, String>? selectedTeam;
    bool isLoading = true;

    try {
      teams = await FootballApiService.getTeams();
      isLoading = false;
    } catch (e) {
      print('Error loading teams: $e');
      isLoading = false;
    }

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Your Favorite Team'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const CircularProgressIndicator()
                else if (teams == null || teams.isEmpty)
                  const Text('Failed to load teams')
                else
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1,
                      ),
                      itemCount: teams.length,
                      itemBuilder: (context, index) {
                        final team = teams![index];
                        final isSelected = selectedTeam == team;
                        return InkWell(
                          onTap: () {
                            setState(() => selectedTeam = team);
                          },
                          child: Card(
                            color: isSelected ? Colors.blue.withOpacity(0.3) : null,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  team['crest'] ?? '',
                                  height: 40,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.sports_soccer),
                                ),
                                Text(
                                  team['name'] ?? 'Unknown Team',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Back'),
            ),
            TextButton(
              onPressed: isLoading || selectedTeam == null
                  ? null
                  : () => Navigator.pop(dialogContext, selectedTeam),
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, String>?> _showLeagueSelectionDialog(BuildContext context) async {
    List<Map<String, String>>? leagues;
    Map<String, String>? selectedLeague;
    bool isLoading = true;

    try {
      leagues = await FootballApiService.getLeagues();
      isLoading = false;
    } catch (e) {
      print('Error loading leagues: $e');
      isLoading = false;
    }

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Your Favorite League'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const CircularProgressIndicator()
                else if (leagues == null || leagues.isEmpty)
                  const Text('Failed to load leagues')
                else
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1,
                      ),
                      itemCount: leagues.length,
                      itemBuilder: (context, index) {
                        final league = leagues![index];
                        final isSelected = selectedLeague == league;
                        return InkWell(
                          onTap: () {
                            setState(() => selectedLeague = league);
                          },
                          child: Card(
                            color: isSelected ? Colors.blue.withOpacity(0.3) : null,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  league['emblem'] ?? '',
                                  height: 40,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.emoji_events),
                                ),
                                Text(
                                  league['name'] ?? 'Unknown League',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Back'),
            ),
            TextButton(
              onPressed: isLoading || selectedLeague == null
                  ? null
                  : () => Navigator.pop(dialogContext, selectedLeague),
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLoginDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Login'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                enabled: !isLoading,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                enabled: !isLoading,
              ),
              if (isLoading) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (emailController.text.isEmpty || passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill in all fields')),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        final firebaseProvider = Provider.of<FirebaseProvider>(context, listen: false);
                        final success = await firebaseProvider.signIn(
                          emailController.text,
                          passwordController.text,
                        );

                        if (success && context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Login successful')),
                          );
                        } else if (context.mounted) {
                          setState(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Login failed')),
                          );
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      }
                    },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _handleDeleteAccount(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final firebaseProvider = Provider.of<FirebaseProvider>(context, listen: false);
    try {
      await firebaseProvider.deleteAccount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: ${e.toString()}')),
        );
      }
    }
  }

  String _formatDate(dynamic date) {
    try {
      if (date == null) {
        return 'Recently'; // Fallback text
      }
      
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      
      DateTime dateTime;
      
      // Handle different types
      if (date is DateTime) {
        dateTime = date;
      } else if (date is Timestamp) {
        dateTime = date.toDate();
      } else if (date is int) {
        // Milliseconds since epoch
        dateTime = DateTime.fromMillisecondsSinceEpoch(date);
      } else {
        return 'Recently'; // Fallback if format unknown
      }
      
      return '${months[dateTime.month - 1]} ${dateTime.year}';
    } catch (e) {
      print('Error formatting date: $e');
      return 'Recently'; // Fallback on error
    }
  }

  void _showImageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Add Profile Picture'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Remove Profile Picture'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteProfilePicture(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteProfilePicture(BuildContext context) async {
    setState(() {
      _profileImage = null;
      _webImagePath = null;
      _isLoadingImage = true; // Show loading indicator
    });

    final provider = Provider.of<FirebaseProvider>(context, listen: false);
    try {
      // Update the Firestore document with null for profilePictureUrl
      await provider.updateProfilePictureUrl(null);
      
      // Refresh user data
      await provider.refreshUserData();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture removed')),
        );
      }
    } catch (e) {
      print('Error removing profile picture: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove profile picture: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
      }
    }
  }

  void _editProfile(BuildContext context) {
    // Navigate to profile edit screen or show edit dialog
    // Implementation depends on your app's navigation structure
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit profile feature coming soon')),
    );
  }

  void _signOut(BuildContext context) async {
    final provider = Provider.of<FirebaseProvider>(context, listen: false);
    try {
      await provider.signOut();
      if (context.mounted) {
        // Navigate to login page or show a success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }

  bool _shouldShowDefaultIcon() {
    final provider = Provider.of<FirebaseProvider>(context, listen: false);
    final profileUrl = provider.userData?['profilePictureUrl'];
    
    // If image is being loaded from local selection (non-web)
    if (!kIsWeb && _profileImage != null) {
      return false;
    }
    
    // If we have a web temporary image
    if (kIsWeb && _webImagePath != null) {
      return false;
    }
    
    // If we have an existing profile picture URL
    if (profileUrl != null && profileUrl.isNotEmpty) {
      return false;
    }
    
    // Default placeholder image - use a material default icon as fallback
    return true;
  }

  Widget _buildAvatarChild() {
    if (_isLoadingImage) {
      return const CircularProgressIndicator();
    }
    
    // Show default icon if needed
    if (_shouldShowDefaultIcon()) {
      return const Icon(Icons.person, size: 50, color: Colors.black54);
    }
    
    // Return an empty widget for when we have an actual image
    return const SizedBox.shrink();
  }

  Widget _buildProfileAvatar() {
    return Container(
      width: 128,
      height: 128,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: _isLoadingImage
            ? const Center(child: CircularProgressIndicator())
            : _getProfileImageProvider() != null
                ? _buildNetworkImageWithRetry()
                : const Icon(Icons.person, size: 50, color: Colors.black54),
      ),
    );
  }

  // Add a method to create a proxied URL for images on the web platform
  String _getProxiedImageUrl(String originalUrl) {
    // Base URL for your Firebase Functions
    // This URL should match your deployed Firebase Functions
    const String functionsBaseUrl = 'https://us-central1-footify-13da4.cloudfunctions.net';
    
    // URL encode the original URL to use as a query parameter
    final encodedUrl = Uri.encodeComponent(originalUrl);
    
    // Return the proxied URL that routes through the Firebase Function
    return '$functionsBaseUrl/proxyImage?url=$encodedUrl';
  }

  // Create a new method specifically for handling network image loading with retries
  Widget _buildNetworkImageWithRetry() {
    final imageProvider = _getProfileImageProvider()!;
    final provider = Provider.of<FirebaseProvider>(context, listen: false);
    final profileUrl = provider.userData?['profilePictureUrl'];
    
    print('========== PROFILE IMAGE DEBUG ==========');
    print('Provider type: ${imageProvider.runtimeType}');
    print('Original profile URL from user data: $profileUrl');
    
    // Verify URL format
    if (profileUrl != null) {
      if (profileUrl.startsWith('https://firebasestorage.googleapis.com')) {
        print('URL appears to be a valid Firebase Storage URL');
      } else {
        print('WARNING: URL does not appear to be a Firebase Storage URL');
      }
    }
    print('=========================================');
    
    // Handle web platform differently
    if (kIsWeb) {
      if (profileUrl != null && profileUrl.isNotEmpty) {
        // Use the proxied URL for the web
        final proxiedUrl = _getProxiedImageUrl(profileUrl);
        print('Using proxied URL for web: $proxiedUrl');
        
        return Image(
          image: NetworkImage(proxiedUrl),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading proxied profile image on web: $error');
            return const Icon(Icons.person, size: 50, color: Colors.black54);
          },
        );
      } else {
        return const Icon(Icons.person, size: 50, color: Colors.black54);
      }
    } else {
      // For mobile/desktop platforms
      return Image(
        image: imageProvider,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: child,
            );
          }
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('Error loading profile image on mobile: $error');
          return const Icon(Icons.person, size: 50, color: Colors.black54);
        },
      );
    }
  }
}