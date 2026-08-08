import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/supplier.dart';
import '../../models/expense.dart';
import '../../models/product.dart';
import '../../models/purchase_order.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierProvider>().loadSuppliers();
      context.read<ExpenseProvider>().loadExpenses();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الموردون والمصاريف'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.local_shipping), text: 'الموردون'),
            Tab(icon: Icon(Icons.receipt_long), text: 'المصاريف'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SuppliersTab(),
          _ExpensesTab(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          return FloatingActionButton.extended(
            onPressed: () {
              if (_tabController.index == 0) {
                _showAddSupplierDialog(context);
              } else {
                _showAddExpenseDialog(context);
              }
            },
            icon: Icon(_tabController.index == 0 ? Icons.local_shipping : Icons.add),
            label: Text(_tabController.index == 0 ? 'مورد جديد' : 'مصروف جديد'),
          );
        },
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

  void _showAddExpenseDialog(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String selectedCategory = 'أخرى';
    const categories = ['كراء', 'كهرباء وماء', 'رواتب', 'نقل', 'صيانة', 'أخرى'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة مصروف'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'عنوان المصروف *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المبلغ *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder()),
                  value: selectedCategory,
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selectedCategory = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim()) ?? 0;
                if (titleController.text.trim().isEmpty || amount <= 0) return;
                final expense = Expense(
                  title: titleController.text.trim(),
                  amount: amount,
                  category: selectedCategory,
                  notes: notesController.text.isEmpty ? null : notesController.text,
                  date: DateTime.now(),
                  createdAt: DateTime.now(),
                );
                await context.read<ExpenseProvider>().addExpense(expense);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
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

void _showAddDebtDialog(BuildContext context, Supplier supplier) {
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('إضافة دين (دائن)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('المستحق حالياً: ${supplier.balance.toStringAsFixed(2)} د.ج'),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            autofocus: true,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'المبلغ المضاف للدين',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'سبب الدين (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            final amount = double.tryParse(amountController.text.trim()) ?? 0;
            if (amount <= 0 || supplier.id == null) return;
            await context.read<SupplierProvider>().addDebtManually(supplier.id!, amount);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );
}

void _showPurchaseInvoiceDialog(BuildContext context, Supplier supplier) {
  final List<_InvoiceLine> lines = [];
  final notesController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        double total = lines.fold(0.0, (sum, l) => sum + (l.quantity * l.unitPrice));
        return AlertDialog(
          title: Text('فاتورة شراء من ${supplier.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Consumer<InventoryProvider>(
                    builder: (context, inventory, _) {
                      if (inventory.products.isEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          inventory.loadProducts();
                        });
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<Product>(
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'اختر منتج'),
                              items: inventory.products
                                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                                  .toList(),
                              onChanged: (product) {
                                if (product != null) {
                                  setDialogState(() {
                                    lines.add(_InvoiceLine(
                                      product: product,
                                      quantity: 1,
                                      unitPrice: product.purchasePrice,
                                    ));
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ...lines.asMap().entries.map((entry) {
                    final index = entry.key;
                    final line = entry.value;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(line.product.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => setDialogState(() => lines.removeAt(index)),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: '${line.quantity}',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'الكمية'),
                                    onChanged: (v) => line.quantity = int.tryParse(v) ?? line.quantity,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: line.unitPrice.toStringAsFixed(2),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: 'سعر الوحدة'),
                                    onChanged: (v) {
                                      line.unitPrice = double.tryParse(v) ?? line.unitPrice;
                                      setDialogState(() {});
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${total.toStringAsFixed(2)} د.ج', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: lines.isEmpty
                  ? null
                  : () async {
                      final order = PurchaseOrder(
                        supplierId: supplier.id,
                        supplierName: supplier.name,
                        date: DateTime.now(),
                        total: total,
                        status: 'received',
                        notes: notesController.text.isEmpty ? null : notesController.text,
                        createdAt: DateTime.now(),
                        items: lines
                            .map((l) => PurchaseOrderItem(
                                  productId: l.product.id,
                                  productName: l.product.name,
                                  quantity: l.quantity,
                                  unitPrice: l.unitPrice,
                                  total: l.quantity * l.unitPrice,
                                ))
                            .toList(),
                      );
                      await context.read<SupplierProvider>().recordPurchaseOrder(order);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              child: const Text('حفظ الفاتورة'),
            ),
          ],
        );
      },
    ),
  );
}

class _InvoiceLine {
  final Product product;
  int quantity;
  double unitPrice;

  _InvoiceLine({required this.product, required this.quantity, required this.unitPrice});
}

class _SuppliersTab extends StatelessWidget {
  const _SuppliersTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<SupplierProvider>(
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
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final Supplier supplier;

  const _SupplierCard({required this.supplier});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            ListTile(
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.receipt, size: 16),
                      label: const Text('فاتورة', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showPurchaseInvoiceDialog(context, supplier),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.add_card, size: 16),
                      label: const Text('دائن', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showAddDebtDialog(context, supplier),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                      icon: const Icon(Icons.payments, size: 16),
                      label: const Text('تسديد', style: TextStyle(fontSize: 12)),
                      onPressed: supplier.balance > 0 ? () => _showPaySupplierDialog(context, supplier) : null,
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

class _ExpensesTab extends StatelessWidget {
  const _ExpensesTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إجمالي مصاريف هذا الشهر', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${provider.totalThisMonth.toStringAsFixed(2)} د.ج',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE53935), fontSize: 16),
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.expenses.isEmpty
                  ? const Center(child: Text('لا توجد مصاريف مسجلة'))
                  : ListView.builder(
                      itemCount: provider.expenses.length,
                      itemBuilder: (context, index) {
                        final expense = provider.expenses[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0x1AE53935),
                              child: Icon(Icons.receipt_long, color: Color(0xFFE53935)),
                            ),
                            title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${expense.category ?? ''} • ${expense.date.day}/${expense.date.month}/${expense.date.year}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${expense.amount.toStringAsFixed(2)} د.ج',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE53935)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                  onPressed: () {
                                    if (expense.id != null) {
                                      context.read<ExpenseProvider>().deleteExpense(expense.id!);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
