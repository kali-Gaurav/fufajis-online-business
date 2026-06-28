import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_theme.dart';
import '../../services/audit_service.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _branchIdController = TextEditingController();
  String _selectedRole = 'packer';

  final List<String> _roles = [
    'packer',
    'delivery',
    'inventory',
    'branch_manager',
    'support'
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _branchIdController.dispose();
    super.dispose();
  }

  void _addEmployee() async {
    final email = _emailController.text.trim().toLowerCase();
    final name = _nameController.text.trim();
    final branchId = _branchIdController.text.trim().toUpperCase();
    
    if (email.isEmpty || name.isEmpty || branchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required.')),
      );
      return;
    }

    if (!email.endsWith('@gmail.com')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee must use a Gmail address.')),
      );
      return;
    }

    final docId = email.replaceAll('@', '_').replaceAll('.', '_');
    final currentUser = FirebaseAuth.instance.currentUser;

    // Create record in Firestore employees collection
    await FirebaseFirestore.instance.collection('employees').doc(docId).set({
      'employeeId': docId,
      'uid': '', // Filled on first login
      'name': name,
      'email': email,
      'role': _selectedRole,
      'branchId': branchId,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Also add to pre_authorized_users for overall app rules compatibility
    await FirebaseFirestore.instance.collection('pre_authorized_users').doc(docId).set({
      'email': email,
      'name': name,
      'role': 'UserRole.employee',
      'branchId': branchId,
      'addedAt': FieldValue.serverTimestamp(),
    });

    // Audit log
    await AuditService().logAction(
      userId: currentUser?.uid ?? 'system',
      userName: currentUser?.displayName ?? currentUser?.email ?? 'Owner',
      action: AuditAction.adminAction,
      description: 'Authorized new employee "$name" ($email) as "$_selectedRole" for Branch $branchId',
      metadata: {
        'employeeEmail': email,
        'employeeName': name,
        'role': _selectedRole,
        'branchId': branchId,
      },
    );

    _emailController.clear();
    _nameController.clear();
    _branchIdController.clear();
    setState(() {
      _selectedRole = 'packer';
    });
    
    if (mounted) Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Employee "$name" authorized successfully.')),
    );
  }

  void _deleteEmployee(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final String name = data['name'] as String? ?? 'Unknown';
    final String email = data['email'] as String? ?? '';
    final currentUser = FirebaseAuth.instance.currentUser;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Employee Authorization', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to revoke access for "$name"? They will be signed out immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await doc.reference.delete();
      
      // Also delete from pre_authorized_users
      final preAuthDocId = email.replaceAll('@', '_').replaceAll('.', '_');
      await FirebaseFirestore.instance.collection('pre_authorized_users').doc(preAuthDocId).delete().catchError((_){});

      // Audit log
      await AuditService().logAction(
        userId: currentUser?.uid ?? 'system',
        userName: currentUser?.displayName ?? currentUser?.email ?? 'Owner',
        action: AuditAction.adminAction,
        description: 'Revoked employee authorization for "$name" ($email)',
        metadata: {
          'employeeEmail': email,
          'employeeName': name,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Employee "$name" authorization revoked.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Employees', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey800,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppTheme.grey200, height: 1.0),
        ),
      ),
      backgroundColor: AppTheme.grey50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('employees').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.badge_outlined, size: 64, color: AppTheme.grey400),
                  SizedBox(height: 16),
                  Text(
                    'No employees authorized yet.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.grey600),
                  ),
                ],
              ),
            );
          }
          
          final employees = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: employees.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = employees[index];
              final data = doc.data() as Map<String, dynamic>;
              final String name = data['name'] as String? ?? 'Unknown';
              final String email = data['email'] as String? ?? '';
              final String role = data['role'] as String? ?? '';
              final String branchId = data['branchId'] as String? ?? '';
              final bool isBound = (data['uid'] as String? ?? '').isNotEmpty;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.grey200),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(email, style: const TextStyle(color: AppTheme.grey600, fontSize: 13)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.info.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    role.toUpperCase(),
                                    style: const TextStyle(fontSize: 10, color: AppTheme.ownerAccent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'BRANCH: $branchId',
                                    style: TextStyle(fontSize: 10, color: Colors.purple.shade700, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (isBound) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.success.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'BOUND',
                                      style: TextStyle(fontSize: 10, color: AppTheme.success, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                        onPressed: () => _deleteEmployee(doc),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Employee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Authorize New Employee', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController, 
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  )
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController, 
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Gmail Address',
                    prefixIcon: Icon(Icons.email_outlined),
                    hintText: 'user@gmail.com',
                  )
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _branchIdController, 
                  decoration: const InputDecoration(
                    labelText: 'Branch ID',
                    prefixIcon: Icon(Icons.store_outlined),
                    hintText: 'KOTA01',
                  )
                ),
                const SizedBox(height: 16),
                const Text('Assign Role:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.grey700)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _roles.map((r) => 
                    DropdownMenuItem(value: r, child: Text(r.toUpperCase()))
                  ).toList(),
                  onChanged: (v) {
                    setState(() => _selectedRole = v!);
                    setDialogState(() {});
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _nameController.clear();
                _emailController.clear();
                _branchIdController.clear();
                Navigator.pop(context);
              }, 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: _addEmployee, 
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Authorize')
            ),
          ],
        ),
      ),
    );
  }
}
