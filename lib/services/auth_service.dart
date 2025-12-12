// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fire = FirebaseFirestore.instance;

  AuthService();

  /// Stream for auth state (used in main.dart)
  /// NOTE: userChanges() is a method on FirebaseAuth, so call it to get the stream.
  Stream<User?> get userChanges => _auth.userChanges();

  // Quick access to current user
  User? get currentUser => _auth.currentUser;

  // Student regex and staff whitelist (same logic as rules)
  final RegExp _studentRegex = RegExp(r'^[0-9]{8}@sunway\.edu\.my$', caseSensitive: false);
  final Set<String> _staffWhitelist = {
    'rosilaha@sunway.edu.my',
    'dennyng@sunway.edu.my',
    'rosdiadeen@sunway.edu.my',
    'jinnyf@sunway.edu.my',
  };

  bool _isStudentEmail(String? email) {
    if (email == null) return false;
    return _studentRegex.hasMatch(email.toLowerCase());
  }

  bool _isStaffWhitelisted(String? email) {
    if (email == null) return false;
    return _staffWhitelist.contains(email.toLowerCase());
  }

  /// Return role strings that match the rest of the app UI (capitalized).
  String _computeRoleForEmail(String? email) {
    if (email == null) return '';
    final e = email.toLowerCase();
    if (_isStudentEmail(e)) return 'Student'; // capitalized
    if (_isStaffWhitelisted(e)) return 'Staff'; // capitalized
    return ''; // unknown, leave blank so admin or rules can handle
  }

  /// Login: returns null on success, or an error message string
  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      // ensure users/{uid} exists and follows the rules (email/role)
      await _ensureUserDocIfMissing(_auth.currentUser);

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Login failed';
    } catch (e) {
      return e.toString();
    }
  }

  /// Register: keep compatibility with older calls (positional email/password).
  /// We compute the role based on email and write a safe doc.
  Future<String?> register(String email, String password, {String? name}) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = cred.user;
      if (user == null) return 'Registration failed';

      // Compute role based on the created user's email (safer)
      final actualEmail = user.email ?? email;
      final role = _computeRoleForEmail(actualEmail);

      final docRef = _fire.collection('users').doc(user.uid);
      await docRef.set({
        'name': name ?? '',
        'email': actualEmail,
        'role': role,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Registration failed';
    } catch (e) {
      return e.toString();
    }
  }

  /// Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Returns the Firestore DocumentSnapshot for the current user (or null)
  Future<DocumentSnapshot?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final snap = await _fire.collection('users').doc(user.uid).get();
      return snap;
    } catch (e) {
      rethrow;
    }
  }

  /// Ensure users/{uid} exists. Creates with a safe payload if missing.
  Future<void> _ensureUserDocIfMissing(User? user) async {
    if (user == null) return;
    final docRef = _fire.collection('users').doc(user.uid);
    final snap = await docRef.get();
    if (!snap.exists) {
      final actualEmail = user.email ?? '';
      final role = _computeRoleForEmail(actualEmail);
      await docRef.set({
        'name': user.displayName ?? '',
        'email': actualEmail,
        'role': role, // possibly '' if not recognized
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Optional public method if you want to call ensure from UI code
  Future<void> ensureUserDoc(User user) => _ensureUserDocIfMissing(user);
}
