import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/report_provider.dart';

class DetailedReportsScreen extends StatefulWidget {
  const DetailedReportsScreen({super.key});

  @override
  State<DetailedReportsScreen> createState() => _DetailedReportsScreenState();
}

class _DetailedReportsScreenState extends State<DetailedReportsScreen> {
  final List<String> _periods = ['today', 'week', 'month', 'year'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().loadDetailedReport('today');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير المفصلة')),
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          final report = provider.detailedReport;

          return Column(
            children: [
              // Period Selector
              Container(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<String>(
                  segments: _periods.map((p) => ButtonSegment(
                    value: p,
                    label: Text(provider.getPeriodLabel(p)),
                  )).toList(),
                  selected: {provider.selectedPeriod},
                  onSelectionChanged: (selected) {
                    provider.loadDetailedReport(selected.first);
                  },
                ),
              ),

              if (provider.isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator())),

              if (!provider.isLoading) ...[
                // Summary Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _SummaryCard(
                        title: 'الفواتير',
                        value: '${report['salesCount'] ?? 0}',
                        icon: Icons.receipt,
                        color: const Color(0xFF1E88E5),
                      ),
                      _SummaryCard(
                        title: 'المبيعات',
                        value: '${(report['salesTotal'] ?? 0.0).toStringAsFixed(0)} د.ج',
                        icon: Icons.attach_money,
                        color: const Color(0xFF43A047),
                      ),
                      _SummaryCard(
                        title: 'الأرباح',
                        value: '${(report['profit'] ?? 0.0).toStringAsFixed(0)} د.ج',
                        icon: Icons.trending_up,
                        color: const Color(0xFF7E57C2),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Payment Methods
                if ((report['paymentMethods'] as List?)?.isNotEmpty ?? false)
                  _PaymentMethodsChart(paymentMethods: report['paymentMethods']),

                const SizedBox(height: 8),

                // Top Products
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'أفضل المنتجات مبيعاً',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: (report['topProducts'] as List?)?.length ?? 0,
                            itemBuilder: (context, index) {
                              final product = (report['topProducts'] as List)[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: index < 3
                                      ? const Color(0xFFFF9800).withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.2),
                                  child: Text('${index + 1}', style: TextStyle(
                                    color: index < 3 ? const Color(0xFFFF9800) : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  )),
                                ),
                                title: Text(product['product_name'] ?? ''),
                                subtitle: Text('${product['qty']} قطعة مباعة'),
                                trailing: Text(
                                  '${(product['revenue'] as num?)?.toDouble().toStringAsFixed(0) ?? 0} د.ج',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodsChart extends StatelessWidget {
  final List<dynamic> paymentMethods;

  const _PaymentMethodsChart({required this.paymentMethods});

  @override
  Widget build(BuildContext context) {
    final colors = [const Color(0xFF43A047), const Color(0xFF1E88E5), const Color(0xFFFF9800), const Color(0xFFE53935)];
    final methodNames = {'cash': 'نقداً', 'card': 'بطاقة', 'transfer': 'تحويل', 'credit': 'آجل'};

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('طرق الدفع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: paymentMethods.asMap().entries.map((entry) {
                          final index = entry.key;
                          final method = entry.value;
                          final total = paymentMethods.fold<double>(0, (sum, m) => sum + ((m['total'] as num?)?.toDouble() ?? 0));
                          final value = (method['total'] as num?)?.toDouble() ?? 0;
                          final percentage = total > 0 ? (value / total * 100) : 0;
                          return PieChartSectionData(
                            color: colors[index % colors.length],
                            value: value,
                            title: '${percentage.toStringAsFixed(0)}%',
                            radius: 50,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: paymentMethods.asMap().entries.map((entry) {
                        final index = entry.key;
                        final method = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[index % colors.length], borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 8),
                              Text(methodNames[method['payment_method']] ?? method['payment_method']),
                              const Spacer(),
                              Text('${(method['total'] as num?)?.toDouble().toStringAsFixed(0) ?? 0} د.ج'),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
