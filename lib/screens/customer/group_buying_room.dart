import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/group_order_model.dart';
import '../../utils/app_theme.dart';

class GroupBuyingRoom extends StatelessWidget {
  final String groupId;

  const GroupBuyingRoom({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neighbor Group Room', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.share(
              'Join my Fufaji group order: fufaji://group/$groupId',
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          final group = GroupOrderModel.fromMap(
            snapshot.data!.data() as Map<String, dynamic>,
          );

          return Column(
            children: [
              LinearProgressIndicator(
                value: group.totalAmount / group.goalAmount,
              ),
              Text('Goal: ₹${group.totalAmount} / ₹${group.goalAmount}'),
              Expanded(
                child: ListView.builder(
                  itemCount: group.memberIds.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text('Member: ${group.memberIds[index]}'),
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
