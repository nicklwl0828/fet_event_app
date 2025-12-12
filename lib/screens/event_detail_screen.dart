import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId; // Firestore document ID

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool isLoading = false;
  Map<String, dynamic>? eventData;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();

      if (!mounted) return;
      setState(() {
        eventData = doc.data() as Map<String, dynamic>?;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load event: $e')),
      );
    }
  }

  Future<void> _rsvp() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to RSVP.')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('registrations').add({
        'event_id': widget.eventId,
        'user_id': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'attended': false,
      });
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RSVP successful!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to RSVP: $e')),
      );
    }
  }

  String _formatWhen(Map<String, dynamic> data) {
    final ts = data['starts_at'] as Timestamp?;
    if (ts != null) {
      final dt = ts.toDate();
      return DateFormat.yMMMd().add_jm().format(dt);
    }
    final d = (data['date'] ?? '').toString();
    final t = (data['time'] ?? '').toString();
    if (d.isEmpty && t.isEmpty) return '-';
    return '$d  $t';
  }

  Widget _buildHeaderImage(String? imageUrl) {
    const border = BorderRadius.only(
      bottomLeft: Radius.circular(24),
      bottomRight: Radius.circular(24),
    );

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: border,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, size: 40),
      );
    }

    return ClipRRect(
      borderRadius: border,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stack) {
                return Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, size: 40),
                );
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------
  // Feedback UI + submit helper
  // -------------------------------
  Future<void> _showFeedbackSheet(BuildContext ctx, String eventId) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Please sign in to leave feedback')),
      );
      return;
    }

    final TextEditingController commentCtrl = TextEditingController();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (sheetCtx) {
        int rating = 5;
        return StatefulBuilder(builder: (sCtx, setStateSB) {
          Future<void> submit() async {
            final comment = commentCtrl.text.trim();
            try {
              await FirebaseFirestore.instance.collection('feedback').add({
                'event_id': eventId,
                'user_id': current.uid,
                'rating': rating,
                'comment': comment,
                'submitted_at': FieldValue.serverTimestamp(),
              });
              Navigator.of(sheetCtx).pop(); // close sheet
              if (!mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Thank you for the feedback')),
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('Failed to submit feedback: $e')),
              );
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(sheetCtx).size.height * 0.75,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Leave feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                        TextButton(onPressed: () => Navigator.pop(sheetCtx), child: const Text('Close')),
                      ],
                    ),
                  ),
                  // Rating stars
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: List.generate(5, (i) {
                        final idx = i + 1;
                        return IconButton(
                          onPressed: () => setStateSB(() => rating = idx),
                          icon: Icon(
                            idx <= rating ? Icons.star : Icons.star_border,
                            size: 28,
                            color: idx <= rating ? Colors.amber : Colors.grey,
                          ),
                        );
                      }),
                    ),
                  ),

                  // Comment
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: commentCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Comment (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: submit,
                        child: const Text('Submit feedback'),
                      ),
                    ),
                  ),

                  const Divider(),
                  // Existing feedback list (live)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('feedback')
                            .where('event_id', isEqualTo: eventId)
                            .orderBy('submitted_at', descending: true)
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                          final docs = snap.data!.docs;
                          if (docs.isEmpty) return const Center(child: Text('No feedback yet'));
                          return ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (c, i) {
                              final d = docs[i].data() as Map<String, dynamic>;
                              final r = d['rating'] ?? 0;
                              final comment = d['comment'] ?? '';
                              final ts = d['submitted_at'] as Timestamp?;
                              final tsText = ts != null ? DateFormat.yMMMd().add_jm().format(ts.toDate()) : '';
                              final userId = d['user_id'] ?? '';
                              return ListTile(
                                leading: CircleAvatar(child: Text((r as int).toString())),
                                title: Row(children: [
                                  for (int s = 0; s < 5; s++)
                                    Icon(s < r ? Icons.star : Icons.star_border, size: 14, color: Colors.amber),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(userId, style: const TextStyle(fontSize: 12, color: Colors.black54))),
                                ]),
                                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  if ((comment as String).isNotEmpty) Text(comment),
                                  if (tsText.isNotEmpty) Text(tsText, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ]),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // -------------------------------
  // End feedback helpers
  // -------------------------------

  @override
  Widget build(BuildContext context) {
    if (eventData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = eventData!;
    final title = (data['title'] ?? 'Event').toString();
    final desc = (data['description'] ?? '').toString();
    final location = (data['location'] ?? '').toString();
    final whenText = _formatWhen(data);
    final imageUrl = (data['image_url'] ?? '').toString();

    final currentUser = FirebaseAuth.instance.currentUser;

    // If user is logged in, create a query stream for their registration for this event.
    Stream<QuerySnapshot<Map<String, dynamic>>>? regStream;
    if (currentUser != null) {
      regStream = FirebaseFirestore.instance
          .collection('registrations')
          .where('event_id', isEqualTo: widget.eventId)
          .where('user_id', isEqualTo: currentUser.uid)
          .limit(1)
          .snapshots()
          .cast<QuerySnapshot<Map<String, dynamic>>>();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Feedback',
            icon: const Icon(Icons.feedback_outlined),
            onPressed: () => _showFeedbackSheet(context, widget.eventId),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderImage(imageUrl),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          whenText,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'About this event',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // Feedback quick button under content (redundant with AppBar; convenient for users)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showFeedbackSheet(context, widget.eventId),
                      icon: const Icon(Icons.feedback_outlined),
                      label: const Text('Feedback & rating'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ========== RSVP area (realtime) with AnimatedSwitcher ==========
                  if (currentUser == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please log in to RSVP')),
                          );
                        },
                        child: const Text('Log in to RSVP'),
                      ),
                    )
                  else
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: regStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: null,
                              child: const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: null,
                                  child: const Text('RSVP'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Failed to load RSVP state',
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                            ],
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];
                        final isRegistered = docs.isNotEmpty;
                        final regId = isRegistered ? docs.first.id : null;
                        final regData = isRegistered ? docs.first.data() : null;
                        final isAttended = regData?['attended'] == true;

                        // AnimatedSwitcher wraps the CONTENT so switches animate smoothly.
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            // combine fade + scale for a snappy micro-animation
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation), child: child),
                            );
                          },
                          child: (!isRegistered)
                              ? SizedBox(
                                  key: const ValueKey('rsvp_button'),
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _rsvp,
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Text('RSVP'),
                                  ),
                                )
                              : Container(
                                  key: const ValueKey('registered_block'),
                                  width: double.infinity,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // STATUS (disabled) - appears first
                                      ElevatedButton(
                                        onPressed: null,
                                        child: Text(isAttended ? 'You have attended this event' : 'Already registered'),
                                      ),

                                      const SizedBox(height: 12),

                                      // CANCEL RSVP with confirmation + local loading
                                      Builder(builder: (ctx) {
                                        bool deleting = false;
                                        return StatefulBuilder(
                                          builder: (contextSB, setStateSB) {
                                            return OutlinedButton(
                                              onPressed: (isAttended || deleting)
                                                  ? null
                                                  : () async {
                                                      final confirmed = await showDialog<bool>(
                                                        context: ctx,
                                                        builder: (dCtx) => AlertDialog(
                                                          title: const Text('Cancel RSVP'),
                                                          content: const Text(
                                                              'Are you sure you want to cancel your RSVP? This will remove your registration.'),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () => Navigator.pop(dCtx, false),
                                                              child: const Text('No'),
                                                            ),
                                                            TextButton(
                                                              onPressed: () => Navigator.pop(dCtx, true),
                                                              child: const Text('Yes, cancel'),
                                                            ),
                                                          ],
                                                        ),
                                                      );

                                                      if (confirmed != true) return;

                                                      setStateSB(() => deleting = true);

                                                      try {
                                                        await FirebaseFirestore.instance
                                                            .collection('registrations')
                                                            .doc(regId)
                                                            .delete();

                                                        if (!mounted) return;
                                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                                          const SnackBar(content: Text('RSVP cancelled')),
                                                        );
                                                      } catch (e) {
                                                        if (!mounted) return;
                                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                                          SnackBar(content: Text('Failed to cancel: $e')),
                                                        );
                                                      } finally {
                                                        if (mounted) setStateSB(() => deleting = false);
                                                      }
                                                    },
                                              child: deleting
                                                  ? const SizedBox(
                                                      height: 16,
                                                      width: 16,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    )
                                                  : const Text('Cancel RSVP'),
                                            );
                                          },
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
