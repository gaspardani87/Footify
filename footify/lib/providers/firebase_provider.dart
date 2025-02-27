import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  UserCredential? _tempUserCredential;

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
        _userData = doc.data();
        if (_userData!['joinDate'] != null) {
          _userData!['joinDate'] = (_userData!['joinDate'] as Timestamp).toDate();
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
  Future<bool> initiateSignUp(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;
      notifyListeners();
      return true;
    } catch (e) {
      print('Sign up initiation error: $e');
      return false;
    }
  }

  Future<bool> completeSignUp({
    required String name,
    required String username,
    String? phoneNumber,
    required String favoriteTeam,
    required String favoriteLeague,
  }) async {
    try {
      if (_user != null) {
        final userData = {
          'name': name,
          'username': username,
          'phoneNumber': phoneNumber ?? '',
          'favoriteTeam': favoriteTeam,
          'favoriteLeague': favoriteLeague,
          'joinDate': FieldValue.serverTimestamp(),
          'email': _user!.email,
          'uid': _user!.uid,
        };

        // Store data in Firestore
        await _firestore.collection('users').doc(_user!.uid).set(userData);
        
        // Update display name in Firebase Auth
        await _user!.updateDisplayName(name);
        
        print('User data saved successfully: $userData');
        return true;
      }
      return false;
    } catch (e) {
      print('Complete sign up error: $e');
      return false;
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
      _userData = await _firebaseService.getUserSettings(_user!.uid);
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

  // Add these new methods
  Future<bool> isUsernameAvailable(String username) async {
    try {
      return await _firebaseService.isUsernameAvailable(username);
    } catch (e) {
      print('Error checking username availability: $e');
      rethrow;
    }
  }

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

  // Method to check if profile is completed
  Future<bool> isProfileCompleted(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['profileCompleted'] ?? false;
    } catch (e) {
      print('Error checking profile completion: $e');
      return false;
    }
  }

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

  Future<String?> uploadProfileImage(File image) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('profile_images/${currentUser!.uid}.jpg');
      final uploadTask = storageRef.putFile(image);
      final snapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }
}