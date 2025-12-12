import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckInScreen extends StatelessWidget {
  final String eventId; // Pass the event document ID

  const CheckInScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    final registrationsRef = FirebaseFirestore.instance
        .collection('registrations')
        .where('event_id', isEqualTo: eventId);

    return Scaffold(
      appBar: AppBar(title: const Text("Check-In Attendees")),
      body: StreamBuilder<QuerySnapshot>(
        stream: registrationsRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No RSVPs yet."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final attended = data['attended'] ?? false;

              return ListTile(
                title: Text(data['user_id'] ?? 'Unknown User'),
                subtitle: Text(attended ? "Attended ✅" : "Not checked-in"),
                trailing: !attended
                    ? ElevatedButton(
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('registrations')
                              .doc(docs[index].id)
                              .update({'attended': true});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Marked as attended!')),
                          );
                        },
                        child: const Text("Check-In"),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
