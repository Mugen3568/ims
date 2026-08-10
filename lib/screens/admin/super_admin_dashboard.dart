import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/institute_model.dart';
import '../../services/institute_service.dart';

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = InstituteService();
    return Scaffold(
      appBar: AppBar(title: const Text('Super Admin')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createInstitute(context, service),
        icon: const Icon(Icons.add_business),
        label: const Text('Create Institute'),
      ),
      body: StreamBuilder(
        stream: service.institutes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final institutes = snapshot.data!.docs
              .map((document) => Institute.fromDocument(document))
              .toList();
          if (institutes.isEmpty) return const Center(child: Text('No institutes created.'));
          return ListView.builder(
            itemCount: institutes.length,
            itemBuilder: (context, index) {
              final institute = institutes[index];
              return ListTile(
                leading: const Icon(Icons.account_balance),
                title: Text(institute.name),
                subtitle: Text('${institute.code} • ${institute.subscription}'),
                trailing: Text(institute.status),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createInstitute(
    BuildContext context,
    InstituteService service,
  ) async {
    final name = TextEditingController();
    final code = TextEditingController();
    String plan = 'Basic';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Institute'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Institute name')),
            TextField(controller: code, decoration: const InputDecoration(labelText: 'Institute code')),
            DropdownButtonFormField<String>(
              initialValue: plan,
              items: const ['Free', 'Basic', 'Standard', 'Premium', 'Enterprise']
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => setDialogState(() => plan = value!),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty || code.text.trim().isEmpty) return;
                try {
                  await service.createInstitute(
                    name: name.text,
                    code: code.text,
                    ownerId: FirebaseAuth.instance.currentUser!.uid,
                    subscription: plan,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('$error')));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
