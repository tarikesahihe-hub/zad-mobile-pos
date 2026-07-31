import 'package:flutter/material.dart';
import '../../models/sale.dart';
import '../../services/database_service.dart';
import 'invoice_edit_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  late Future<List<Sale>> _salesFuture;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  void _loadSales() {
    _salesFuture = DatabaseService().getAllSales();
  }

  Future<void> _refresh() async {
    setState(_loadSales);
    await _salesFuture;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الفواتير')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Sale>>(
          future: _salesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final sales = snapshot.data ?? [];
            if (sales.isEmpty) {
              return const Center(child: Text('لا توجد فواتير بعد'));
            }
            return ListView.separated(
              itemCount: sales.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final sale = sales[index];
                final isCredit = sale.paymentMethod == 'credit';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCredit ? Colors.orange.shade100 : const Color(0xFF1E88E5).withOpacity(0.1),
                    child: Icon(
                      isCredit ? Icons.credit_score : Icons.receipt,
                      color: isCredit ? Colors.orange : const Color(0xFF1E88E5),
                    ),
                  ),
                  title: Text(sale.invoiceNumber),
                  subtitle: Text(
                    '${_formatDate(sale.date)}'
                    '${sale.customerName != null ? " — ${sale.customerName}" : ""}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${sale.total.toStringAsFixed(2)} د.ج',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (sale.status == 'cancelled')
                        const Text('ملغاة', style: TextStyle(color: Colors.red, fontSize: 11)),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvoiceEditScreen(saleId: sale.id!),
                      ),
                    );
                    _refresh();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
