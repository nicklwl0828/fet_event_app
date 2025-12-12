// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // <- added
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/login_screen.dart';
import 'screens/student_dashboard.dart';
import 'screens/staff_dashboard.dart';
import 'services/auth_service.dart'; // <- added

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FET Event App',

        // Global theme
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.deepPurple,
          textTheme: GoogleFonts.poppinsTextTheme(),

          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),

        home: const AuthWrapper(),
      ),
    );
  }
}

/// Decides whether to show:
/// - Login screen (not logged in)
/// - Staff dashboard
/// - Student dashboard
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder<User?>(
      stream: auth.userChanges,
      builder: (context, snapshot) {
        // Not logged in
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final user = snapshot.data!;

        // Ensure users/{uid} exists before we fetch it for role
        return FutureBuilder<void>(
          future: auth.ensureUserDoc(user),
          builder: (context, ensureSnap) {
            if (ensureSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // Now fetch the user doc once the ensure step is done.
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
              builder: (context, snapshot2) {
                if (snapshot2.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                if (snapshot2.hasError) {
                  return Scaffold(
                    body: Center(child: Text("Firestore Error: ${snapshot2.error}", style: const TextStyle(color: Colors.red))),
                  );
                }

                if (!snapshot2.hasData || !snapshot2.data!.exists) {
                  return Scaffold(
                    body: Center(
                      child: Text("User record not found in Firestore.\nPlease create /users/${user.uid}",
                          textAlign: TextAlign.center),
                    ),
                  );
                }

                final data = snapshot2.data!.data() as Map<String, dynamic>?;
                final role = data?['role'];

                if (role == null) {
                  return const Scaffold(
                    body: Center(child: Text("User role missing in Firestore.", style: TextStyle(color: Colors.red))),
                  );
                }

                if (role == "Staff") {
                  return const StaffDashboard();
                } else {
                  return const StudentDashboard();
                }
              },
            );
          },
        );
      },
    );
  }
}
