import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['contact_number'] ?? data['phone'] ?? '';
        _addressController.text = data['address'] ?? '';
        _role = data['role'] ?? '';
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (user == null) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'name': _nameController.text.trim(),
        'contact_number': _phoneController.text.trim(),
        'phone': _phoneController.text.trim(), // Support both fields
        'address': _addressController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile & Personal Info')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                user?.email?.isNotEmpty == true
                    ? user!.email![0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  fontSize: 32,
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Email Display
            Text(
              user?.email ?? 'No Email',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            // Role Badge
            if (_role.isNotEmpty) ...[
              const SizedBox(height: 8),
              Chip(
                label: Text(_role.toUpperCase()),
                backgroundColor: theme.colorScheme.primaryContainer,
              ),
            ],

            const SizedBox(height: 32),

            // Full Name Field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),

            // Phone Number Field
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number / Contact',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),

            // Address Field
            TextField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Address (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
