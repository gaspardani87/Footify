import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign Up
  Future<UserCredential> signUp(String email, String password) async {
    try {
      // Create auth user - Firebase automatically encrypts the password
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create initial user document
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'name': '',
        'username': '',
        'phoneNumber': '',
        'favoriteTeam': '',
        'favoriteLeague': '',
        'settings': {
          'isDarkMode': false,
          'isColorBlindMode': false,
          'fontSize': 16.0,
        }
      });

      return userCredential;
    } catch (e) {
      print('Error during sign up: $e');
      rethrow;
    }
  }

  // Complete User Profile
  Future<void> completeUserProfile(String userId, {
    required String name,
    required String username,
    String? phoneNumber,
    required String favoriteTeam,
    required String favoriteLeague,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'name': name,
        'username': username,
        'phoneNumber': phoneNumber ?? '',
        'favoriteTeam': favoriteTeam,
        'favoriteLeague': favoriteLeague,
        'profileCompleted': true,
      });
    } catch (e) {
      print('Error completing profile: $e');
      rethrow;
    }
  }

  // Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    final QuerySnapshot result = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return result.docs.isEmpty;
  }

  // User Authentication
  Future<UserCredential> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } catch (e) {
      print('Error in FirebaseService signIn: $e'); // Debug print
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // User Settings
  Future<void> updateUserSettings(String userId, Map<String, dynamic> settings) async {
    await _firestore.collection('users').doc(userId).update({
      'settings': settings,
    });
  }

  Future<Map<String, dynamic>?> getUserSettings(String userId) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
    return doc.exists ? (doc.data() as Map<String, dynamic>)['settings'] : null;
  }

  // Favorites Management
  Future<void> toggleFavoriteTeam(String userId, String teamId) async {
    DocumentReference userRef = _firestore.collection('users').doc(userId);
    
    return _firestore.runTransaction((transaction) async {
      DocumentSnapshot userDoc = await transaction.get(userRef);
      List<String> favorites = List<String>.from(userDoc['favorites'] ?? []);
      
      if (favorites.contains(teamId)) {
        favorites.remove(teamId);
      } else {
        favorites.add(teamId);
      }
      
      transaction.update(userRef, {'favorites': favorites});
    });
  }

  Future<List<String>> getFavoriteTeams(String userId) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
    return doc.exists ? List<String>.from(doc['favorites'] ?? []) : [];
  }

  // User Profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> profileData) async {
    await _firestore.collection('users').doc(userId).update(profileData);
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
    return doc.exists ? doc.data() as Map<String, dynamic> : null;
  }
} 