import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

class FeedbackSubmitScreen extends StatefulWidget {
  final String eventId;
  const FeedbackSubmitScreen({super.key, required this.eventId});

  @override
  _FeedbackSubmitScreenState createState() => _FeedbackSubmitScreenState();
}

class _FeedbackSubmitScreenState extends State<FeedbackSubmitScreen> {
  int _rating = 5;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in')));
      return;
    }

    final comment = _commentCtrl.text.trim();
    // optional: require comment or rating
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'event_id': widget.eventId,
        'user_id': user.uid,
        'rating': _rating,
        'comment': comment,
        'submitted_at': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for your feedback')));
      Navigator.pop(context, true); // return true to indicate success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit feedback: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Feedback'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Align(alignment: Alignment.centerLeft, child: Text('Rating', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starIndex = i + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = starIndex),
                  icon: Icon(
                    _rating >= starIndex ? Icons.star : Icons.star_border,
                    size: 32,
                  ),
                );
              }),
            ),

            const SizedBox(height: 12),
            TextField(
              controller: _commentCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Comments (optional)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Submit Feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
