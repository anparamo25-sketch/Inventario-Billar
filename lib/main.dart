import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() => runApp(const InventarioApp());

class Product {
  final String name;
  final int price;
  final int packSize;
  int warehouseUnits;
  int freezerUnits;

  Product({required this.name, required this.price, required this.packSize, this.warehouseUnits = 0, this.freezerUnits = 0});
}

final products = <Product>[
  Product(name: 'Toña pequeña', price: 46, packSize: 24),
  Product(name: 'Litro Toña', price: 95, packSize: 12),
  Product(name: 'Frost litro', price: 80, packSize: 12),
  Product(name: 'Frost pequeña', price: 40, packSize: 24),
  Product(name: 'Gaseosa', price: 25, packSize: 24),
];

class Loan {
  final String person;
  final int amount;
  final String reason;
  final DateTime date;
  Loan(this.person, this.amount, this.reason, this.date);
}

class Consumption {
  final String person;
  final String product;
  final int quantity;
  final int value;
  final DateTime date;
  Consumption(this.person, this.product, this.quantity, this.value, this.date);
}

class Movement {
  final String product;
  final int units;
  final DateTime date;
  Movement(this.product, this.units, this.date);
}

class InventarioApp extends StatelessWidget {
  const InventarioApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Inventario Billar',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  final loans = <Loan>[];
  final consumptions = <Consumption>[];
  final movements = <Movement>[];
  final saleUnits = <String, int>{};
  bool dayClosed = false;
  int lastSales = 0;
  int lastExpectedCash = 0;
  int lastActualCash = 0;
  int lastDifference = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [dashboard(), warehouse(), freezer(), const HistoryPage()];
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario Billar')),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Bodega'),
          NavigationDestination(icon: Icon(Icons.ac_unit), label: 'Freezer'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
        ],
      ),
      floatingActionButton: dayClosed
          ? null
          : FloatingActionButton.extended(
              onPressed: closeDay,
              icon: const Icon(Icons.lock_clock),
              label: const Text('Cerrar jornada'),
            ),
    );
  }

  Widget dashboard() {
    final warehouse = products.fold<int>(0, (s, p) => s + p.warehouseUnits);
    final freezer = products.fold<int>(0, (s, p) => s + p.freezerUnits);
    final expected = lastSales - loans.fold<int>(0, (s, l) => s + l.amount) - consumptions.fold<int>(0, (s, c) => s + c.value);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Resumen de hoy', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: statCard('Bodega', '$warehouse unidades', Icons.warehouse_outlined)),
        const SizedBox(width: 12),
        Expanded(child: statCard('Freezer', '$freezer unidades', Icons.ac_unit)),
      ]),
      const SizedBox(height: 12),
      Card(child: ListTile(leading: const Icon(Icons.point_of_sale), title: const Text('Ventas de cierre'), subtitle: Text('C\$${NumberFormat('#,##0').format(lastSales)}'))),
      Card(child: ListTile(leading: const Icon(Icons.account_balance_wallet_outlined), title: const Text('Efectivo esperado'), subtitle: Text('C\$${NumberFormat('#,##0').format(expected)}'))),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: dayClosed ? null : () => addLoan(), icon: const Icon(Icons.payments_outlined), label: const Text('Registrar préstamo / retiro')),
      OutlinedButton.icon(onPressed: dayClosed ? null : () => addConsumption(), icon: const Icon(Icons.restaurant_outlined), label: const Text('Registrar consumo del propietario')),
      const SizedBox(height: 8),
      Card(child: ListTile(title: const Text('Movimientos bodega → freezer'), subtitle: Text('${movements.length} movimientos registrados'))),
    ]);
  }

  Widget statCard(String title, String value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const SizedBox(height: 8), Text(title), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))])));

  Widget warehouse() => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Bodega', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Existencia interna por unidades. La pantalla muestra cajillas + unidades.'),
        const SizedBox(height: 12),
        ...products.map((p) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('${p.warehouseUnits ~/ p.packSize} cajillas + ${p.warehouseUnits % p.packSize} unidades  •  ${p.warehouseUnits} unidades'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => editWarehouse(p), icon: const Icon(Icons.edit), label: const Text('Ajustar'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(onPressed: dayClosed ? null : () => moveToFreezer(p), icon: const Icon(Icons.south), label: const Text('Pasar a freezer'))),
          ]),
        ]))))
      ]);

  Widget freezer() => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Freezer', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Las existencias se manejan en unidades. Las ventas y consumos descuentan unidades.'),
        const SizedBox(height: 12),
        ...products.map((p) => Card(child: ListTile(
          leading: const Icon(Icons.ac_unit),
          title: Text(p.name),
          subtitle: Text('${p.freezerUnits} unidades disponibles'),
          trailing: Text('C\$${p.price}'),
        )))
      ]);

  Future<void> editWarehouse(Product p) async {
    final c = TextEditingController(text: p.warehouseUnits.toString());
    final value = await showDialog<int>(context: context, builder: (_) => AlertDialog(title: Text('Bodega: ${p.name}'), content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Unidades totales')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(c.text) ?? 0), child: const Text('Guardar'))]));
    c.dispose();
    if (value != null && value >= 0) setState(() => p.warehouseUnits = value);
  }

  Future<void> moveToFreezer(Product p) async {
    final c = TextEditingController();
    final units = await showDialog<int>(context: context, builder: (_) => AlertDialog(
      title: Text('Pasar ${p.name} al freezer'),
      content: TextField(controller: c, autofocus: true, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Unidades a trasladar', helperText: 'Disponible en bodega: ${p.warehouseUnits}')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(c.text) ?? 0), child: const Text('Trasladar'))],
    ));
    c.dispose();
    if (units == null || units <= 0) return;
    if (units > p.warehouseUnits) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay suficientes unidades en bodega.')));
      return;
    }
    setState(() {
      p.warehouseUnits -= units;
      p.freezerUnits += units;
      movements.add(Movement(p.name, units, DateTime.now()));
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$units unidades de ${p.name} pasaron al freezer.')));
  }

  Future<void> addLoan() async {
    final person = TextEditingController();
    final amount = TextEditingController();
    final reason = TextEditingController();
    final result = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Préstamo / retiro'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: person, decoration: const InputDecoration(labelText: 'Persona')),
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monto C$')),
        TextField(controller: reason, decoration: const InputDecoration(labelText: 'Motivo / observación')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar'))],
    ));
    if (result == true) {
      final value = int.tryParse(amount.text) ?? 0;
      if (person.text.trim().isNotEmpty && value > 0) setState(() => loans.add(Loan(person.text.trim(), value, reason.text.trim(), DateTime.now())));
    }
    person.dispose(); amount.dispose(); reason.dispose();
  }

  Future<void> addConsumption() async {
    String? selected;
    final person = TextEditingController();
    final qty = TextEditingController(text: '1');
    final result = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('Consumo del propietario'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: person, decoration: const InputDecoration(labelText: 'Quién consumió')),
        DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Producto'), items: products.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name))).toList(), onChanged: (v) => setDialogState(() => selected = v)),
        TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cantidad de unidades')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar'))],
    )));
    if (result == true && selected != null) {
      final p = products.firstWhere((x) => x.name == selected);
      final quantity = int.tryParse(qty.text) ?? 0;
      final value = quantity * p.price;
      if (quantity > 0 && quantity <= p.freezerUnits && person.text.trim().isNotEmpty) {
        setState(() {
          p.freezerUnits -= quantity;
          consumptions.add(Consumption(person.text.trim(), p.name, quantity, value, DateTime.now()));
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verifica persona, cantidad y existencia en freezer.')));
      }
    }
    person.dispose(); qty.dispose();
  }

  Future<void> closeDay() async {
    final remaining = <String, int>{for (final p in products) p.name: p.freezerUnits};
    final controllers = <String, TextEditingController>{for (final p in products) p.name: TextEditingController(text: p.freezerUnits.toString())};

    final confirmed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ClosingPage(products: products, controllers: controllers, onSave: (counts) {
      remaining
        ..clear()
        ..addAll(counts);
    })));
    for (final c in controllers.values) c.dispose();
    if (confirmed != true || !mounted) return;

    int sales = 0;
    int unitsSold = 0;
    for (final p in products) {
      final finalCount = remaining[p.name] ?? p.freezerUnits;
      final sold = p.freezerUnits - finalCount;
      if (sold > 0) {
        p.freezerUnits = finalCount;
        saleUnits[p.name] = (saleUnits[p.name] ?? 0) + sold;
        unitsSold += sold;
        sales += sold * p.price;
      }
    }
    lastSales = sales;
    final loanTotal = loans.fold<int>(0, (s, l) => s + l.amount);
    final consumptionTotal = consumptions.fold<int>(0, (s, c) => s + c.value);
    lastExpectedCash = sales - loanTotal - consumptionTotal;

    final actual = await askActualCash(lastExpectedCash, unitsSold, sales, loanTotal, consumptionTotal);
    if (actual == null || !mounted) return;
    lastActualCash = actual;
    lastDifference = actual - lastExpectedCash;
    await showArqueoSummary(sales, loanTotal, consumptionTotal, lastExpectedCash, actual, lastDifference);
    if (!mounted) return;
    await refillFreezers();
  }

  Future<int?> askActualCash(int expected, int units, int sales, int loansTotal, int consumptionTotal) async {
    final c = TextEditingController();
    return showDialog<int>(context: context, builder: (_) => AlertDialog(
      title: const Text('Arqueo de jornada'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Unidades vendidas: $units'),
        Text('Ventas: C\$${NumberFormat('#,##0').format(sales)}'),
        Text('Préstamos/retiros: - C\$${NumberFormat('#,##0').format(loansTotal)}'),
        Text('Consumos: - C\$${NumberFormat('#,##0').format(consumptionTotal)}'),
        const SizedBox(height: 12),
        Text('Efectivo esperado: C\$${NumberFormat('#,##0').format(expected)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Efectivo contado en caja')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(c.text)), child: const Text('Confirmar arqueo'))],
    ));
  }

  Future<void> showArqueoSummary(int sales, int loansTotal, int consumptionTotal, int expected, int actual, int difference) async {
    final label = difference == 0 ? 'Exacto' : difference < 0 ? 'Faltante' : 'Sobrante';
    await showDialog<void>(context: context, builder: (_) => AlertDialog(
      title: const Text('Arqueo final'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Ventas: C\$${NumberFormat('#,##0').format(sales)}'),
        Text('Préstamos/retiros: C\$${NumberFormat('#,##0').format(loansTotal)}'),
        Text('Consumos: C\$${NumberFormat('#,##0').format(consumptionTotal)}'),
        const Divider(),
        Text('Esperado: C\$${NumberFormat('#,##0').format(expected)}'),
        Text('Contado: C\$${NumberFormat('#,##0').format(actual)}'),
        const SizedBox(height: 8),
        Text('$label: C\$${NumberFormat('#,##0').format(difference.abs())}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ]),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Continuar a Rellenar Freezer'))],
    ));
  }

  Future<void> refillFreezers() async {
    for (final p in products) {
      if (!mounted) return;
      final c = TextEditingController(text: '0');
      final add = await showDialog<int>(context: context, builder: (_) => AlertDialog(title: Text('Rellenar: ${p.name}'), content: TextField(controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Unidades a sacar de bodega', helperText: 'Freezer actual: ${p.freezerUnits} unidades')), actions: [TextButton(onPressed: () => Navigator.pop(context, 0), child: const Text('Omitir')), FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(c.text) ?? 0), child: const Text('Agregar'))]));
      c.dispose();
      if (add == null || add < 0) return;
      if (add > p.warehouseUnits) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No hay suficientes unidades de ${p.name} en bodega.')));
        return;
      }
      if (add > 0) setState(() { p.warehouseUnits -= add; p.freezerUnits += add; movements.add(Movement(p.name, add, DateTime.now())); });
    }
    if (mounted) {
      setState(() => dayClosed = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jornada cerrada y freezer preparado para el siguiente día.')));
    }
  }
}

class ClosingPage extends StatefulWidget {
  final List<Product> products;
  final Map<String, TextEditingController> controllers;
  final void Function(Map<String, int>) onSave;
  const ClosingPage({super.key, required this.products, required this.controllers, required this.onSave});
  @override
  State<ClosingPage> createState() => _ClosingPageState();
}

class _ClosingPageState extends State<ClosingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cierre de jornada')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Inventario final del freezer', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Registra en cada tarjeta cuántas unidades quedan. El sistema calculará las ventas automáticamente.'),
        const SizedBox(height: 16),
        ...widget.products.map((p) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), Text('C\$${p.price}')]),
          const SizedBox(height: 8),
          Text('Inicio disponible: ${p.freezerUnits} unidades'),
          const SizedBox(height: 8),
          TextField(controller: widget.controllers[p.name], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Unidades que quedan en freezer', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          ValueListenableBuilder<TextEditingValue>(valueListenable: widget.controllers[p.name]!, builder: (_, value, __) {
            final finalCount = int.tryParse(value.text) ?? p.freezerUnits;
            final sold = (p.freezerUnits - finalCount).clamp(0, p.freezerUnits);
            return Text('Venta calculada: $sold unidades  •  C\$${NumberFormat('#,##0').format(sold * p.price)}', style: const TextStyle(fontWeight: FontWeight.w600));
          }),
        ]))))),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: () {
          final counts = <String, int>{};
          for (final p in widget.products) {
            final value = int.tryParse(widget.controllers[p.name]!.text);
            if (value == null || value < 0 || value > p.freezerUnits) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cantidad inválida en ${p.name}.')));
              return;
            }
            counts[p.name] = value;
          }
          widget.onSave(counts);
          Navigator.pop(context, true);
        }, icon: const Icon(Icons.check_circle_outline), label: const Text('Confirmar inventario y continuar al arqueo')),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) => const ListView(padding: EdgeInsets.all(16), children: [Text('Historial', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('La estructura de historial y reportes PDF se implementará en la siguiente fase de persistencia.')]);
}
