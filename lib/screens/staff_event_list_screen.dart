import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'create_event_screen.dart';
import 'staff_event_detail_screen.dart';

class StaffEventListScreen extends StatelessWidget {
  const StaffEventListScreen({super.key});

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final dt = ts.toDate();
    return DateFormat.yMMMd().add_jm().format(dt);
  }

  Widget _buildThumbnail(String? imageUrl) {
    final url = imageUrl ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: url.isNotEmpty
          ? Image.network(
              url,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            )
          : Container(
              width: 80,
              height: 80,
              color: Colors.pink[50],
              child: Icon(
                Icons.event,
                color: Colors.pink[200],
                size: 28,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated')),
      );
    }

    final eventsStream = FirebaseFirestore.instance
        .collection('events')
        .where('created_by', isEqualTo: user.uid)
        .orderBy('starts_at')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Events'),
        actions: [
          IconButton(
            tooltip: 'Create Event',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final newId = await Navigator.push<String?>(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateEventScreen(),
                ),
              );
              if (newId != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Event created')),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: eventsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('You have not created any events.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = (data['title'] ?? 'Untitled').toString();
              final desc = (data['description'] ?? '').toString();
              final location = (data['location'] ?? '').toString();
              final startsAt = data['starts_at'] as Timestamp?;
              final dateText = _formatDate(startsAt);
              final imageUrl = data['image_url'] as String? ?? '';

              // live RSVP count for this event
              final regsStream = FirebaseFirestore.instance
                  .collection('registrations')
                  .where('event_id', isEqualTo: doc.id)
                  .snapshots();

              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          StaffEventDetailScreen(eventId: doc.id),
                    ),
                  );
                },
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 1.5,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildThumbnail(imageUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                desc,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 14),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      dateText,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      location,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StreamBuilder<QuerySnapshot>(
                          stream: regsStream,
                          builder: (context, snap) {
                            final count = snap.data?.size ?? 0;
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'RSVPs',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '$count',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
