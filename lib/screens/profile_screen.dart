import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '-';
    final dt = ts.toDate();
    return DateFormat.yMMMd().add_jm().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Not logged in'),
        ),
      );
    }

    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    final regsQuery = FirebaseFirestore.instance
        .collection('registrations')
        .where('user_id', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: userDocRef.get(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (userSnap.hasError) {
              return Center(
                child: Text(
                  'Failed to load profile: ${userSnap.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final userData = userSnap.data?.data() ?? {};
            final name = (userData['name'] ?? user.email ?? '') as String;
            final email = (userData['email'] ?? user.email ?? '') as String;
            final role = (userData['role'] ?? 'Student') as String;

            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Profile card ---
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            child: Text(
                              name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Chip(
                                  label: Text(
                                    role,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors
                                      .deepPurpleAccent
                                      .withOpacity(0.1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- RSVP stats & list ---
                  StreamBuilder<QuerySnapshot>(
                    stream: regsQuery.snapshots(),
                    builder: (context, regsSnap) {
                      if (regsSnap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Failed to load RSVPs: ${regsSnap.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      if (!regsSnap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final regs = regsSnap.data!.docs;
                      final totalRsvps = regs.length;
                      final attendedCount = regs
                          .where((d) =>
                              (d.data() as Map<String, dynamic>)['attended'] ==
                              true)
                          .length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats row
                          Row(
                            children: [
                              Expanded(
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Total RSVPs',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$totalRsvps',
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Attended',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$attendedCount',
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Text(
                            'My RSVPs',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (regs.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                'You have not registered for any events yet.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: regs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final reg =
                                    regs[i].data() as Map<String, dynamic>;
                                final eventId =
                                    reg['event_id'] as String? ?? '';
                                final attended =
                                    (reg['attended'] ?? false) as bool;
                                final ts = reg['timestamp'] as Timestamp?;

                                // Fetch event details (title / starts_at)
                                return FutureBuilder<
                                    DocumentSnapshot<Map<String, dynamic>>>(
                                  future: FirebaseFirestore.instance
                                      .collection('events')
                                      .doc(eventId)
                                      .get(),
                                  builder: (context, eventSnap) {
                                    String eventTitle = 'Event';
                                    String dateText = _formatTimestamp(ts);

                                    if (eventSnap.hasData &&
                                        eventSnap.data!.data() != null) {
                                      final ev =
                                          eventSnap.data!.data()!;
                                      eventTitle =
                                          ev['title'] ?? eventTitle;

                                      final startsAt =
                                          ev['starts_at'] as Timestamp?;
                                      if (startsAt != null) {
                                        dateText =
                                            _formatTimestamp(startsAt);
                                      }
                                    }

                                    return Card(
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.event_outlined,
                                        ),
                                        title: Text(
                                          eventTitle,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          dateText,
                                          style: const TextStyle(
                                              fontSize: 12),
                                        ),
                                        trailing: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: attended
                                                ? Colors.green.shade100
                                                : Colors
                                                    .orange.shade100,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            attended
                                                ? 'Attended'
                                                : 'Registered',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: attended
                                                  ? Colors.green.shade800
                                                  : Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
