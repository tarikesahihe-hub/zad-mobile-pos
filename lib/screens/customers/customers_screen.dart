import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/customer_provider.dart';
import '../../models/customer.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('العملاء')),
      body: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.customers.isEmpty) {
            return const Center(child: Text('لا يوجد عملاء'));
          }
          return ListView.builder(
            itemCount: provider.customers.length,
            itemBuilder: (context, index) {
              final customer = provider.customers[index];
              return _CustomerCard(customer: customer);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('عميل جديد'),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة عميل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'الاسم *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final customer = Customer(
                name: nameController.text.trim(),
                phone: phoneController.text.isEmpty ? null : phoneController.text,
                createdAt: DateTime.now(),
              );
              await context.read<CustomerProvider>().addCustomer(customer);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}
void _showPayDebtDialog(BuildContext context, Customer customer) {
  final amountController = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('تسديد دين'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('الدين الحالي: ${customer.balance.toStringAsFixed(2)} د.ج'),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            autofocus: true,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'المبلغ المدفوع',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () async {
            final paid = double.tryParse(amountController.text.trim()) ?? 0;
            if (paid <= 0) return;
            final newBalance = customer.balance - paid;
            final updated = customer.copyWith(
              balance: newBalance < 0 ? 0 : newBalance,
            );
            await context.read<CustomerProvider>().updateCustomer(updated);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('تأكيد الدفع'),
        ),
      ],
    ),
  );
}
class _CustomerCard extends StatelessWidget {
  final Customer customer;

  const _CustomerCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1E88E5).withOpacity(0.1),
          child: Text(customer.name[0], style: const TextStyle(color: Color(0xFF1E88E5))),
        ),
        title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.phone != null) Text(customer.phone!),
            Text('نقاط الولاء: ${customer.loyaltyPoints}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
                Text(
                  '${customer.balance.toStringAsFixed(2)} د.ج',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: customer.balance > 0 ? Colors.red : const Color(0xFF43A047),
                  ),
                ),
                const Text('الرصيد', style: TextStyle(fontSize: 11, color: Colors.grey)),
                if (customer.balance > 0)
                  IconButton(
                    icon: const Icon(Icons.payments, color: Colors.green, size: 20),
                    tooltip: 'تسديد دين',
                    onPressed: () => _showPayDebtDialog(context, customer),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
        ),
      ),
    );
  }
}
