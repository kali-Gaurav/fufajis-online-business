import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class GaonIntelligentInsights extends StatelessWidget {
  const GaonIntelligentInsights({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.psychology, color: Colors.indigo[700]),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Village Intelligent Insights',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text(
                      'AI UPDATED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInsightSection(
            context,
            'Trending Demands',
            'AI analysis of local buying patterns',
            [
              _VillageInsight(name: 'Cold Drinks', growth: '+45%', items: 'Surge after 4 PM', color: Colors.blue),
              _VillageInsight(name: 'Milk/Dairy', growth: '+15%', items: 'Morning 7-9 AM', color: Colors.orange),
              _VillageInsight(name: 'Snacks', growth: '+30%', items: 'Combo with Soda', color: Colors.purple),
            ],
          ),
          const Divider(height: 32),
          _buildTrustLeaderboard(),
          const SizedBox(height: 24),
          _buildAutomatedActionCard(context),
        ],
      ),
    );
  }

  Widget _buildInsightSection(BuildContext context, String title, String subtitle, List<_VillageInsight> insights) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 16),
        Row(
          children: insights.map((insight) => Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[100]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(insight.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(insight.growth, style: TextStyle(color: insight.color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'High Demand:',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                  Text(
                    insight.items,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildTrustLeaderboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Community Trust Leaderboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildTrustProfile('Ramesh C.', 'Bassi', '5.0 ⭐'),
            const SizedBox(width: 16),
            _buildTrustProfile('Kamla D.', 'Chomu', '4.9 ⭐'),
            const SizedBox(width: 16),
            _buildTrustProfile('Vikram Y.', 'Shahpura', '4.9 ⭐'),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustProfile(String name, String village, String rating) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.amber[50]?.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 12, backgroundColor: Colors.amber[100], child: Text(name[0], style: const TextStyle(fontSize: 10))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(village, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                ],
              ),
            ),
            Text(rating, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomatedActionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[900]!, Colors.indigo[600]!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Colors.amber),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automated Logic for Fufaji',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Based on trends, I suggest ordering +50kg Tomatoes for Bassi tomorrow.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Automated order for 50kg Tomatoes placed with Mandi Supplier for Bassi route.'),
                  backgroundColor: Colors.indigo,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.indigo[900],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _VillageInsight {
  final String name;
  final String growth;
  final String items;
  final Color color;

  _VillageInsight({required this.name, required this.growth, required this.items, required this.color});
}
