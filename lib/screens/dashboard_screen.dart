import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/report_provider.dart';
import '../providers/ai_provider.dart';
import '../providers/auth_provider.dart';
import 'pos/pos_screen.dart';
import 'ai_assistant_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().loadDashboardStats();
      context.read<AiProvider>().generateInsights();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZAD Mobile POS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<ReportProvider>().loadDashboardStats();
          await context.read<AiProvider>().generateInsights();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Action Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PosScreen()),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart, size: 28),
                  label: const Text(
                    'بيع جديد',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Stats Cards
              Consumer<ReportProvider>(
                builder: (context, provider, child) {
                  final stats = provider.dashboardStats;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      _StatCard(
                        title: 'مبيعات اليوم',
                        value: '${(stats['salesTotal'] ?? 0.0).toStringAsFixed(0)} د.ج',
                        icon: Icons.attach_money,
                        color: const Color(0xFF43A047),
                        subtitle: '${stats['salesCount'] ?? 0} فاتورة',
                      ),
                      _StatCard(
                        title: 'الأرباح',
                        value: '${(stats['profit'] ?? 0.0).toStringAsFixed(0)} د.ج',
                        icon: Icons.trending_up,
                        color: const Color(0xFF1E88E5),
                        subtitle: 'هامش تقديري',
                      ),
                      _StatCard(
                        title: 'المنتجات',
                        value: '${stats['productCount'] ?? 0}',
                        icon: Icons.inventory_2,
                        color: const Color(0xFF7E57C2),
                        subtitle: 'صنف نشط',
                      ),
                      _StatCard(
                        title: 'نقص المخزون',
                        value: '${stats['lowStockCount'] ?? 0}',
                        icon: Icons.warning_amber,
                        color: const Color(0xFFE53935),
                        subtitle: 'يحتاج طلب',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // AI Insights
              const Text(
                'تنبيهات ذكية',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Consumer<AiProvider>(
                builder: (context, aiProvider, child) {
                  if (aiProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Column(
                    children: aiProvider.insights.map((insight) {
                      Color color = Colors.blue;
                      IconData icon = Icons.info;
                      if (insight['type'] == 'warning') {
                        color = Colors.orange;
                        icon = Icons.warning_amber;
                      } else if (insight['type'] == 'success') {
                        color = Colors.green;
                        icon = Icons.check_circle;
                      }
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.1),
                            child: Icon(icon, color: color),
                          ),
                          title: Text(insight['title'] ?? ''),
                          subtitle: Text(insight['message'] ?? ''),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 20),

              // AI Assistant Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                    );
                  },
                  icon: const Icon(Icons.smart_toy),
                  label: const Text('المساعد الذكي'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
