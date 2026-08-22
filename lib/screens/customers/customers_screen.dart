import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/app_provider.dart';
import '../../models/customer.dart';
import '../../l10n/app_strings.dart';

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
      appBar: AppBar(title: Text(AppStrings.get(context, 'cust_title'))),
      body: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.customers.isEmpty) {
            return Center(child: Text(AppStrings.get(context, 'cust_no_customers')));
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
        label: Text(AppStrings.get(context, 'cust_new_customer')),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.get(context, 'cust_add_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: AppStrings.get(context, 'cust_name_required'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: AppStrings.get(context, 'cust_phone'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.get(context, 'common_cancel')),
          ),
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
            child: Text(AppStrings.get(context, 'common_add')),
          ),
        ],
      ),
    );
  }
}

void _showPayDebtDialog(BuildContext context, Customer customer) {
  final amountController = TextEditingController();
  final currency = context.read<AppProvider>().currencySymbol;
  final debtText = AppStrings
      .get(context, 'cust_current_debt')
      .replaceAll('{amount}', customer.balance.toStringAsFixed(2))
      .replaceAll('د.ج', currency)
      .replaceAll('DA', currency)
      .replaceAll('DZD', currency);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(AppStrings.get(context, 'cust_pay_debt_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(debtText),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            autofocus: true,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: AppStrings.get(context, 'cust_amount_paid'),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(AppStrings.get(context, 'common_cancel')),
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
          child: Text(AppStrings.get(context, 'cust_confirm_payment')),
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
    final currency = context.watch<AppProvider>().currencySymbol;
    final loyaltyText = AppStrings
        .get(context, 'cust_loyalty_points')
        .replaceAll('{points}', '${customer.loyaltyPoints}');

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
            Text(loyaltyText),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${customer.balance.toStringAsFixed(2)} $currency',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: customer.balance > 0 ? Colors.red : const Color(0xFF43A047),
              ),
            ),
            Text(AppStrings.get(context, 'cust_balance'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (customer.balance > 0)
              IconButton(
                icon: const Icon(Icons.payments, color: Colors.green, size: 20),
                tooltip: AppStrings.get(context, 'cust_pay_debt_title'),
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
