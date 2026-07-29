import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/sale.dart';
import '../../services/printer_service.dart';
import '../../services/database_service.dart';

class SaleReceiptScreen extends StatelessWidget {
  final Sale sale;

  const SaleReceiptScreen({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة المبيعات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printReceipt(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareReceipt,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Receipt Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Header
                    const Icon(Icons.point_of_sale, size: 48, color: Color(0xFF1E88E5)),
                    const SizedBox(height: 8),
                    const Text(
                      'ZAD Store',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Text('فاتورة مبيعات', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    const Divider(),

                    // Invoice Info
                    _buildInfoRow('رقم الفاتورة:', sale.invoiceNumber),
                    _buildInfoRow('التاريخ:', _formatDate(sale.date)),
                    if (sale.customerName != null)
                      _buildInfoRow('العميل:', sale.customerName!),
                    const Divider(),

                    // Items
                    const Row(
                      children: [
                        Expanded(flex: 3, child: Text('المنتج', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text('الكمية', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('السعر', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const Divider(),
                    ...sale.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(item.productName)),
                          Expanded(flex: 1, child: Text('${item.quantity}', textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('${item.total.toStringAsFixed(2)} د.ج', textAlign: TextAlign.end)),
                        ],
                      ),
                    )),
                    const Divider(),

                    // Totals
                    _buildTotalRow('المجموع:', sale.subtotal),
                    if (sale.discount > 0)
                      _buildTotalRow('الخصم:', sale.discount, isDiscount: true),
                    if (sale.tax > 0)
                      _buildTotalRow('الضريبة:', sale.tax),
                    const Divider(),
                    _buildTotalRow('الإجمالي:', sale.total, isBold: true),
                    const SizedBox(height: 16),

                    // Payment
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF43A047).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.payment, color: Color(0xFF43A047)),
                          const SizedBox(width: 8),
                          Text(
                            'طريقة الدفع: ${_getPaymentMethodName(sale.paymentMethod)}',
                            style: const TextStyle(color: Color(0xFF43A047), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // QR Code placeholder
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(child: Icon(Icons.qr_code, size: 80, color: Colors.grey)),
                    ),
                    const SizedBox(height: 16),
                    const Text('شكراً لزيارتكم', style: TextStyle(color: Colors.grey)),
                    const Text('ZAD Mobile POS', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Print Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _printReceipt(context),
                icon: const Icon(Icons.print),
                label: const Text('طباعة الفاتورة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double value, {bool isBold = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 18 : 14)),
          Text(
            '${value.toStringAsFixed(2)} د.ج',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 20 : 14,
              color: isDiscount ? Colors.red : (isBold ? const Color(0xFF1E88E5) : null),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'cash': return 'نقداً';
      case 'card': return 'بطاقة';
      case 'transfer': return 'تحويل';
      case 'credit': return 'آجل';
      default: return method;
    }
  }

  Future<void> _printReceipt(BuildContext context) async {
    final ip = await DatabaseService().getSetting('printer_ip') ?? '192.168.1.100';
    final printer = PrinterService();
    final connected = await printer.connect(ip);
    if (!context.mounted) return;
    if (connected) {
      await printer.printSaleReceipt(sale);
      await printer.disconnect();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت الطباعة بنجاح')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الاتصال بالطابعة ($ip). تحقق من الإعدادات.')),
      );
    }
  }

  Future<void> _shareReceipt() async {
    final buffer = StringBuffer();
    buffer.writeln('ZAD Store - فاتورة مبيعات');
    buffer.writeln('رقم الفاتورة: ${sale.invoiceNumber}');
    buffer.writeln('التاريخ: ${_formatDate(sale.date)}');
    if (sale.customerName != null) buffer.writeln('العميل: ${sale.customerName}');
    buffer.writeln('-------------------------');
    for (final item in sale.items) {
      buffer.writeln('${item.productName}  x${item.quantity}  ${item.total.toStringAsFixed(2)} د.ج');
    }
    buffer.writeln('-------------------------');
    buffer.writeln('المجموع: ${sale.subtotal.toStringAsFixed(2)} د.ج');
    if (sale.discount > 0) buffer.writeln('الخصم: ${sale.discount.toStringAsFixed(2)} د.ج');
    if (sale.tax > 0) buffer.writeln('الضريبة: ${sale.tax.toStringAsFixed(2)} د.ج');
    buffer.writeln('الإجمالي: ${sale.total.toStringAsFixed(2)} د.ج');
    buffer.writeln('طريقة الدفع: ${_getPaymentMethodName(sale.paymentMethod)}');
    buffer.writeln('شكراً لزيارتكم - ZAD Mobile POS');

    await Share.share(buffer.toString(), subject: 'فاتورة ${sale.invoiceNumber}');
  }
}
