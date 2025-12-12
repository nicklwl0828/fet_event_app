import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fet_event_app/util/download_csv.dart'; // relative path — adjust if different

class StaffEventDetailScreen extends StatelessWidget {
  final String eventId;
  const StaffEventDetailScreen({super.key, required this.eventId});

  // Helper to format timestamp safely
  String _formatTimestamp(Timestamp? t) {
    if (t == null) return '-';
    final dt = t.toDate();
    return DateFormat.yMMMd().add_jm().format(dt);
  }

  Future<void> _markAttendedSingle(BuildContext context, String regId) async {
    try {
      await FirebaseFirestore.instance
          .collection('registrations')
          .doc(regId)
          .update({'attended': true});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Marked as attended')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _markAllAttended(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      final regsSnap = await FirebaseFirestore.instance
          .collection('registrations')
          .where('event_id', isEqualTo: eventId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var d in regsSnap.docs) {
        batch.update(d.reference, {'attended': true});
      }
      await batch.commit();
      scaffold.showSnackBar(
        const SnackBar(content: Text('All attendees marked as attended')),
      );
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(content: Text('Failed to mark all: $e')),
      );
    }
  }

  // Export RSVPs as CSV — on web triggers a download, otherwise shows selectable dialog.
  Future<void> _exportCsv(BuildContext context) async {
    final navigator = Navigator.of(context);

    // show loading indicator while fetching
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // optional: fetch event title to use in filename
      String eventTitle = eventId;
      try {
        final eventDoc = await FirebaseFirestore.instance.collection('events').doc(eventId).get();
        if (eventDoc.exists) {
          final evData = eventDoc.data() as Map<String, dynamic>?;
          final t = (evData?['title'] ?? '').toString();
          if (t.isNotEmpty) eventTitle = t.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        }
      } catch (_) {
        // ignore — fallback to eventId
      }

      final regsSnap = await FirebaseFirestore.instance
          .collection('registrations')
          .where('event_id', isEqualTo: eventId)
          .orderBy('timestamp', descending: false)
          .get();

      // Build CSV with a UTF-8 BOM so Excel recognizes UTF-8 when opened
      final buffer = StringBuffer();
      buffer.write('\uFEFF'); // BOM
      buffer.writeln('Name,Email,User ID,Attended,Timestamp');

      String esc(String? value) {
        final v = (value ?? '').replaceAll('"', '""');
        return '"$v"';
      }

      for (var doc in regsSnap.docs) {
        final reg = doc.data() as Map<String, dynamic>;
        final userId = reg['user_id'] as String?;
        final attended = reg['attended'] == true;
        final ts = reg['timestamp'] as Timestamp?;
        final tsStr =
            ts != null ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate()) : '';

        String name = '';
        String email = '';

        if (userId != null) {
          final userSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          if (userSnap.exists) {
            final udata = userSnap.data() as Map<String, dynamic>?;
            name = (udata?['name'] ?? '').toString();
            email = (udata?['email'] ?? '').toString();
          }
        }

        buffer.writeln(
          '${esc(name)},${esc(email)},${esc(userId)},${attended ? "Yes" : "No"},${esc(tsStr)}',
        );
      }

      // close loading
      navigator.pop();

      final csvString = buffer.toString();
      final filename = '${eventTitle}_rsvps.csv';

      if (kIsWeb) {
        // web: trigger direct download (uses your conditional export helper)
        await downloadCsvFile(filename, csvString);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('CSV download started')));
      } else {
        // non-web: show CSV in dialog as selectable text (fallback)
        await showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('RSVP CSV'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: SelectableText(
                    csvString,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      // close loading if still open
      try {
        navigator.pop();
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export CSV: $e')),
      );
    }
  }

  Future<void> _showFeedbackDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Feedback'),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('feedback')
                  .where('event_id', isEqualTo: eventId)
                  .orderBy('submitted_at', descending: true)
                  .snapshots(),
              builder: (c, snap) {
                if (snap.hasError) {
                  return Text(
                    'Failed to load feedback:\n${snap.error}',
                    style: const TextStyle(color: Colors.red),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Text('No feedback yet.');
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, idx) {
                    final d = docs[idx].data() as Map<String, dynamic>;
                    final rating = d['rating']?.toString() ?? '-';
                    final comment = d['comment'] ?? '';
                    final submitted = d['submitted_at'] as Timestamp?;
                    final userId = d['user_id'] as String?;
                    return ListTile(
                      title: Text('Rating: $rating'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (userId != null)
                            Text(
                              'User: $userId',
                              style: const TextStyle(fontSize: 12),
                            ),
                          Text(comment),
                          Text(
                            _formatTimestamp(submitted),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventRef =
        FirebaseFirestore.instance.collection('events').doc(eventId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details (Staff)'),
        actions: [
          IconButton(
            tooltip: 'Export RSVPs as CSV',
            icon: const Icon(Icons.download),
            onPressed: () => _exportCsv(context),
          ),
          IconButton(
            tooltip: 'Mark all attended',
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Mark all as attended?'),
                  content: const Text(
                    'This will mark every RSVP for this event as attended.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await _markAllAttended(context);
              }
            },
          ),
          IconButton(
            tooltip: 'View feedback',
            icon: const Icon(Icons.feedback_outlined),
            onPressed: () => _showFeedbackDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: eventRef.snapshots(),
        builder: (context, eventSnap) {
          if (eventSnap.hasError) {
            return Center(child: Text('Error: ${eventSnap.error}'));
          }
          if (!eventSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = eventSnap.data!.data() as Map<String, dynamic>?;

          if (data == null) {
            return const Center(child: Text('Event not found'));
          }

          final startsAt = (data['starts_at'] as Timestamp?)?.toDate();
          final dateText = startsAt != null
              ? DateFormat.yMMMd().add_jm().format(startsAt)
              : '${data['date'] ?? ''} ${data['time'] ?? ''}';
          final title = (data['title'] ?? 'Untitled').toString();
          final desc = (data['description'] ?? '').toString();
          final location = (data['location'] ?? '').toString();
          final imageUrl = (data['image_url'] ?? '').toString();

          return Column(
            children: [
              // 🔹 Banner image
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.pink[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Icon(
                    Icons.event,
                    size: 56,
                    color: Colors.pink[200],
                  ),
                ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Event header card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(desc),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      dateText,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.location_on, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      location,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Registrations stream
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('registrations')
                              .where('event_id', isEqualTo: eventId)
                              .orderBy('timestamp', descending: false)
                              .snapshots(),
                          builder: (context, regsSnap) {
                            if (regsSnap.hasError) {
                              return Center(
                                child: Text('Error: ${regsSnap.error}'),
                              );
                            }
                            if (!regsSnap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final regs = regsSnap.data!.docs;
                            if (regs.isEmpty) {
                              return const Center(
                                child: Text('No RSVPs yet.'),
                              );
                            }

                            return ListView.separated(
                              itemCount: regs.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, i) {
                                final regDoc = regs[i];
                                final reg = regDoc.data() as Map<String, dynamic>;
                                final userId = reg['user_id'] as String?;
                                final attended = reg['attended'] == true;
                                final timestamp = reg['timestamp'] as Timestamp?;

                                return FutureBuilder<DocumentSnapshot>(
                                  future: userId == null
                                      ? Future.value(null)
                                      : FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(userId)
                                          .get(),
                                  builder: (c, userSnap) {
                                    String displayName = userId ?? 'Unknown';
                                    String email = '';
                                    if (userSnap.hasData &&
                                        userSnap.data != null &&
                                        userSnap.data!.exists) {
                                      final udata = userSnap.data!.data() as Map<String, dynamic>?;
                                      displayName = udata?['name'] ?? displayName;
                                      email = udata?['email'] ?? '';
                                    }

                                    return ListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      leading: CircleAvatar(
                                        child: Text(
                                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                        ),
                                      ),
                                      title: Text(
                                        displayName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (email.isNotEmpty)
                                            Text(
                                              email,
                                              style: const TextStyle(fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          Text(
                                            _formatTimestamp(timestamp),
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      trailing: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: attended
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade100,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: const Text(
                                                  'Attended',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              )
                                            : ElevatedButton(
                                                onPressed: () => _markAttendedSingle(context, regDoc.id),
                                                child: const Text(
                                                  'Mark attended',
                                                  style: TextStyle(fontSize: 12),
                                                ),
                                              ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
