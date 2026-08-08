import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/supplier_provider.dart';
import '../../models/supplier.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierProvider>().loadSuppliers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الموردون')),
      body: Consumer<SupplierProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.suppliers.isEmpty) {
            return const Center(child: Text('لا يوجد موردون'));
          }
          return ListView.builder(
            itemCount: provider.suppliers.length,
            itemBuilder: (context, index) {
              final supplier = provider.suppliers[index];
              return _SupplierCard(supplier: supplier);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSupplierDialog(context),
        icon: const Icon(Icons.local_shipping),
        label: const Text('مورد جديد'),
      ),
    );
  }

  void _showAddSupplierDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مورد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'اسم المورد *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final supplier = Supplier(
                name: nameController.text.trim(),
                phone: phoneController.text.isEmpty ? null : phoneController.text,
                email: emailController.text.isEmpty ? null : emailController.text,
                address: addressController.text.isEmpty ? null : addressController.text,
                createdAt: DateTime.now(),
              );
              await context.read<SupplierProvider>().addSupplier(supplier);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

void _showPaySupplierDialog(BuildContext context, Supplier supplier) {
  final amountController = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('تسديد للمورد'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('المستحق للمورد حالياً: ${supplier.balance.toStringAsFixed(2)} د.ج'),
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
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () async {
            final paid = double.tryParse(amountController.text.trim()) ?? 0;
            if (paid <= 0) return;
            final newBalance = supplier.balance - paid;
            final updated = Supplier(
              id: supplier.id,
              name: supplier.name,
              phone: supplier.phone,
              email: supplier.email,
              address: supplier.address,
              balance: newBalance < 0 ? 0 : newBalance,
              createdAt: supplier.createdAt,
            );
            await context.read<SupplierProvider>().updateSupplier(updated);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('تأكيد الدفع'),
        ),
      ],
    ),
  );
}

class _SupplierCard extends StatelessWidget {
  final Supplier supplier;

  const _SupplierCard({required this.supplier});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFF9800).withOpacity(0.1),
          child: Text(supplier.name[0], style: const TextStyle(color: Color(0xFFFF9800))),
        ),
        title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (supplier.phone != null) Text(supplier.phone!),
            if (supplier.address != null) Text(supplier.address!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${supplier.balance.toStringAsFixed(2)} د.ج',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: supplier.balance > 0 ? Colors.red : const Color(0xFF43A047),
              ),
            ),
            const Text('مستحق للمورد', style: TextStyle(fontSize: 11, color: Colors.grey)),
            if (supplier.balance > 0)
              IconButton(
                icon: const Icon(Icons.payments, color: Colors.green, size: 20),
                tooltip: 'تسديد للمورد',
                onPressed: () => _showPaySupplierDialog(context, supplier),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}
