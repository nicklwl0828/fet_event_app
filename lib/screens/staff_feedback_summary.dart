import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StaffFeedbackSummary extends StatelessWidget {
  final String eventId;
  const StaffFeedbackSummary({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    final feedbackQuery = FirebaseFirestore.instance
        .collection('feedback')
        .where('event_id', isEqualTo: eventId)
        .orderBy('submitted_at', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: StreamBuilder<QuerySnapshot>(
        stream: feedbackQuery,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No feedback yet'));

          // compute average
          double avg = 0;
          int count = docs.length;
          for (var d in docs) {
            final m = d.data() as Map<String, dynamic>;
            final r = (m['rating'] is int) ? m['rating'] as int : (m['rating'] is double ? (m['rating'] as double).round() : 0);
            avg += r;
          }
          avg = (count > 0) ? (avg / count) : 0;

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Card(
                  child: ListTile(
                    title: Text('Average rating: ${avg.toStringAsFixed(2)} ⭐'),
                    subtitle: Text('$count feedback entries'),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (c, i) {
                      final m = docs[i].data() as Map<String, dynamic>;
                      final rating = m['rating'] ?? 0;
                      final comment = m['comment'] ?? '';
                      final submitted = m['submitted_at'] as Timestamp?;
                      final byUser = m['user_id'] ?? 'unknown';
                      return ListTile(
                        leading: CircleAvatar(child: Text('$rating')),
                        title: Text(comment.isNotEmpty ? comment : '(no comment)'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('By: $byUser', style: const TextStyle(fontSize: 12)),
                            Text(submitted == null ? '' : DateFormat.yMMMd().add_jm().format(submitted.toDate()), style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
