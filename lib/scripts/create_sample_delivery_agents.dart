import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/delivery_agent_model.dart';

/// Script to create sample delivery agents in Firestore
/// Run this once to populate the delivery_agents collection with test data

Future<void> createSampleDeliveryAgents() async {
  final db = FirebaseFirestore.instance;

  final sampleAgents = [
    DeliveryAgent(
      id: 'agent_1',
      name: 'Raj Kumar',
      phone: '+919876543210',
      currentLat: 28.6139,
      currentLng: 77.2090,
      isAvailable: true,
      currentStatus: 'active',
      rating: 4.8,
      totalDeliveries: 245,
      currentOrderCount: 0,
      createdAt: DateTime.now(),
    ),
    DeliveryAgent(
      id: 'agent_2',
      name: 'Priya Singh',
      phone: '+919876543211',
      currentLat: 28.5244,
      currentLng: 77.1855,
      isAvailable: true,
      currentStatus: 'active',
      rating: 4.9,
      totalDeliveries: 312,
      currentOrderCount: 1,
      createdAt: DateTime.now(),
    ),
    DeliveryAgent(
      id: 'agent_3',
      name: 'Vikram Patel',
      phone: '+919876543212',
      currentLat: 28.6358,
      currentLng: 77.2273,
      isAvailable: true,
      currentStatus: 'active',
      rating: 4.7,
      totalDeliveries: 198,
      currentOrderCount: 0,
      createdAt: DateTime.now(),
    ),
    DeliveryAgent(
      id: 'agent_4',
      name: 'Anjali Sharma',
      phone: '+919876543213',
      currentLat: 28.5355,
      currentLng: 77.3910,
      isAvailable: true,
      currentStatus: 'active',
      rating: 4.6,
      totalDeliveries: 167,
      currentOrderCount: 2,
      createdAt: DateTime.now(),
    ),
    DeliveryAgent(
      id: 'agent_5',
      name: 'Rohan Desai',
      phone: '+919876543214',
      currentLat: 28.4595,
      currentLng: 77.0266,
      isAvailable: true,
      currentStatus: 'active',
      rating: 4.5,
      totalDeliveries: 134,
      currentOrderCount: 0,
      createdAt: DateTime.now(),
    ),
  ];

  try {
    for (var agent in sampleAgents) {
      await db
          .collection('delivery_agents')
          .doc(agent.id)
          .set(agent.toMap());
      print('Created agent: ${agent.name} (${agent.id})');
    }
    print('Successfully created ${sampleAgents.length} sample delivery agents');
  } catch (e) {
    print('Error creating sample agents: $e');
    rethrow;
  }
}

/// Remove all sample delivery agents (for cleanup)
Future<void> deleteSampleDeliveryAgents() async {
  final db = FirebaseFirestore.instance;
  final agentIds = ['agent_1', 'agent_2', 'agent_3', 'agent_4', 'agent_5'];

  try {
    for (var agentId in agentIds) {
      await db.collection('delivery_agents').doc(agentId).delete();
      print('Deleted agent: $agentId');
    }
    print('Successfully deleted sample agents');
  } catch (e) {
    print('Error deleting sample agents: $e');
    rethrow;
  }
}

/// Update sample agent locations
Future<void> updateAgentLocations() async {
  final db = FirebaseFirestore.instance;

  final updatedLocations = {
    'agent_1': {'lat': 28.6200, 'lng': 77.2150},
    'agent_2': {'lat': 28.5300, 'lng': 77.1900},
    'agent_3': {'lat': 28.6400, 'lng': 77.2300},
    'agent_4': {'lat': 28.5400, 'lng': 77.3950},
    'agent_5': {'lat': 28.4650, 'lng': 77.0300},
  };

  try {
    for (var entry in updatedLocations.entries) {
      await db
          .collection('delivery_agents')
          .doc(entry.key)
          .update({
            'currentLat': entry.value['lat'],
            'currentLng': entry.value['lng'],
            'lastLocationUpdate': FieldValue.serverTimestamp(),
          });
      print('Updated location for ${entry.key}');
    }
    print('Successfully updated agent locations');
  } catch (e) {
    print('Error updating locations: $e');
    rethrow;
  }
}

/// Get all delivery agents
Future<List<DeliveryAgent>> getAllDeliveryAgents() async {
  final db = FirebaseFirestore.instance;

  try {
    final snapshot =
        await db.collection('delivery_agents').get();

    final agents = snapshot.docs
        .map((doc) => DeliveryAgent.fromMap(doc.data()))
        .toList();

    print('Retrieved ${agents.length} delivery agents');
    return agents;
  } catch (e) {
    print('Error fetching agents: $e');
    rethrow;
  }
}

/// Get available agents count
Future<int> getAvailableAgentsCount() async {
  final db = FirebaseFirestore.instance;

  try {
    final snapshot = await db
        .collection('delivery_agents')
        .where('isAvailable', isEqualTo: true)
        .where('currentStatus', isEqualTo: 'active')
        .get();

    print('Available agents: ${snapshot.docs.length}');
    return snapshot.docs.length;
  } catch (e) {
    print('Error counting available agents: $e');
    rethrow;
  }
}

void main() async {
  // Example usage:
  // await createSampleDeliveryAgents();
  // await updateAgentLocations();
  // final agents = await getAllDeliveryAgents();
  // await deleteSampleDeliveryAgents();

  print('Delivery agent management script loaded');
}
