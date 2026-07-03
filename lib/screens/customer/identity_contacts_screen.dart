import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/identity_provider.dart';
import '../../models/contact_model.dart';
import '../../utils/app_theme.dart';

class IdentityContactsScreen extends StatefulWidget {
  const IdentityContactsScreen({super.key});

  @override
  State<IdentityContactsScreen> createState() => _IdentityContactsScreenState();
}

class _IdentityContactsScreenState extends State<IdentityContactsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().currentUser?.id;
      if (userId != null) {
        context.read<IdentityProvider>().loadContacts(userId);
      }
    });
  }

  void _showAddContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    String relationship = 'primary';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Contact', style: TextStyle(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email (Optional)'),
                keyboardType: TextInputType.emailAddress,
              ),
              DropdownButtonFormField<String>(
                initialValue: relationship,
                items: [
                  'primary',
                  'family',
                  'friend',
                  'emergency',
                ].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                onChanged: (v) => relationship = v ?? 'primary',
                decoration: const InputDecoration(labelText: 'Relationship'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) return;

              final userId = context.read<AuthProvider>().currentUser?.id;
              if (userId == null) return;

              final contact = ContactModel(
                id: '', // Will be assigned by RDS Serial
                userId: userId,
                name: nameController.text,
                phoneNumber: phoneController.text,
                email: emailController.text.isEmpty ? null : emailController.text,
                relationship: relationship,
                createdAt: DateTime.now(),
              );

              final success = await context.read<IdentityProvider>().addContact(contact);
              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Contact added to secure vault')));
                }
              }
            },
            child: const Text('Save to AWS'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Identity & Contacts'),
            Text('Secured by AWS RDS', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: Consumer<IdentityProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          if (provider.contacts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.contact_phone_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No contacts found in your AWS vault.'),
                  ElevatedButton(
                    onPressed: _showAddContactDialog,
                    child: const Text('Add First Contact'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.contacts.length,
            itemBuilder: (context, index) {
              final contact = provider.contacts[index];
              return ListTile(
                leading: CircleAvatar(child: Text(contact.name[0])),
                title: Text(contact.name),
                subtitle: Text('${contact.phoneNumber} • ${contact.relationship}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                  onPressed: () => provider.deleteContact(
                    contact.id,
                    context.read<AuthProvider>().currentUser!.id,
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
