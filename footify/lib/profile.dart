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
import 'font_size_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for email availability check
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for Timestamp
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'dart:async';
import 'services/message_service.dart'; // Import for our new message popup system

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  static const Color goldColor = Color(0xFFFFE6AC);
  static const Color darkColor = Color(0xFF2C2C2C);

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoadingImage = false;

  // Track the temporary image path for web
  String? _webImagePath;

  // Preload teams for faster dialog display
  List<Map<String, dynamic>>? _cachedTeams;
  List<Map<String, dynamic>>? _cachedLeagues;

  // Track if we're in edit mode
  bool _isEditMode = false;
  
  // Controllers for editable fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  // Keys for animations
  final GlobalKey _editProfileButtonKey = GlobalKey();
  final GlobalKey _logoutButtonKey = GlobalKey();
  final GlobalKey _deleteButtonKey = GlobalKey();
  final GlobalKey _cancelButtonKey = GlobalKey();

  // Add this variable to track which field is being edited
  String? _currentlyEditingField;

  // Add this variable to store temporary name change
  String? _pendingNameChange;

  // Add controllers for password fields
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Add these variables to store temporary selections
  Map<String, dynamic>? _selectedTeam;
  Map<String, dynamic>? _selectedLeague;
  
  // Add variables to store original values
  Map<String, dynamic>? _originalTeam;
  Map<String, dynamic>? _originalLeague;

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
        joinDate = DateFormat('MMMM yyyy').format(joinDateValue.toDate());
      } else if (joinDateValue is DateTime) {
        joinDate = DateFormat('MMMM yyyy').format(joinDateValue);
      }
    }
    
    return CommonLayout(
      selectedIndex: 3, // Profile is index 3 in the bottom navigation
      child: userData == null
          ? _buildLoginView(context)
          : SingleChildScrollView(
            // Webböngészőben letiltjuk a görgetést, hogy ne legyen lehetséges a profil oldalon
            physics: kIsWeb ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
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
          AppLocalizations.of(context)!.joinedIn(joinDate),
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.black54,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Card(
          color: Theme.of(context).brightness == Brightness.dark ? const Color.fromARGB(255, 32, 32, 32) : Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileItem(
                  context,
                  AppLocalizations.of(context)!.email,
                  userData['email'] ?? AppLocalizations.of(context)!.noEmailProvided,
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
                  AppLocalizations.of(context)!.favoriteNationalTeam,
                  userData['favoriteNationalTeam'] ?? userData['favoriteLeague'] ?? AppLocalizations.of(context)!.noNationalTeamSelected,
                  Icons.flag,
                            Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                ),
              ],
            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Main action buttons with responsive layout
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate button height based on screen width
                        final buttonHeight = constraints.maxWidth < 350 ? 40.0 : 44.0;
                        final fontSize = constraints.maxWidth < 350 ? 13.0 : 14.0;
                        
                        return Column(
                          children: [
                            // Edit Profile/Confirm button
                            SizedBox(
                              key: _editProfileButtonKey,
                              width: double.infinity,
                              height: buttonHeight,
                              child: ElevatedButton.icon(
                                icon: Icon(
                                  _isEditMode ? Icons.check : Icons.edit, 
                                  size: 20, 
                                  color: Colors.black
                                ),
                                label: AnimatedCrossFade(
                                  firstChild: Text(
                                    AppLocalizations.of(context)!.editProfile, 
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    )
                                  ),
                                  secondChild: Text(
                                    AppLocalizations.of(context)!.confirm, 
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    )
                                  ),
                                  crossFadeState: _isEditMode 
                                      ? CrossFadeState.showSecond 
                                      : CrossFadeState.showFirst,
                                  duration: const Duration(milliseconds: 300),
                                ),
                                onPressed: () => _toggleEditMode(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFE6AC),
                                  foregroundColor: Colors.black,
                                  elevation: 5,
                                  shadowColor: Colors.black.withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(buttonHeight / 2),
                                  ),
                                ),
                              ),
                            ),
                            
                            // Animated space for Cancel button
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: _isEditMode ? 12 : 0,
                              curve: Curves.easeInOut,
                            ),
                            
                            // Cancel button that appears in edit mode
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: _isEditMode ? buttonHeight : 0,
                              curve: Curves.easeInOut,
                              child: AnimatedOpacity(
                                opacity: _isEditMode ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 250),
                                child: SizedBox(
                                  key: _cancelButtonKey,
                                  width: double.infinity,
                                  height: _isEditMode ? buttonHeight : 0,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.close, 
                                      size: 20, 
                                      color: Color(0xFFFFE6AC),
                                    ),
                                    label: Text(
                                      AppLocalizations.of(context)!.cancel, 
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      )
                                    ),
                                    onPressed: () => _cancelEditMode(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).brightness == Brightness.dark 
                                          ? const Color(0xFF1D1D1D) 
                                          : Colors.white,
                                      foregroundColor: const Color(0xFFFFE6AC),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(buttonHeight / 2),
                                        side: const BorderSide(color: Color(0xFFFFE6AC), width: 2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Row with Logout and Delete Account buttons
                            Row(
                              children: [
                                // Logout Button - Animated slide
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: _isEditMode ? 0 : constraints.maxWidth / 2 - 5,
                                  height: buttonHeight,
                                  curve: Curves.easeInOut,
                                  child: AnimatedOpacity(
                                    opacity: _isEditMode ? 0.0 : 1.0,
                                    duration: const Duration(milliseconds: 300),
                                    child: OverflowBox(
                                      maxWidth: constraints.maxWidth / 2 - 5,
                                      maxHeight: buttonHeight,
                                      child: SizedBox(
                                        key: _logoutButtonKey,
                                        height: buttonHeight,
                                        child: ElevatedButton.icon(
                                          icon: Icon(
                                            Icons.logout, 
                                            size: constraints.maxWidth < 350 ? 16 : 20,
                                            color: Theme.of(context).brightness == Brightness.dark 
                                                ? const Color(0xFFFFE6AC) 
                                                : Colors.black,
                                          ),
                                          label: Text(
                                            AppLocalizations.of(context)!.logOut, 
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: fontSize,
                                              color: Theme.of(context).brightness == Brightness.dark 
                                                  ? const Color(0xFFFFE6AC) 
                                                  : Colors.black,
                                            )
                                          ),
                                          onPressed: _isEditMode ? null : () => _signOut(context),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Theme.of(context).brightness == Brightness.dark 
                                                ? const Color(0xFF1D1D1D) 
                                                : Colors.white,
                                            foregroundColor: const Color(0xFFFFE6AC),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(buttonHeight / 2),
                                              side: const BorderSide(color: Color(0xFFFFE6AC), width: 2),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Center spacer that grows when buttons slide out
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: _isEditMode ? constraints.maxWidth : 10,
                                  curve: Curves.easeInOut,
                                ),
                                
                                // Delete Account Button - Animated slide
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: _isEditMode ? 0 : constraints.maxWidth / 2 - 5,
                                  height: buttonHeight,
                                  curve: Curves.easeInOut,
                                  child: AnimatedOpacity(
                                    opacity: _isEditMode ? 0.0 : 1.0,
                                    duration: const Duration(milliseconds: 300),
                                    child: OverflowBox(
                                      maxWidth: constraints.maxWidth / 2 - 5,
                                      maxHeight: buttonHeight,
                                      child: SizedBox(
                                        key: _deleteButtonKey,
                                        height: buttonHeight,
                                        child: ElevatedButton.icon(
                                          icon: Icon(
                                            Icons.delete_forever, 
                                            size: constraints.maxWidth < 350 ? 16 : 20,
                                            color: Colors.white,
                                          ),
                                          label: Text(
                                            AppLocalizations.of(context)!.delete, 
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: fontSize,
                                            )
                                          ),
                                          onPressed: _isEditMode ? null : () => _showDeleteAccountDialog(context),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade600,
                                            foregroundColor: Colors.white,
                                            elevation: 5,
                                            shadowColor: Colors.black.withOpacity(0.3),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(buttonHeight / 2),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
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
    _refreshUserData();
    _preloadTeamsAndLeagues();  // Preload the data
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
    _nameController.dispose();
    _emailController.dispose();
    _profileImage = null;
    _webImagePath = null;
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _uploadProfilePicture() async {
    try {
      if (_profileImage == null && _webImagePath == null) return;
      
      // Show uploading message
      MessageService.showMessage(
        context,
        message: 'Uploading profile picture...',
        type: MessageType.info,
      );
      
      setState(() {
        _isLoadingImage = true;
      });
      
      final provider = Provider.of<FirebaseProvider>(context, listen: false);
      final userId = provider.currentUser?.uid;
      
      if (userId == null) return;
      
      final storageRef = FirebaseStorage.instance.ref('profile_pictures/$userId.jpg');
      
      if (kIsWeb) {
        if (_webImagePath == null) return;
        
        // For web, we upload the selected file using putString
        final bytes = await rootBundle.load(_webImagePath!);
        await storageRef.putData(
          bytes.buffer.asUint8List(),
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // For mobile, use the File object
        await storageRef.putFile(_profileImage!);
      }
      
      // Get the download URL and update user profile
      final downloadUrl = await storageRef.getDownloadURL();
      await provider.updateProfilePictureUrl(downloadUrl);
      
      setState(() {
        _isLoadingImage = false;
      });
      
      // Show success message
      MessageService.showMessage(
        context,
        message: 'Profile picture updated successfully',
        type: MessageType.success,
      );
      
    } catch (e) {
      setState(() {
        _isLoadingImage = false;
      });
      
      // Show error message
      MessageService.showMessage(
        context,
        message: 'Failed to upload profile picture: ${e.toString()}',
        type: MessageType.error,
      );
    }
  }

  Future<void> _pickImage(BuildContext context) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (pickedFile == null) return;
      
      if (kIsWeb) {
        // For web, store the path
        setState(() {
          _webImagePath = pickedFile.path;
        });
      } else {
        // For mobile, create a File object
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
      
      // Upload the image
      await _uploadProfilePicture();
      
    } catch (e) {
      // Show error message
      MessageService.showMessage(
        context,
        message: 'Error selecting image: ${e.toString()}',
        type: MessageType.error,
      );
    }
  }

  Widget _buildProfileItem(BuildContext context, String label, String value, IconData icon, Color textColor) {
    final bool isNameField = label == AppLocalizations.of(context)!.profileName;
    final bool isTeamField = label == AppLocalizations.of(context)!.favTeam;
    final bool isNationalTeamField = label == AppLocalizations.of(context)!.favoriteNationalTeam;
    final bool isEmailField = label == AppLocalizations.of(context)!.email;
    
    // Calculate if this field is currently being edited
    final bool isFieldBeingEdited = _isEditMode && _currentlyEditingField == label && isNameField;
    
    // Use pending changes if available for each field type
    String displayValue;
    if (isNameField && _pendingNameChange != null) {
      displayValue = _pendingNameChange!;
    } else if (isTeamField && _selectedTeam != null) {
      displayValue = _selectedTeam!['name'] ?? value;
    } else if (isNationalTeamField && _selectedLeague != null) {
      displayValue = _selectedLeague!['name'] ?? value;
    } else {
      displayValue = value;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    // Show name TextField only when this specific field is being edited
                    if (isFieldBeingEdited)
                      TextField(
                        controller: _nameController,
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: goldColor),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: goldColor),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: goldColor, width: 2),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check, size: 18),
                            color: goldColor,
                            onPressed: () {
                              setState(() {
                                // Store the pending name change
                                _pendingNameChange = _nameController.text;
                                _currentlyEditingField = null; // Close editing
                              });
                            },
                          ),
                        ),
                      )
                    else if (_isEditMode && (isNameField || isTeamField || isNationalTeamField))
                      // For name/team/league, show a button to open the selection dialog
                      InkWell(
                        onTap: () {
                          if (isNameField) {
                            setState(() {
                              // Initialize the controller with the current display value
                              _nameController.text = displayValue;
                              _currentlyEditingField = label;
                            });
                          } else if (isTeamField) {
                            _showTeamSelectionDialogForEdit(context);
                          } else if (isNationalTeamField) {
                            _showLeagueSelectionDialogForEdit(context);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  displayValue,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(Icons.edit, color: goldColor, size: 18),
                            ],
                          ),
                        ),
                      )
                    else if (_isEditMode && isEmailField)
                      // Email is typically not editable after registration
                      Container(
                        height: 40, // Fixed height to match other fields
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                value,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textColor.withOpacity(0.7), // Dimmed to indicate not editable
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Tooltip(
                              message: 'Email cannot be changed after registration',
                              child: Icon(Icons.info_outline, color: Colors.grey, size: 18),
                            ),
                          ],
                        ),
                      )
                    else
                      // Regular text in non-edit mode (or any other field)
                      Container(
                        height: 40, // Fixed height for consistency
                        alignment: Alignment.centerLeft,
                        child: Text(
                          displayValue,
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          // Add Change Password button below the email field when in edit mode
          if (isEmailField && _isEditMode)
            Padding(
              padding: const EdgeInsets.only(top: 12.0, left: 39.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: goldColor, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton.icon(
                  icon: const Icon(Icons.lock_outline, size: 16),
                  label: const Text('Change Password'),
                  onPressed: () => _showChangePasswordDialog(context),
                  style: TextButton.styleFrom(
                    foregroundColor: goldColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showRegistrationFlow(BuildContext context) async {
    // Show a series of dialogs to collect user information
    try {
      // Step 1: Collect email and password
      final credentials = await _showEmailPasswordDialog(context);
      if (credentials == null) return;

      // Step 2: Collect full name
      final fullName = await _showNameDialog(context);
      if (fullName == null || fullName.isEmpty) return;

      // Step 3: Collect username
      final username = await _showUsernameDialog(context);
      if (username == null || username.isEmpty) return;

      // Step 4: Select favorite team
      final favoriteTeam = await _showTeamSelectionDialog(context);
      if (favoriteTeam == null) return;

      // Step 5: Select national team (league)
      final nationalTeam = await _showNationalTeamSelectionDialog(context);
      if (nationalTeam == null) return;

      // Complete the registration process
      final firebaseProvider = Provider.of<FirebaseProvider>(context, listen: false);
      
      // Use our MessageService instead of SnackBar
      final success = await firebaseProvider.completeSignUp(
        email: credentials['email']!,
        password: credentials['password']!,
        name: fullName,
        username: username,
        favoriteTeam: favoriteTeam['name'],
        favoriteTeamId: favoriteTeam['id'].toString(),
        favoriteLeague: nationalTeam['name'],
        favoriteNationalTeamId: nationalTeam['id'].toString(),
      );
      
      if (success && context.mounted) {
        // Use our MessageService instead of SnackBar
        MessageService.showMessage(
          context,
          message: 'Registration completed successfully',
          type: MessageType.success,
        );
        
        // Reload the profile page by navigating back to itself
        if (context.mounted) {
          // Delay the navigation slightly to allow Firebase to complete its state updates
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            }
          });
        }
      }
    } catch (e) {
      if (context.mounted) {
        MessageService.showMessage(
          context,
          message: 'Registration failed: ${e.toString()}',
          type: MessageType.error,
        );
      }
    }
  }

  Future<Map<String, String>?> _showEmailPasswordDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;

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
                onSubmitted: !isLoading ? (_) => _performRegistration(context, setState, emailController, passwordController, confirmPasswordController, isLoading) : null,
              ),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: obscurePassword,
                enabled: !isLoading,
                onSubmitted: !isLoading ? (_) => _performRegistration(context, setState, emailController, passwordController, confirmPasswordController, isLoading) : null,
              ),
              TextField(
                controller: confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword = !obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                obscureText: obscureConfirmPassword,
                enabled: !isLoading,
                onSubmitted: !isLoading ? (_) => _performRegistration(context, setState, emailController, passwordController, confirmPasswordController, isLoading) : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isLoading ? null : () => _performRegistration(context, setState, emailController, passwordController, confirmPasswordController, isLoading),
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to handle the registration step
  Future<void> _performRegistration(
    BuildContext context, 
    StateSetter setState, 
    TextEditingController emailController, 
    TextEditingController passwordController,
    TextEditingController confirmPasswordController, 
    bool isLoading
  ) async {
    if (passwordController.text != confirmPasswordController.text) {
      MessageService.showMessage(
        context,
        message: 'Passwords do not match',
        type: MessageType.error,
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(emailController.text);
      if (methods.isNotEmpty) {
        MessageService.showMessage(
          context,
          message: 'Email already in use',
          type: MessageType.error,
        );
        setState(() => isLoading = false);
        return;
      }
      Navigator.pop(context, {
        'email': emailController.text,
        'password': passwordController.text,
      });
    } catch (e) {
      MessageService.showMessage(
        context,
        message: 'Error checking email: $e',
        type: MessageType.error,
      );
      setState(() => isLoading = false);
    }
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
                MessageService.showMessage(
                  context,
                  message: 'Please enter a username',
                  type: MessageType.error,
                );
              }
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showTeamSelectionDialog(BuildContext context) async {
    List<Map<String, dynamic>>? teams = _cachedTeams;
    Map<String, dynamic>? selectedTeam;
    bool isLoading = teams == null;
    // Keresési szöveg és szűrt csapatok listájának hozzáadása
    String searchQuery = '';
    List<Map<String, dynamic>> filteredTeams = [];

    if (teams == null) {
      try {
        teams = await FootballApiService.getTeams();
        isLoading = false;
      } catch (e) {
        print('Error loading teams: $e');
        isLoading = false;
      }
    }
    
    // Inicializáljuk a szűrt listát az összes csapattal
    if (teams != null) {
      filteredTeams = List.from(teams);
    }

    // Get screen size to make dialog properly responsive
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    // Adjust dialog width based on screen size
    final dialogWidth = isSmallScreen
        ? math.min(400.0, screenSize.width * 0.9)  // Mobile: 90% of screen width up to 400px
        : math.min(450.0, screenSize.width * 0.7); // Desktop: 70% of screen width up to 450px

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Your Favorite Team'),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          content: SizedBox(
            width: dialogWidth,
            height: 400, // Slightly taller than before
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Keresősáv hozzáadása
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search teams...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                        // Csapatok szűrése a keresési kifejezés alapján
                        if (teams != null) {
                          filteredTeams = teams.where((team) => 
                            team['name']?.toLowerCase().contains(searchQuery) ?? false
                          ).toList();
                        }
                      });
                    },
                  ),
                ),
                if (isLoading)
                  const CircularProgressIndicator()
                else if (teams == null || teams.isEmpty)
                  const Text('Failed to load teams')
                else
                  Expanded(
                    child: filteredTeams.isEmpty
                      ? const Center(child: Text('No matching teams found'))
                      : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isSmallScreen ? 3 : 4, // 3 columns on mobile, 4 on desktop
                          childAspectRatio: 0.75, // Slightly better than 0.7
                          crossAxisSpacing: 4, // Increased from 3
                          mainAxisSpacing: 4, // Increased from 3
                        ),
                        itemCount: filteredTeams.length,
                        itemBuilder: (context, index) {
                          final team = filteredTeams[index];
                          final isSelected = selectedTeam == team;
                          return InkWell(
                            onTap: () {
                              setState(() => selectedTeam = team);
                            },
                            child: Card(
                              color: isSelected ? Colors.blue.withOpacity(0.3) : null,
                              margin: const EdgeInsets.all(2), // Back to 2px margins
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    team['crest'] ?? '',
                                    height: 36,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.sports_soccer, size: 36),
                                  ),
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Text(
                                      team['name'] ?? 'Unknown Team',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 9.0 : 9.5,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
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

  Future<Map<String, dynamic>?> _showNationalTeamSelectionDialog(BuildContext context) async {
    Completer<Map<String, dynamic>?> completer = Completer<Map<String, dynamic>?>();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: FootballApiService.getNationalTeams(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              // Hiba esetén, vagy ha üres a lista, használjuk a fallback adatokat
              print('Error loading national teams: ${snapshot.error}');
              return _buildNationalTeamDialog(context, FootballApiService.getNationalTeams(useFallback: true), completer);
            }
            
            // A sikeres lekérdezés adataival építjük fel a dialógust
            return _buildNationalTeamDialog(context, Future.value(snapshot.data!), completer);
          },
        );
      },
    );
    
    return completer.future;
  }
  
  Widget _buildNationalTeamDialog(BuildContext context, Future<List<Map<String, dynamic>>> teamsFuture, Completer<Map<String, dynamic>?> completer) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    // Adjust dialog width based on screen size
    final dialogWidth = isSmallScreen
        ? math.min(400.0, screenSize.width * 0.9)  // Mobile: 90% of screen width up to 400px
        : math.min(450.0, screenSize.width * 0.7); // Desktop: 70% of screen width up to 450px
    
    // Keresőszöveg kontrollere
    TextEditingController searchController = TextEditingController();
    ValueNotifier<String> searchText = ValueNotifier<String>('');
    
    return AlertDialog(
      title: Column(
        children: [
          const Text('Válassz nemzeti csapatot'),
          const SizedBox(height: 8),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Keresés...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (value) {
              searchText.value = value.toLowerCase();
            },
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      content: SizedBox(
        width: dialogWidth,
        height: 400,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: teamsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError || !snapshot.hasData) {
              return const Center(
                child: Text('Hiba történt a csapatok betöltése során'),
              );
            }
            
            List<Map<String, dynamic>> teams = snapshot.data!;
            
            return ValueListenableBuilder<String>(
              valueListenable: searchText,
              builder: (context, search, child) {
                List<Map<String, dynamic>> filteredTeams = teams
                    .where((team) => 
                        team['name'].toString().toLowerCase().contains(search))
                    .toList();
                
                // ABC sorrendbe rendezés a nevek alapján
                filteredTeams.sort((a, b) => 
                    (a['name'] as String).compareTo(b['name'] as String));
                
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isSmallScreen ? 3 : 4,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: filteredTeams.length,
                  itemBuilder: (context, index) {
                    Map<String, dynamic> team = filteredTeams[index];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedLeague = team;
                        });
                        Navigator.of(context).pop();
                        completer.complete(team);
                      },
                      child: Card(
                        margin: const EdgeInsets.all(2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              team['crest'] ?? '',
                              height: 36,
                              errorBuilder: (context, error, stackTrace) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.flag, size: 36),
                                    if (team['countryCode'] != null)
                                      Text(
                                        team['countryCode'],
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.all(2),
                              child: Text(
                                team['name'] ?? '',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 9.0 : 9.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            completer.complete(null);
          },
          child: const Text('Mégse'),
        ),
      ],
    );
  }

  Future<void> _showLoginDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;
    bool obscurePassword = true;

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
                onSubmitted: !isLoading ? (_) => _performLogin(context, setState, emailController, passwordController, isLoading) : null,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: obscurePassword,
                enabled: !isLoading,
                onSubmitted: !isLoading ? (_) => _performLogin(context, setState, emailController, passwordController, isLoading) : null,
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
              onPressed: isLoading ? null : () => _performLogin(context, setState, emailController, passwordController, isLoading),
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to handle login logic
  Future<void> _performLogin(BuildContext context, StateSetter setState, 
      TextEditingController emailController, TextEditingController passwordController, bool isLoading) async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      MessageService.showMessage(
        context,
        message: 'Please fill in all fields',
        type: MessageType.error,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final success = await Provider.of<FirebaseProvider>(context, listen: false)
          .signIn(emailController.text, passwordController.text);
      
      // Close the dialog if login was successful
      if (success && context.mounted) {
        Navigator.pop(context); // Dismiss the dialog
        
        // Use our MessageService instead of SnackBar
        MessageService.showMessage(
          context,
          message: 'Login successful',
          type: MessageType.success,
        );
      } else if (context.mounted) {
        setState(() => isLoading = false);
        
        MessageService.showMessage(
          context,
          message: 'Login failed',
          type: MessageType.error,
        );
      }
      
    } catch (e) {
      setState(() => isLoading = false);
      if (context.mounted) {
        MessageService.showMessage(
          context,
          message: 'Login failed',
          type: MessageType.error,
        );
      }
      print(e);
    }
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 28),
            const SizedBox(width: 10),
            const Text('Delete Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.deleteAccountConfirm,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16, 
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone. All your data will be permanently removed.',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _handleDeleteAccount(context);
            },
            child: Text(AppLocalizations.of(context)!.delete, style: const TextStyle(fontWeight: FontWeight.bold)),
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
        MessageService.showMessage(
          context,
          message: 'Account deleted successfully',
          type: MessageType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        MessageService.showMessage(
          context,
          message: 'Error deleting account: ${e.toString()}',
          type: MessageType.error,
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
        MessageService.showMessage(
          context,
          message: 'Profile picture removed',
          type: MessageType.success,
        );
      }
    } catch (e) {
      print('Error removing profile picture: $e');
      if (context.mounted) {
        MessageService.showMessage(
          context,
          message: 'Failed to remove profile picture: ${e.toString()}',
          type: MessageType.error,
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
    MessageService.showMessage(
      context,
      message: 'Edit profile feature coming soon',
      type: MessageType.info,
    );
  }

  void _signOut(BuildContext context) async {
    final provider = Provider.of<FirebaseProvider>(context, listen: false);
    try {
      await provider.signOut();
      if (context.mounted) {
        // Navigate to login page or show a success message
        MessageService.showMessage(
          context,
          message: 'Signed out successfully',
          type: MessageType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        MessageService.showMessage(
          context,
          message: 'Error signing out: ${e.toString()}',
          type: MessageType.error,
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

  // Method to build the login/register view when user is not logged in
  Widget _buildLoginView(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final fontSizeProvider = Provider.of<FontSizeProvider>(context);
    final baseFontSize = fontSizeProvider.fontSize;
    final backgroundColor = isDarkMode ? const Color(0xFF1D1D1D) : Colors.white;
    
    // Calculate button dimensions based on font size
    final buttonWidth = 180 + (baseFontSize - 16) * 5; // Starts at 180px at default font size (16)
    final buttonHeight = 44 + (baseFontSize - 16) * 2; // Starts at 44px at default font size (16)
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text(
              'Welcome to Footify!',
              style: TextStyle(
                fontSize: baseFontSize * 1.7, // Responsive font size
                fontWeight: FontWeight.bold,
                color: isDarkMode ? const Color(0xFFFFE6AC) : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'Sign in or create an account to save your favorite teams and personalize your experience.',
              style: TextStyle(
                fontSize: baseFontSize,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: buttonWidth,
              height: buttonHeight,
              child: ElevatedButton(
                onPressed: () => _showLoginDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFE6AC),
                  foregroundColor: Colors.black,
                  elevation: 5,
                  shadowColor: Colors.black.withOpacity(0.3),
                  padding: EdgeInsets.symmetric(
                    horizontal: baseFontSize * 0.75,
                    vertical: baseFontSize * 0.3,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(buttonHeight / 2), // Fully rounded corners
                  ),
                ),
                child: Text(
                  'Login',
                  style: TextStyle(
                    fontSize: baseFontSize * 1.1, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SizedBox(height: baseFontSize),
            SizedBox(
              width: buttonWidth,
              height: buttonHeight,
              child: ElevatedButton(
                onPressed: () => _showRegistrationFlow(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: backgroundColor, // Match app background color
                  foregroundColor: isDarkMode ? const Color(0xFFFFE6AC) : (Colors.black), // Yellowish text in dark mode, black in light mode
                  elevation: 0, // No shadow for outline style
                  padding: EdgeInsets.symmetric(
                    horizontal: baseFontSize * 0.75,
                    vertical: baseFontSize * 0.3,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(buttonHeight / 2), // Fully rounded corners
                    side: const BorderSide(color: Color(0xFFFFE6AC), width: 2),
                  ),
                ),
                child: Text(
                  'Register',
                  style: TextStyle(
                    fontSize: baseFontSize * 1.1,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Preload teams and leagues data when profile page is initialized
  Future<void> _preloadTeamsAndLeagues() async {
    try {
      // Nemzeti csapatok betöltése
      _cachedLeagues = await FootballApiService.getNationalTeams();
      if (_cachedLeagues != null && _cachedLeagues!.isNotEmpty) {
        print('Preloaded ${_cachedTeams?.length ?? 0} teams and ${_cachedLeagues?.length ?? 0} national teams');
      }
      
      // Klubcsapatok betöltése
      _cachedTeams = await FootballApiService.getTeams();
      
    } catch (e) {
      print('Error preloading data: $e');
    }
  }

  // Add this method for team selection in edit mode
  Future<void> _showTeamSelectionDialogForEdit(BuildContext context) async {
    final team = await _showTeamSelectionDialog(context);
    if (team != null && mounted) {
      setState(() {
        // We'll store this selection temporarily and apply it on confirm
        _selectedTeam = team;
      });
    }
  }

  // Add this method for league selection in edit mode
  Future<void> _showLeagueSelectionDialogForEdit(BuildContext context) async {
    final Completer<Map<String, dynamic>?> completer = Completer<Map<String, dynamic>?>();
    
    // Mindig a fallback listát használjuk, hogy ugyanazok a csapatok jelenjenek meg, mint a regisztrációnál
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _buildNationalTeamDialog(
          context, 
          FootballApiService.getNationalTeams(useFallback: true), 
          completer
        );
      },
    );
    
    final nationalTeam = await completer.future;
    if (nationalTeam != null && mounted) {
      setState(() {
        // We'll store this selection temporarily and apply it on confirm
        _selectedLeague = nationalTeam;
      });
    }
  }

  // Add the _toggleEditMode method
  void _toggleEditMode(BuildContext context) async {
    final provider = Provider.of<FirebaseProvider>(context, listen: false);
    final userData = provider.userData;
    
    // If we're turning on edit mode, initialize the controllers
    if (!_isEditMode) {
      _nameController.text = userData?['name'] ?? '';
      _emailController.text = userData?['email'] ?? '';
      
      // Store original values
      if (userData != null) {
        final teamName = userData['favoriteTeam'];
        final teamId = userData['favoriteTeamId'];
        if (teamName != null && teamId != null) {
          _originalTeam = {
            'name': teamName,
            'id': teamId,
          };
        }
        
        // Most már favoriteNationalTeam-ként van tárolva az adatbázisban
        final nationalTeamName = userData['favoriteNationalTeam'] ?? userData['favoriteLeague']; // Visszafele kompatibilitás
        if (nationalTeamName != null) {
          _originalLeague = {
            'name': nationalTeamName,
          };
        }
      }
      
      // Clear temporary selections
      _selectedTeam = null;
      _selectedLeague = null;
      _currentlyEditingField = null;
      _pendingNameChange = null;
      
      setState(() {
        _isEditMode = true;
      });
    } else {
      // Confirm edits and save changes
      final Map<String, dynamic> updates = {};
      
      // Only add changed fields - use pending name if available
      if (_pendingNameChange != null && _pendingNameChange != (userData?['name'] ?? '')) {
        updates['name'] = _pendingNameChange;
      }
      
      // Add team/league changes if they were updated
      if (_selectedTeam != null) {
        updates['favoriteTeam'] = _selectedTeam!['name'];
        updates['favoriteTeamId'] = _selectedTeam!['id'];
      }
      
      if (_selectedLeague != null) {
        // Már favoriteNationalTeam-ként mentjük az adatbázisba
        updates['favoriteNationalTeam'] = _selectedLeague!['name'];
        updates['favoriteNationalTeamId'] = _selectedLeague!['id'];
      }
      
      // Save changes if there are any
      if (updates.isNotEmpty) {
        try {
          await provider.updateUserProfile(updates);
          
          // Refresh user data after update
          await provider.refreshUserData();
          
          if (mounted) {
            MessageService.showMessage(
              context,
              message: 'Profile updated successfully',
              type: MessageType.success,
            );
          }
        } catch (e) {
          if (mounted) {
            MessageService.showMessage(
              context,
              message: 'Error updating profile: ${e.toString()}',
              type: MessageType.error,
            );
          }
        }
      }
      
      setState(() {
        _isEditMode = false;
        _currentlyEditingField = null;
        _pendingNameChange = null;
        _selectedTeam = null;
        _selectedLeague = null;
        _originalTeam = null;
        _originalLeague = null;
      });
    }
  }

  // Add the _cancelEditMode method
  void _cancelEditMode(BuildContext context) {
    setState(() {
      _isEditMode = false;
      _currentlyEditingField = null;
      _pendingNameChange = null;
      // Revert to original values if selections were made
      _selectedTeam = null;
      _selectedLeague = null;
      _originalTeam = null;
      _originalLeague = null;
    });
  }

  // Method to show change password dialog
  void _showChangePasswordDialog(BuildContext context) {
    // Clear previous password entries
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    
    // Error states
    bool isCurrentPasswordError = false;
    bool isNewPasswordError = false;
    bool isConfirmPasswordError = false;
    String? errorText;
    
    // Password visibility toggles
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    bool isLoading = false;
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Current Password
                    TextField(
                      controller: _currentPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        errorText: isCurrentPasswordError ? 'Current password is required' : null,
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrentPassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () {
                            setState(() {
                              obscureCurrentPassword = !obscureCurrentPassword;
                            });
                          },
                        ),
                        enabled: !isLoading,
                      ),
                      obscureText: obscureCurrentPassword,
                      onSubmitted: !isLoading ? (_) {} : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // New Password
                    TextField(
                      controller: _newPasswordController,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        errorText: isNewPasswordError ? 'Password must be at least 6 characters' : null,
                        suffixIcon: IconButton(
                          icon: Icon(obscureNewPassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () {
                            setState(() {
                              obscureNewPassword = !obscureNewPassword;
                            });
                          },
                        ),
                        enabled: !isLoading,
                      ),
                      obscureText: obscureNewPassword,
                      onSubmitted: !isLoading ? (_) {} : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '*', 
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            )
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Password must be at least 6 characters',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Confirm New Password
                    TextField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        errorText: isConfirmPasswordError ? 'Passwords do not match' : null,
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () {
                            setState(() {
                              obscureConfirmPassword = !obscureConfirmPassword;
                            });
                          },
                        ),
                        enabled: !isLoading,
                      ),
                      obscureText: obscureConfirmPassword,
                      onSubmitted: !isLoading ? (_) {} : null,
                    ),
                    
                    // Display error message if any
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          errorText!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      
                    // Show loading indicator when processing
                    if (isLoading) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    // Reset error states
                    setState(() {
                      isCurrentPasswordError = _currentPasswordController.text.isEmpty;
                      isNewPasswordError = _newPasswordController.text.length < 6;
                      isConfirmPasswordError = _newPasswordController.text != _confirmPasswordController.text;
                      errorText = null;
                      
                      // Set loading state if validation passes
                      if (!isCurrentPasswordError && !isNewPasswordError && !isConfirmPasswordError) {
                        isLoading = true;
                      }
                    });
                    
                    // Check for validation errors
                    if (isCurrentPasswordError || isNewPasswordError || isConfirmPasswordError) {
                      return;
                    }
                    
                    // Attempt to change password
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        // Get credentials with current password for reauthentication
                        final credential = EmailAuthProvider.credential(
                          email: user.email!,
                          password: _currentPasswordController.text,
                        );
                        
                        // Reauthenticate user
                        await user.reauthenticateWithCredential(credential);
                        
                        // Update password
                        await user.updatePassword(_newPasswordController.text);
                        
                        // Close dialog
                        Navigator.of(context).pop();
                        
                        // Show success message
                        MessageService.showMessage(
                          context,
                          message: 'Password updated successfully',
                          type: MessageType.success,
                        );
                      }
                    } on FirebaseAuthException catch (e) {
                      setState(() {
                        isLoading = false;
                        if (e.code == 'wrong-password') {
                          isCurrentPasswordError = true;
                          errorText = 'Current password is incorrect';
                        } else if (e.code == 'weak-password') {
                          isNewPasswordError = true;
                          errorText = 'New password is too weak';
                        } else {
                          errorText = 'Error: ${e.message}';
                        }
                      });
                    } catch (e) {
                      setState(() {
                        isLoading = false;
                        errorText = 'An unexpected error occurred: $e';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE6AC),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Update Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}