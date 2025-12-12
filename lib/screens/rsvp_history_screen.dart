import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'event_detail_screen.dart';

class RsvpHistoryScreen extends StatelessWidget {
  const RsvpHistoryScreen({super.key});

  String _formatTimestamp(Timestamp? t) {
    if (t == null) return '-';
    final dt = t.toDate();
    return DateFormat.yMMMd().add_jm().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
final user = auth.currentUser;

if (user == null) {
  return Scaffold(
    appBar: AppBar(title: const Text('My RSVPs')),
    body: const Center(child: Text('Not logged in')),
  );
}

final regsStream = FirebaseFirestore.instance
    .collection('registrations')
    .where('user_id', isEqualTo: user.uid)
    .orderBy('timestamp', descending: true)
    .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('My RSVPs')),
      body: StreamBuilder<QuerySnapshot>(
        stream: regsStream,
        builder: (context, regsSnap) {
          if (regsSnap.hasError) {
            return Center(child: Text('Error: ${regsSnap.error}'));
          }
          if (regsSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final regDocs = regsSnap.data?.docs ?? [];
          if (regDocs.isEmpty) {
            return const Center(child: Text('You have not RSVP’d to any events yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: regDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final regDoc = regDocs[i];
              final reg = regDoc.data() as Map<String, dynamic>;
              final eventId = reg['event_id'] as String?;
              final attended = reg['attended'] ?? false;
              final timestamp = reg['timestamp'] as Timestamp?;

              // For each registration we fetch the event doc (future)
              return FutureBuilder<DocumentSnapshot>(
                future: eventId == null
                    // ignore: null_argument_to_non_null_type
                    ? Future.value(null)
                    : FirebaseFirestore.instance.collection('events').doc(eventId).get(),
                builder: (c, eventSnap) {
                  final eventExists = eventSnap.hasData && eventSnap.data!.exists;
                  final eventData = eventExists ? eventSnap.data!.data() as Map<String, dynamic> : null;

                  final title = eventData?['title'] ?? (eventExists ? 'Untitled' : 'Event removed');
                  final startsAt = (eventData?['starts_at'] as Timestamp?)?.toDate();
                  final dateText = startsAt != null
                      ? DateFormat.yMMMd().add_jm().format(startsAt)
                      : '${eventData?['date'] ?? ''} ${eventData?['time'] ?? ''}';

                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      title: Text(title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(dateText),
                          const SizedBox(height: 4),
                          Text('RSVP at: ${_formatTimestamp(timestamp)}',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: attended
                          ? const Chip(label: Text('Attended'), backgroundColor: Colors.greenAccent)
                          : const Chip(label: Text('Not attended')),
                      onTap: eventId == null
                          ? null
                          : () {
                              // open event details (student view)
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventDetailScreen(eventId: eventId),
                                ),
                              );
                            },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
