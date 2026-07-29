import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/report_provider.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().loadTodayStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: 'من',
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateButton(
                        label: 'إلى',
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Today Stats
            Consumer<ReportProvider>(
              builder: (context, provider, child) {
                final stats = provider.todayStats;
                return Column(
                  children: [
                    _ReportCard(
                      title: 'مبيعات اليوم',
                      value: '${(stats['salesTotal'] ?? 0.0).toStringAsFixed(2)} د.ج',
                      icon: Icons.attach_money,
                      color: const Color(0xFF43A047),
                    ),
                    const SizedBox(height: 12),
                    _ReportCard(
                      title: 'عدد الفواتير',
                      value: '${stats['salesCount'] ?? 0}',
                      icon: Icons.receipt,
                      color: const Color(0xFF1E88E5),
                    ),
                    const SizedBox(height: 12),
                    _ReportCard(
                      title: 'الأرباح التقديرية',
                      value: '${(stats['profit'] ?? 0.0).toStringAsFixed(2)} د.ج',
                      icon: Icons.trending_up,
                      color: const Color(0xFF7E57C2),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Sales Chart
            const Text('مبيعات الأسبوع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              const days = ['سبت', 'أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة'];
                              if (value.toInt() >= 0 && value.toInt() < days.length) {
                                return Text(days[value.toInt()], style: const TextStyle(fontSize: 10));
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        _makeBarGroup(0, 4500),
                        _makeBarGroup(1, 6200),
                        _makeBarGroup(2, 3800),
                        _makeBarGroup(3, 8100),
                        _makeBarGroup(4, 5400),
                        _makeBarGroup(5, 7200),
                        _makeBarGroup(6, 3900),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Top Products
            const Text('أفضل المنتجات مبيعاً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  _ProductRankItem(rank: 1, name: 'مياه معدنية 1.5ل', sales: 245, revenue: 12250),
                  const Divider(height: 1),
                  _ProductRankItem(rank: 2, name: 'شيبس ليز', sales: 198, revenue: 9900),
                  const Divider(height: 1),
                  _ProductRankItem(rank: 3, name: 'كوكا كولا 1ل', sales: 176, revenue: 8800),
                  const Divider(height: 1),
                  _ProductRankItem(rank: 4, name: 'خبز فرنسي', sales: 150, revenue: 4500),
                  const Divider(height: 1),
                  _ProductRankItem(rank: 5, name: 'حليب طازج', sales: 134, revenue: 6700),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: const Color(0xFF1E88E5),
          width: 20,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DateButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ReportCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}

class _ProductRankItem extends StatelessWidget {
  final int rank;
  final String name;
  final int sales;
  final double revenue;

  const _ProductRankItem({required this.rank, required this.name, required this.sales, required this.revenue});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: rank <= 3 ? const Color(0xFFFF9800).withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        child: Text('$rank', style: TextStyle(
          color: rank <= 3 ? const Color(0xFFFF9800) : Colors.grey,
          fontWeight: FontWeight.bold,
        )),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('$sales مبيعة'),
      trailing: Text('${revenue.toStringAsFixed(0)} د.ج', style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
