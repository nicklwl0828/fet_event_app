// lib/screens/create_event_screen.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class CreateEventScreen extends StatefulWidget {
  final String? eventId; // null = create, not null = edit

  const CreateEventScreen({super.key, this.eventId});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  DateTime? _startsAt;
  bool _isLoading = false;

  // image stuff (web + mobile friendly)
  final ImagePicker _picker = ImagePicker();
  Uint8List? _pickedImageBytes;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.eventId != null) {
      _loadExistingEvent();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingEvent() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();

      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        _titleCtrl.text = (data['title'] ?? '') as String;
        _descCtrl.text = (data['description'] ?? '') as String;
        _locationCtrl.text = (data['location'] ?? '') as String;
        _existingImageUrl = (data['image_url'] ?? '') as String;

        final ts = data['starts_at'];
        if (ts is Timestamp) {
          _startsAt = ts.toDate();
        } else if (ts is DateTime) {
          _startsAt = ts;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load event: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
      });
    }
  }

  /// Uploads the picked image (if any) and returns a download URL.
  /// If no new image picked, returns existing URL (for edit mode).
  Future<String?> _uploadImage(String eventId) async {
    if (_pickedImageBytes == null) {
      // no new image picked → keep old one if any
      return _existingImageUrl;
    }

    final ref = FirebaseStorage.instance.ref().child('event_photos').child('$eventId.jpg');

    debugPrint('📤 Uploading image to: ${ref.fullPath}');

    try {
      // Prepare metadata including custom metadata fields
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'eventId': eventId,
          'createdBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        },
      );

      // 1) Upload bytes with metadata
      final taskSnapshot = await ref.putData(_pickedImageBytes!, metadata);

      debugPrint('✅ Upload complete. State: ${taskSnapshot.state}');

      // 2) Get download URL
      final url = await taskSnapshot.ref.getDownloadURL();
      debugPrint('🔗 Download URL: $url');
      return url;
    } on FirebaseException catch (e) {
      debugPrint('❌ Upload failed for ${ref.fullPath}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: ${e.message}')),
        );
      }
      return _existingImageUrl;
    } catch (e) {
      debugPrint('❌ Unexpected upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e')),
        );
      }
      return _existingImageUrl;
    }
  }

  Future<void> _pickDateTime() async {
    final initDate = _startsAt ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initDate),
    );
    if (time == null) return;

    setState(() {
      _startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _saveEvent() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _descCtrl.text.trim().isEmpty ||
        _locationCtrl.text.trim().isEmpty ||
        _startsAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not logged in.')),
          );
        }
        return;
      }

      final eventsRef = FirebaseFirestore.instance.collection('events');
      final String eventId = widget.eventId ?? eventsRef.doc().id;
      final docRef = eventsRef.doc(eventId);

      // If editing and a new image is selected, try to remove old image from storage
      final willReplaceImage = _pickedImageBytes != null && _existingImageUrl != null && _existingImageUrl!.isNotEmpty;
      if (willReplaceImage) {
        try {
          final oldRef = FirebaseStorage.instance.refFromURL(_existingImageUrl!);
          await oldRef.delete();
          debugPrint('Old image deleted: ${oldRef.fullPath}');
        } catch (e) {
          debugPrint('Failed to delete old image (non-fatal): $e');
          // continue — not fatal
        }
      }

      // 1️⃣ Upload image first (if any)
      final imageUrl = await _uploadImage(eventId);

      // 2️⃣ Build event data (use Timestamp for Firestore)
      final data = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'starts_at': Timestamp.fromDate(_startsAt!),
        'image_url': imageUrl ?? '',
        'created_by': user.uid,
        'updated_at': FieldValue.serverTimestamp(),
      };

      // 3️⃣ Save / update
      if (widget.eventId == null) {
        // new doc - add created_at as well
        data['created_at'] = FieldValue.serverTimestamp();
        await docRef.set(data);
      } else {
        await docRef.update(data);
      }

      if (!mounted) return;

      Navigator.pop(context, eventId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.eventId == null ? 'Event created successfully' : 'Event updated successfully')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save event: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.eventId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Event' : 'Create Event'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // image preview
                  if (_pickedImageBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _pickedImageBytes!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _existingImageUrl!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.image, size: 80),
                    ),
                  const SizedBox(height: 8),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo),
                      label: const Text('Pick Event Image'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Event Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(_startsAt == null
                            ? 'No date selected'
                            : DateFormat.yMMMd().add_jm().format(_startsAt!)),
                      ),
                      ElevatedButton(
                        onPressed: _pickDateTime,
                        child: const Text('Pick date & time'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveEvent,
                      child: Text(isEdit ? 'Update Event' : 'Create Event'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
