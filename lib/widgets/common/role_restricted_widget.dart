import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';

class RoleRestrictedWidget extends StatelessWidget {
  final List<UserRole> allowedRoles;
  final Widget child;
  final Widget fallback;

  const RoleRestrictedWidget({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    if (user != null && allowedRoles.contains(user.role)) {
      return child;
    }
    return fallback;
  }
}
