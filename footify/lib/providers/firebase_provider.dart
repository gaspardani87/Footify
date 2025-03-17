import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  // Getters
  User? get currentUser => _user;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;

  FirebaseProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Listen to auth state changes
      _auth.authStateChanges().listen((User? user) async {
        _user = user;
        if (user != null) {
          await _fetchUserData();
        } else {
          _userData = null;
          _isLoading = false;
          notifyListeners();
        }
      });

      // Initial check
      _user = _auth.currentUser;
      if (_user != null) {
        await _fetchUserData();
      } else {
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('Initialization error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchUserData() async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_user == null) {
        _userData = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      final doc = await _firestore.collection('users').doc(_user!.uid).get();

      if (doc.exists) {
        _userData = Map<String, dynamic>.from(doc.data()!);
        
        // We'll keep joinDate as it is from Firestore (Timestamp)
        // Just ensure it exists to avoid null pointer errors elsewhere
        if (!_userData!.containsKey('joinDate') || _userData!['joinDate'] == null) {
          // If joinDate is missing or null, add a default Timestamp value
          _userData!['joinDate'] = Timestamp.now();
        }
        
        print('Retrieved user data: $_userData');
      } else {
        print('No user document found');
        _userData = null;
      }
    } catch (e) {
      print('Error fetching user data: $e');
      _userData = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    if (_userData != null) {
      return _userData;
    }

    try {
      await _fetchUserData();
      return _userData;
    } catch (e) {
      print('Error in getUserData: $e');
      return null;
    }
  }

  // Sign Up
  Future<bool> completeSignUp({
    required String email,
    required String password,
    required String name,
    required String username,
    required String favoriteTeam,
    required String favoriteTeamId,  // Make sure this parameter exists
    required String favoriteLeague,
  }) async {
    try {
      // Create the user account with email and password
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;

      if (_user != null) {
        // Create user data document
        final userData = {
          'email': email,
          'name': name,
          'username': username,
          'favoriteTeam': favoriteTeam,
          'favoriteTeamId': favoriteTeamId,  // Make sure this field is included
          'favoriteLeague': favoriteLeague,
          'joinDate': FieldValue.serverTimestamp(),
          'uid': _user!.uid,
        };

        // Store user data in Firestore
        await _firestore.collection('users').doc(_user!.uid).set(userData);
        
        // Update local user data
        _userData = userData;
        notifyListeners();
        
        return true;
      }
      return false;
    } catch (e) {
      print('Error in completeSignUp: $e');
      rethrow;
    }
  }

  // Sign In
  Future<bool> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;
      if (_user != null) {
        await _fetchUserData();
      }
      notifyListeners();
      return true;
    } catch (e) {
      print('Sign in error: $e');
      return false;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _user = null;
      _userData = null;
      notifyListeners();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  // Load User Settings
  Future<void> loadUserSettings() async {
    if (_user == null) return;

    try {
      // Instead of using FirebaseService, fetch directly from Firestore
      // for consistency with how we create and update user data
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      
      if (doc.exists) {
        _userData = Map<String, dynamic>.from(doc.data()!);
        
        // We'll keep joinDate as it is from Firestore (Timestamp)
        // Just ensure it exists to avoid null pointer errors elsewhere
        if (!_userData!.containsKey('joinDate') || _userData!['joinDate'] == null) {
          // If joinDate is missing or null, add a default Timestamp value
          _userData!['joinDate'] = Timestamp.now();
        }
        
        print('User data refreshed: $_userData');
      } else {
        print('No user document found during refresh');
      }
      
      notifyListeners();
    } catch (e) {
      print('Error loading user settings: $e');
    }
  }

  // Update User Settings
  Future<void> updateUserSettings(Map<String, dynamic> newSettings) async {
    if (_user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _firebaseService.updateUserSettings(_user!.uid, newSettings);
      _userData = newSettings;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Toggle Favorite Team
  Future<void> toggleFavoriteTeam(String teamId) async {
    if (_user == null) return;

    try {
      await _firebaseService.toggleFavoriteTeam(_user!.uid, teamId);
      // Reload user settings to get updated favorites
      await loadUserSettings();
    } catch (e) {
      print('Error toggling favorite team: $e');
    }
  }

  // Get Favorite Teams
  Future<List<String>> getFavoriteTeams() async {
    if (_user == null) return [];

    try {
      return await _firebaseService.getFavoriteTeams(_user!.uid);
    } catch (e) {
      print('Error getting favorite teams: $e');
      return [];
    }
  }

  // Update User Profile
  Future<void> updateUserProfile(Map<String, dynamic> profileData) async {
    if (_user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _firebaseService.updateUserProfile(_user!.uid, profileData);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Check Username Availability
  Future<bool> isUsernameAvailable(String username) async {
    try {
      return await _firebaseService.isUsernameAvailable(username);
    } catch (e) {
      print('Error checking username availability: $e');
      rethrow;
    }
  }

  // Complete User Profile
  Future<void> completeUserProfile(
    String userId, {
    required String name,
    required String username,
    required String phoneNumber,
    required String favoriteTeam,
    required String favoriteLeague,
  }) async {
    try {
      print('Attempting to complete profile for user: $userId');
      await _firestore.collection('users').doc(userId).update({
        'name': name,
        'username': username,
        'phoneNumber': phoneNumber,
        'favoriteTeam': favoriteTeam,
        'favoriteLeague': favoriteLeague,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Profile completed successfully');
      await loadUserSettings();
    } catch (e) {
      print('Error in completeUserProfile: $e');
      rethrow;
    }
  }

  // Check if Profile is Completed
  Future<bool> isProfileCompleted(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['profileCompleted'] ?? false;
    } catch (e) {
      print('Error checking profile completion: $e');
      return false;
    }
  }

  // Delete Account
  Future<void> deleteAccount() async {
    try {
      if (_user != null) {
        await _firestore.collection('users').doc(_user!.uid).delete();
        await _user!.delete();
        await signOut();
      }
    } catch (e) {
      print('Delete account error: $e');
      throw e;
    }
  }

  // Upload Profile Image
  Future<String?> uploadProfileImage(File image) async {
    try {
      print('Starting profile image upload');
      
      if (_user == null) {
        print('Cannot upload image: User is not logged in');
        throw Exception('User is not logged in');
      }
      
      if (!image.existsSync()) {
        print('Cannot upload image: File does not exist at path: ${image.path}');
        throw Exception('Image file does not exist');
      }
      
      print('Uploading image from path: ${image.path}');
      
      // Reference to the storage location with a timestamp to avoid cache issues
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${_user!.uid}_$timestamp.jpg');
      
      // Create upload task with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': _user!.uid},
      );
      
      // Upload the file
      final uploadTask = storageRef.putFile(image, metadata);
      
      // Monitor the upload task
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      }, onError: (e) {
        print('Upload error during monitoring: $e');
      });
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      print('Upload completed successfully');
      
      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('Download URL retrieved: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      
      // Provide more detailed error information
      if (e.toString().contains('storage/unauthorized')) {
        print('Firebase Storage error: Unauthorized. Check Firebase Storage rules.');
      } else if (e.toString().contains('storage/canceled')) {
        print('Firebase Storage error: Upload canceled.');
      } else if (e.toString().contains('storage/unknown')) {
        print('Firebase Storage error: Unknown error occurred.');
      } else if (e.toString().contains('Platform._operatingSystem')) {
        print('Platform compatibility issue. This may be a limitation on this platform.');
      }
      
      return null;
    }
  }

  // Update Profile Picture URL
  Future<void> updateProfilePictureUrl(String? url) async {
    try {
      print('Updating profile picture URL in Firestore: $url');
      
      if (_user == null) {
        print('Cannot update profile picture: User is null');
        throw Exception('User is not logged in');
      }
      
      // Create the update data
      final Map<String, dynamic> updateData = {'profilePictureUrl': url};
      
      // Update the Firestore document
      await _firestore.collection('users').doc(_user!.uid).update(updateData);
      
      print('Firestore update successful');
      
      // If we have local user data, update it as well
      if (_userData != null) {
        _userData!['profilePictureUrl'] = url;
        print('Local user data updated');
      } else {
        print('Warning: Local user data is null, cannot update locally');
      }
      
      print('Profile picture URL updated successfully');
      
      // Notify listeners to update the UI
      notifyListeners();
    } catch (e) {
      print('Error updating profile picture URL: $e');
      throw Exception('Failed to update profile picture: $e');
    }
  }

  // Add a public method to fetch user data
  Future<void> refreshUserData() async {
    return _fetchUserData();
  }

  // Upload Profile Image Bytes (for web platforms)
  Future<String?> uploadProfileImageBytes(Uint8List bytes, String extension) async {
    try {
      print('Starting profile image upload from bytes');
      
      if (_user == null) {
        print('Cannot upload image: User is not logged in');
        throw Exception('User is not logged in');
      }
      
      if (bytes.isEmpty) {
        print('Cannot upload image: Byte array is empty');
        throw Exception('Image data is empty');
      }
      
      print('Uploading image bytes: ${bytes.length} bytes');
      
      // Reference to the storage location with a timestamp to avoid cache issues
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${_user!.uid}_$timestamp.$extension');
      
      // Create upload task with metadata
      final metadata = SettableMetadata(
        contentType: extension == 'jpg' ? 'image/jpeg' : 'image/${extension}',
        customMetadata: {'userId': _user!.uid},
      );
      
      // Upload the file bytes
      final uploadTask = storageRef.putData(bytes, metadata);
      
      // Monitor the upload task
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      }, onError: (e) {
        print('Upload error during monitoring: $e');
      });
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      print('Upload completed successfully');
      
      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('Download URL retrieved: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image bytes: $e');
      
      // Provide more detailed error information
      if (e.toString().contains('storage/unauthorized')) {
        print('Firebase Storage error: Unauthorized. Check Firebase Storage rules.');
      } else if (e.toString().contains('storage/canceled')) {
        print('Firebase Storage error: Upload canceled.');
      } else if (e.toString().contains('storage/unknown')) {
        print('Firebase Storage error: Unknown error occurred.');
      }
      
      return null;
    }
  }
}