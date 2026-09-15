import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const InventarioApp());
}

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
  final warehouseControllers = <String, TextEditingController>{};
  final freezerControllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final p in products) {
      warehouseControllers[p.name] = TextEditingController(text: '0');
      freezerControllers[p.name] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    for (final c in warehouseControllers.values) c.dispose();
    for (final c in freezerControllers.values) c.dispose();
    super.dispose();
  }

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: closeDay,
        icon: const Icon(Icons.lock_clock),
        label: const Text('Cerrar jornada'),
      ),
    );
  }

  Widget dashboard() {
    final freezer = products.fold<int>(0, (s, p) => s + p.freezerUnits);
    final warehouse = products.fold<int>(0, (s, p) => s + p.warehouseUnits);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Resumen de hoy', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: statCard('Bodega', '$warehouse unidades', Icons.warehouse_outlined)),
        const SizedBox(width: 12),
        Expanded(child: statCard('Freezer', '$freezer unidades', Icons.ac_unit)),
      ]),
      const SizedBox(height: 12),
      Card(child: ListTile(leading: const Icon(Icons.point_of_sale), title: const Text('Cierre de jornada'), subtitle: const Text('Registrar lo que queda en cada freezer y calcular ventas.'))),
      Card(child: ListTile(leading: const Icon(Icons.payments_outlined), title: const Text('Préstamos y consumos'), subtitle: const Text('Se descuentan automáticamente del arqueo.'))),
    ]);
  }

  Widget statCard(String title, String value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const SizedBox(height: 8), Text(title), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))])));

  Widget warehouse() => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Bodega', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('La bodega se controla por cajillas y unidades equivalentes.'),
        const SizedBox(height: 12),
        ...products.map((p) => Card(child: ListTile(title: Text(p.name), subtitle: Text('${p.warehouseUnits ~/ p.packSize} cajillas + ${p.warehouseUnits % p.packSize} unidades | ${p.warehouseUnits} unidades'), trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => editWarehouse(p)))))
      ]);

  Widget freezer() => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Freezer', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('El freezer se controla por unidades.'),
        const SizedBox(height: 12),
        ...products.map((p) => Card(child: ListTile(title: Text(p.name), subtitle: Text('${p.freezerUnits} unidades'), trailing: Text('C\$${p.price}'))))
      ]);

  Future<void> editWarehouse(Product p) async {
    final c = TextEditingController(text: p.warehouseUnits.toString());
    final value = await showDialog<int>(context: context, builder: (_) => AlertDialog(title: Text('Bodega: ${p.name}'), content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Unidades totales')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(c.text) ?? 0), child: const Text('Guardar'))]));
    c.dispose();
    if (value != null) setState(() => p.warehouseUnits = value);
  }

  Future<void> closeDay() async {
    final finalCounts = <String, int>{};
    for (final p in products) {
      final controller = TextEditingController(text: p.freezerUnits.toString());
      final result = await showDialog<int>(context: context, builder: (_) => AlertDialog(title: Text(p.name), content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '¿Cuántas unidades quedan en el freezer?')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(controller.text) ?? 0), child: const Text('Confirmar'))]));
      controller.dispose();
      if (result == null) return;
      finalCounts[p.name] = result;
    }

    int sales = 0;
    int units = 0;
    for (final p in products) {
      final sold = (p.freezerUnits - finalCounts[p.name]!).clamp(0, 100000);
      units += sold;
      sales += sold * p.price;
    }

    if (!mounted) return;
    await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Arqueo final'), content: Column(mainAxisSize: MainAxisSize.min, children: [Text('Unidades vendidas: $units'), const SizedBox(height: 8), Text('Ventas: C\$${NumberFormat('#,##0').format(sales)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 16), const Text('En la siguiente versión aquí se registrarán préstamos y consumos antes de calcular el efectivo esperado.'),]), actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Continuar a Rellenar Freezer'))]));

    if (!mounted) return;
    await refillFreezers(finalCounts);
  }

  Future<void> refillFreezers(Map<String, int> finalCounts) async {
    for (final p in products) {
      p.freezerUnits = finalCounts[p.name]!;
    }
    for (final p in products) {
      final target = p.freezerUnits;
      final controller = TextEditingController(text: '0');
      final add = await showDialog<int>(context: context, builder: (_) => AlertDialog(title: Text('Rellenar: ${p.name}'), content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Unidades a sacar de bodega', helperText: 'Freezer actual: $target unidades')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Omitir')), FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(controller.text) ?? 0), child: const Text('Agregar'))]));
      controller.dispose();
      if (add != null && add > 0) {
        setState(() { p.warehouseUnits = (p.warehouseUnits - add).clamp(0, 100000); p.freezerUnits += add; });
      }
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jornada cerrada y freezer preparado para el siguiente día.')));
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: const [Text('Historial', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('Los historiales se organizarán por mes y tendrán reportes PDF quincenales descargables en la versión de persistencia completa.')]);
}
