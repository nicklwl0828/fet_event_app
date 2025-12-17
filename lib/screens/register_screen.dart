// lib/screens/register_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String role = 'Student';
  bool isLoading = false;
  String? error;

  // Student pattern and staff whitelist
  final RegExp _studentRegex = RegExp(r'^[0-9]{8}@imail\.sunway\.edu\.my$', caseSensitive: false);
  final Set<String> _staffWhitelist = {
    'rosilaha@sunway.edu.my',
    'dennyng@sunway.edu.my',
    'rosdiadeen@sunway.edu.my',
    'jinnyf@sunway.edu.my',
  };

  Future<void> _handleRegister() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => error = 'Please fill in all fields.');
      return;
    }

    // role-specific validation
    if (role == 'Student') {
      if (!_studentRegex.hasMatch(email)) {
        setState(() => error = 'Student emails must be like 23005192@sunway.edu.my');
        return;
      }
    } else {
      // Staff selected
      if (!_staffWhitelist.contains(email)) {
        setState(() => error = 'This staff email is not authorised to register. Contact admin.');
        return;
      }
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // 1) Create Firebase Auth user
      final authResult = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = authResult.user;
      if (user == null) {
        throw Exception('Failed to create user account.');
      }

      // 2) Create Firestore user doc
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

      await userDoc.set({
        'name': name,
        'email': email,
        'role': role, // "Student" or "Staff"
        'created_at': FieldValue.serverTimestamp(),
      });

      // Optional: update FirebaseAuth displayName
      try {
        await user.updateDisplayName(name);
      } catch (_) {}

      if (!mounted) return;

      // Success — go back to login
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Please login.')),
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Registration failed: ${e.message ?? e.code}';
      // Friendly messages for common codes
      if (e.code == 'weak-password') {
        msg = 'Password is too weak.';
      } else if (e.code == 'email-already-in-use') {
        msg = 'This email is already registered.';
      } else if (e.code == 'invalid-email') {
        msg = 'Invalid email address.';
      }
      setState(() => error = msg);
    } catch (e) {
      setState(() => error = 'Registration failed: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Create account',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Student', child: Text('Student')),
                        DropdownMenuItem(value: 'Staff', child: Text('Staff')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => role = value);
                      },
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleRegister,
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Register'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
