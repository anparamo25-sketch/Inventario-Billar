import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'extra_features.dart';

void main() => runApp(const App());
class Product{final String name;final int price,packSize;int warehouse,freezer;Product(this.name,this.price,this.packSize,{this.warehouse=0,this.freezer=0});Map<String,dynamic> j()=>{'name':name,'warehouse':warehouse,'freezer':freezer};}
class Loan{final String person,reason;final int amount;final DateTime date;Loan(this.person,this.amount,this.reason,this.date);Map<String,dynamic> j()=>{'person':person,'amount':amount,'reason':reason,'date':date.toIso8601String()};}
class Consumption{final String person,product;final int quantity,value;final DateTime date;Consumption(this.person,this.product,this.quantity,this.value,this.date);Map<String,dynamic> j()=>{'person':person,'product':product,'quantity':quantity,'value':value,'date':date.toIso8601String()};}
class Movement{final String product,type;final int units;final DateTime date;Movement(this.product,this.units,this.date,{this.type='Bodega → Freezer'});Map<String,dynamic> j()=>{'product':product,'units':units,'type':type,'date':date.toIso8601String()};}
class Day{final DateTime date;final Map<String,int> opening,finalStock,sold,refill;final List<Loan> loans;final List<Consumption> consumptions;final List<Movement> movements;final int sales,expenses,expected,actual,difference;Day({required this.date,required this.opening,required this.finalStock,required this.sold,required this.refill,required this.loans,required this.consumptions,required this.movements,required this.sales,required this.expenses,required this.expected,required this.actual,required this.difference});Map<String,dynamic> j()=>{'date':date.toIso8601String(),'opening':opening,'final':finalStock,'sold':sold,'refill':refill,'loans':loans.map((x)=>x.j()).toList(),'consumptions':consumptions.map((x)=>x.j()).toList(),'movements':movements.map((x)=>x.j()).toList(),'sales':sales,'expenses':expenses,'expected':expected,'actual':actual,'difference':difference};static Map<String,int> mp(dynamic v){final m=Map<String,dynamic>.from(v??{});return m.map((k,v)=>MapEntry(k,(v as num).toInt()));}factory Day.from(Map<String,dynamic> x)=>Day(date:DateTime.tryParse(x['date']??'')??DateTime.now(),opening:mp(x['opening']),finalStock:mp(x['final']),sold:mp(x['sold']),refill:mp(x['refill']),loans:(x['loans'] as List? ?? []).map((v)=>Loan((v['person']??'') as String,(v['amount'] as num? ?? 0).toInt(),(v['reason']??'') as String,DateTime.tryParse(v['date']??'')??DateTime.now())).toList(),consumptions:(x['consumptions'] as List? ?? []).map((v)=>Consumption((v['person']??'') as String,(v['product']??'') as String,(v['quantity'] as num? ?? 0).toInt(),(v['value'] as num? ?? 0).toInt(),DateTime.tryParse(v['date']??'')??DateTime.now())).toList(),movements:(x['movements'] as List? ?? []).map((v)=>Movement((v['product']??'') as String,(v['units'] as num? ?? 0).toInt(),DateTime.tryParse(v['date']??'')??DateTime.now(),type:(v['type']??'Bodega → Freezer') as String)).toList(),sales:(x['sales'] as num? ?? 0).toInt(),expenses:(x['expenses'] as num? ?? 0).toInt(),expected:(x['expected'] as num? ?? 0).toInt(),actual:(x['actual'] as num? ?? 0).toInt(),difference:(x['difference'] as num? ?? 0).toInt());}
final ps=<Product>[Product('Toña pequeña',46,24),Product('Litro Toña',95,12),Product('Frost litro',80,12),Product('Frost pequeña',40,24),Product('Gaseosa',25,24)];
class Store{static Future<SharedPreferences> get p=>SharedPreferences.getInstance();static Future<void> save()async{final x=await p;await x.setString('products',jsonEncode(ps.map((p)=>p.j()).toList()));await x.setString('history',jsonEncode(H.map((d)=>d.j()).toList()));await x.setString('opening',jsonEncode(opening));await x.setString('date',dayDate.toIso8601String());await x.setBool('jornadaAbierta',jornadaAbiertaGlobal);await x.setBool('initialConfigured',true);}static Future<Map<String,dynamic>> load()async{final x=await p;dynamic d(String k,dynamic f){try{return jsonDecode(x.getString(k)??jsonEncode(f));}catch(_){return f;}}return{'products':d('products',[]),'history':d('history',[]),'opening':d('opening',{}),'date':x.getString('date'),'jornadaAbierta':x.getBool('jornadaAbierta')??false,'initialConfigured':x.getBool('initialConfigured')??false};}}
final H=<Day>[];final opening=<String,int>{};DateTime dayDate=DateTime.now();bool jornadaAbiertaGlobal=false;
class App extends StatelessWidget{const App({super.key});@override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,title:'Inventario Billar',theme:ThemeData(useMaterial3:true,colorSchemeSeed:Colors.indigo),home:const Home());}
class Home extends StatefulWidget{const Home({super.key});@override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home> with WidgetsBindingObserver{int tab=0;bool loading=true,closed=false,jornadaAbierta=false,initialConfigured=false;Timer? auto;final loans=<Loan>[],cons=<Consumption>[],mov=<Movement>[];int lastSales=0,lastExpected=0;
 @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);load();auto=Timer.periodic(const Duration(seconds:15),(_)=>Store.save());}
 bool same(DateTime a,DateTime b)=>a.year==b.year&&a.month==b.month&&a.day==b.day;
 Future<void> load()async{final d=await Store.load();initialConfigured=d['initialConfigured'] as bool? ?? false;for(final v in d['products'] as List){for(final p in ps){if(p.name==v['name']){p.warehouse=(v['warehouse'] as num? ?? 0).toInt();p.freezer=(v['freezer'] as num? ?? 0).toInt();}}}H.addAll((d['history'] as List).map((v)=>Day.from(Map<String,dynamic>.from(v))));opening.addAll(Day.mp(d['opening']));dayDate=DateTime.tryParse(d['date']??'')??DateTime.now();if(opening.isEmpty){for(final p in ps)opening[p.name]=p.freezer;}if(!same(dayDate,DateTime.now())){dayDate=DateTime.now();opening..clear()..addEntries(ps.map((p)=>MapEntry(p.name,p.freezer)));jornadaAbierta=false;closed=false;await Store.save();}if(H.isNotEmpty&&same(H.last.date,dayDate)){closed=true;jornadaAbierta=false;}else{jornadaAbierta=(d['jornadaAbierta'] as bool? ?? false);closed=false;}jornadaAbiertaGlobal=jornadaAbierta;if(H.isNotEmpty){lastSales=H.last.sales;lastExpected=H.last.expected;}setState(()=>loading=false);}
 Future<void> change(VoidCallback f)async{setState(f);jornadaAbiertaGlobal=jornadaAbierta;await Store.save();}
 @override void didChangeAppLifecycleState(AppLifecycleState s){if(s==AppLifecycleState.inactive||s==AppLifecycleState.paused||s==AppLifecycleState.detached)Store.save();}
 @override void dispose(){auto?.cancel();WidgetsBinding.instance.removeObserver(this);jornadaAbiertaGlobal=jornadaAbierta;Store.save();super.dispose();}
 @override Widget build(BuildContext c){if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));if(!initialConfigured)return InitialSetupPage(products:ps,onSaved:()async{await Store.save();if(mounted)setState(()=>initialConfigured=true);});final pages=[home(),warehouse(),freezer(),History(history:H)];return Scaffold(appBar:AppBar(title:const Text('Inventario Billar')),body:pages[tab],bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const[NavigationDestination(icon:Icon(Icons.dashboard),label:'Inicio'),NavigationDestination(icon:Icon(Icons.warehouse),label:'Bodega'),NavigationDestination(icon:Icon(Icons.ac_unit),label:'Freezer'),NavigationDestination(icon:Icon(Icons.history),label:'Historial')]),floatingActionButton:jornadaAbierta&&!closed?FloatingActionButton.extended(onPressed:closeDay,icon:const Icon(Icons.lock_clock),label:const Text('Cerrar jornada')):null);}
 Widget home(){final b=ps.fold(0,(s,p)=>s+p.warehouse),f=ps.fold(0,(s,p)=>s+p.freezer);return ListView(padding:const EdgeInsets.all(16),children:[Text('Resumen de hoy',style:Theme.of(context).textTheme.headlineSmall),Text(DateFormat('dd/MM/yyyy').format(dayDate)),if(!jornadaAbierta)Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Jornada pendiente de apertura',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:8),const Text('Antes de comenzar, verifica las unidades de cada producto que deben estar en el freezer.'),const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:openDay,icon:const Icon(Icons.play_arrow),label:const Text('Abrir jornada')))]))),if(closed)Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[const Icon(Icons.check_circle),const SizedBox(width:10),Expanded(child:Text('Jornada cerrada y registrada.',style:const TextStyle(fontWeight:FontWeight.bold)))]))),Row(children:[Expanded(child:card('Bodega','$b unidades')),Expanded(child:card('Freezer','$f unidades'))]),if(jornadaAbierta)ListTile(title:const Text('Jornada abierta'),subtitle:const Text('El control de ventas y movimientos del día está activo.')),ListTile(title:const Text('Ventas último cierre'),trailing:Text('C\$$lastSales')),FilledButton.icon(onPressed:jornadaAbierta&&!closed?addLoan:null,icon:const Icon(Icons.payments),label:const Text('Registrar préstamo / retiro')),OutlinedButton.icon(onPressed:jornadaAbierta&&!closed?addConsumption:null,icon:const Icon(Icons.restaurant),label:const Text('Registrar consumo del propietario')),const SizedBox(height:12),Card(child:ListTile(leading:const Icon(Icons.inventory_2),title:const Text('Pedidos, gastos y cigarros'),subtitle:const Text('Control de pedidos, gastos, entradas por cajillas y cigarros.'),trailing:const Icon(Icons.chevron_right),onTap:openFeatureHub))]);}
 Widget card(String a,String b)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a),Text(b,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold))])));
 Widget warehouse()=>ListView(padding:const EdgeInsets.all(16),children:[const Text('Bodega',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),...ps.map((p)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p.name,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),Text('${p.warehouse~/p.packSize} cajillas + ${p.warehouse%p.packSize} unidades'),FilledButton(onPressed:closed?null:()=>move(p),child:const Text('Pasar a freezer'))]))))]);
 Widget freezer()=>ListView(padding:const EdgeInsets.all(16),children:[const Text('Freezer',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),...ps.map((p)=>Card(child:ListTile(title:Text(p.name),subtitle:Text('Actual: ${p.freezer} • Esperado al abrir: ${opening[p.name]??0}'),trailing:Text('C\$${p.price}'))))]);
 Future<void> openDay()async{final ok=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>OpenDayPage(ps,opening)));if(ok==true&&mounted){await change((){jornadaAbierta=true;closed=false;});}}
 Future<void> openFeatureHub()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>FeatureHubPage(products:ps.map((p)=>FeatureProduct(p.name,p.packSize)).toList(),onWarehouseAdd:(name,units){final p=ps.firstWhere((x)=>x.name==name);p.warehouse+=units;},onChanged:(){Store.save();setState((){});})));if(mounted)setState((){});}
 Future<void> move(Product p)async{final c=TextEditingController();final v=await showDialog<int>(context:context,builder:(_)=>AlertDialog(title:Text('Pasar ${p.name}'),content:TextField(controller:c,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'Unidades',helperText:'Disponible: ${p.warehouse}')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(context,int.tryParse(c.text)??0),child:const Text('Trasladar'))]));c.dispose();if(v==null||v<=0||v>p.warehouse)return;if(mounted)await change((){p.warehouse-=v;p.freezer+=v;mov.add(Movement(p.name,v,DateTime.now()));});}
 Future<void> addLoan()async{final a=TextEditingController(),m=TextEditingController(),r=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('Préstamo / retiro'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:a,decoration:const InputDecoration(labelText:'Persona')),TextField(controller:m,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Monto C\$')),TextField(controller:r,decoration:const InputDecoration(labelText:'Motivo'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Guardar'))]));if(ok==true&&(int.tryParse(m.text)??0)>0&&a.text.trim().isNotEmpty)await change(()=>loans.add(Loan(a.text.trim(),int.parse(m.text),r.text.trim(),DateTime.now())));a.dispose();m.dispose();r.dispose();}
 Future<void> addConsumption()async{String? sel;final who=TextEditingController(),q=TextEditingController(text:'1');final ok=await showDialog<bool>(context:context,builder:(_)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(title:const Text('Consumo del propietario'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:who,decoration:const InputDecoration(labelText:'Quién')),DropdownButtonFormField<String>(decoration:const InputDecoration(labelText:'Producto'),items:ps.map((p)=>DropdownMenuItem(value:p.name,child:Text(p.name))).toList(),onChanged:(v)=>setD(()=>sel=v)),TextField(controller:q,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Cantidad'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Guardar'))])));if(ok==true&&sel!=null){final p=ps.firstWhere((x)=>x.name==sel);final n=int.tryParse(q.text)??0;if(n>0&&n<=p.freezer&&who.text.trim().isNotEmpty)await change((){p.freezer-=n;cons.add(Consumption(who.text.trim(),p.name,n,n*p.price,DateTime.now()));});}who.dispose();q.dispose();}
 Future<void> closeDay()async{final cs={for(final p in ps)p.name:TextEditingController(text:'${p.freezer}')};final cigs=await FeatureStore.cigarettesForClose();final counts=await Navigator.push<CloseResult>(context,MaterialPageRoute(builder:(_)=>ClosePage(ps,cs,opening,cigs)));for(final c in cs.values)c.dispose();if(counts==null)return;final sold=<String,int>{};int sales=0;for(final p in ps){final n=counts.beer[p.name]!;final s=p.freezer-n;if(s<0)return;p.freezer=n;if(s>0){sold[p.name]=s;sales+=s*p.price;}}await FeatureStore.setCigaretteClosing(counts.cigarettes);final feature=await FeatureStore.summary();final lt=loans.fold(0,(s,x)=>s+x.amount),ct=cons.fold(0,(s,x)=>s+x.value);final dailySales=sales+feature.cigaretteSales;final expected=dailySales-lt-ct-feature.expensesTotal;final actual=await Navigator.push<int>(context,MaterialPageRoute(builder:(_)=>CashPage(dailySales,lt,ct,feature.expensesTotal,expected)));if(actual==null)return;final diff=actual-expected;await showDialog(context:context,barrierDismissible:false,builder:(_)=>AlertDialog(title:const Text('Arqueo final'),content:Text(diff==0?'Exacto: C\$0':diff<0?'Faltante: C\$\${diff.abs()}':'Sobrante: C\$\${diff.abs()}'),actions:[FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('Continuar'))]));final refill=await Navigator.push<Map<String,int>>(context,MaterialPageRoute(builder:(_)=>RefillPage(ps)));if(refill==null)return;final pre={for(final p in ps)p.name:p.freezer};await change((){for(final p in ps){final n=refill[p.name]??0;p.warehouse-=n;p.freezer+=n;if(n>0)mov.add(Movement(p.name,n,DateTime.now(),type:'Bodega → Freezer (Relleno)'));}H.add(Day(date:dayDate,opening:Map.from(opening),finalStock:pre,sold:sold,refill:Map.from(refill),loans:List.from(loans),consumptions:List.from(cons),movements:List.from(mov),sales:dailySales,expenses:feature.expensesTotal,expected:expected,actual:actual,difference:diff));lastSales=sales+feature.cigaretteSales;lastExpected=expected;opening..clear()..addEntries(ps.map((p)=>MapEntry(p.name,p.freezer)));loans.clear();cons.clear();mov.clear();closed=true;jornadaAbierta=false;});await PdfReport.autoGenerateIfCutoff(dayDate,List.from(H));await FeatureStore.resetDay();}
}
class InitialSetupPage extends StatefulWidget{final List<Product> products;final VoidCallback onSaved;const InitialSetupPage({super.key,required this.products,required this.onSaved});@override State<InitialSetupPage> createState()=>_InitialSetupState();}
class _InitialSetupState extends State<InitialSetupPage>{late final Map<String,TextEditingController> wh;late final Map<String,TextEditingController> fr;@override void initState(){super.initState();wh={for(final p in widget.products)p.name:TextEditingController()};fr={for(final p in widget.products)p.name:TextEditingController()};}@override void dispose(){for(final c in wh.values)c.dispose();for(final c in fr.values)c.dispose();super.dispose();}@override Widget build(BuildContext x)=>Scaffold(appBar:AppBar(title:const Text('Configuración inicial')),body:ListView(padding:const EdgeInsets.all(16),children:[const Text('Configura las existencias iniciales',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:8),const Text('Esta pantalla aparece solo la primera vez que se instala la aplicación. Registra las unidades iniciales de cada cerveza en bodega y freezer.'),const SizedBox(height:16),...widget.products.map((p)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p.name,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),TextField(controller:wh[p.name],keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Unidades iniciales en bodega')),TextField(controller:fr[p.name],keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Unidades iniciales en freezer'))])))),const SizedBox(height:12),FilledButton.icon(onPressed:()async{for(final p in widget.products){final w=int.tryParse(wh[p.name]!.text)??-1;final f=int.tryParse(fr[p.name]!.text)??-1;if(w<0||f<0)return;p.warehouse=w;p.freezer=f;opening[p.name]=f;}await Store.save();if(mounted)widget.onSaved();},icon:const Icon(Icons.save),label:const Text('Guardar configuración inicial'))]));}
class OpenDayPage extends StatefulWidget{final List<Product> products;final Map<String,int> expected;const OpenDayPage(this.products,this.expected,{super.key});@override State<OpenDayPage> createState()=>_OpenDayState();}
class _OpenDayState extends State<OpenDayPage>{final checked=<String,bool>{};@override void initState(){super.initState();for(final p in widget.products)checked[p.name]=false;}bool get allChecked=>checked.values.every((v)=>v);@override Widget build(BuildContext x)=>Scaffold(appBar:AppBar(title:const Text('Abrir jornada')),body:ListView(padding:const EdgeInsets.all(16),children:[const Text('Verificación inicial del freezer',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:8),const Text('Confirma con un check cada producto después de comprobar físicamente las unidades indicadas.'),const SizedBox(height:12),...widget.products.map((p)=>Card(child:CheckboxListTile(value:checked[p.name]??false,onChanged:(v)=>setState(()=>checked[p.name]=v??false),title:Text(p.name,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('Hay ${widget.expected[p.name]??0} unidades en freezer'),secondary:CircleAvatar(child:Text('${widget.expected[p.name]??0}'))))),const SizedBox(height:12),FilledButton.icon(onPressed:allChecked?()=>Navigator.pop(x,true):null,icon:const Icon(Icons.lock_open),label:const Text('Confirmar y abrir jornada'))]));}
class CloseResult{final Map<String,int> beer,cigarettes;CloseResult(this.beer,this.cigarettes);}
class ClosePage extends StatefulWidget{final List<Product> p;final Map<String,TextEditingController> c;final Map<String,int> o;final List<Map<String,dynamic>> cigs;const ClosePage(this.p,this.c,this.o,this.cigs,{super.key});@override State<ClosePage> createState()=>_CloseState();}
class _CloseState extends State<ClosePage>{late final Map<String,TextEditingController> cigC;@override void initState(){super.initState();cigC={for(final z in widget.cigs)z['name'].toString():TextEditingController(text:'${z['stock']??0}')};}@override void dispose(){for(final c in cigC.values)c.dispose();super.dispose();}@override Widget build(BuildContext x)=>Scaffold(appBar:AppBar(title:const Text('Cierre de jornada')),body:ListView(padding:const EdgeInsets.all(16),children:[const Text('Inventario final',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:8),...widget.p.map((z)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(z.name,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),Text('Esperado al abrir: ${widget.o[z.name]??0} • Disponible: ${z.freezer}'),TextField(controller:widget.c[z.name],keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Unidades que quedan')),ValueListenableBuilder<TextEditingValue>(valueListenable:widget.c[z.name]!,builder:(_,v,__){final n=int.tryParse(v.text)??0;final sold=(z.freezer-n).clamp(0,z.freezer);return Text('Venta calculada: $sold unidades • C\$\${sold*z.price}',style:const TextStyle(fontWeight:FontWeight.bold));})])))),if(widget.cigs.isNotEmpty)const Padding(padding:EdgeInsets.only(top:8,bottom:4),child:Text('Cigarros',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),...widget.cigs.map((z)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(z['name'].toString(),style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),Text('Existencia disponible: ${z['stock']??0}'),TextField(controller:cigC[z['name'].toString()],keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Unidades que quedan')),ValueListenableBuilder<TextEditingValue>(valueListenable:cigC[z['name'].toString()]!,builder:(_,v,__){final current=int.tryParse(v.text)??0;final opening=int.tryParse('${z['opening']??0}')??0;final entries=int.tryParse('${z['entries']??0}')??0;final sold=(opening+entries-current).clamp(0,999999);final price=int.tryParse('${z['price']??0}')??0;return Text('Venta calculada: $sold unidades • C\$${sold*price}',style:const TextStyle(fontWeight:FontWeight.bold));})})])))),FilledButton(onPressed:(){final r=<String,int>{};for(final z in widget.p){final n=int.tryParse(widget.c[z.name]!.text)??-1;if(n<0||n>z.freezer)return;r[z.name]=n;}final cr=<String,int>{};for(final z in widget.cigs){final name=z['name'].toString();final n=int.tryParse(cigC[name]!.text)??-1;final stock=int.tryParse('${z['stock']??0}')??0;if(n<0||n>stock)return;cr[name]=n;}Navigator.pop(x,CloseResult(r,cr));},child:const Text('Confirmar y continuar al arqueo'))]));}
class CashPage extends StatefulWidget{final int sales,loans,cons,adjustments,expected;const CashPage(this.sales,this.loans,this.cons,this.adjustments,this.expected,{super.key});@override State<CashPage> createState()=>_CashState();}
class _CashState extends State<CashPage>{final c=TextEditingController();@override Widget build(BuildContext x){final a=int.tryParse(c.text),d=a==null?null:a-widget.expected;return Scaffold(appBar:AppBar(title:const Text('Arqueo')),body:ListView(padding:const EdgeInsets.all(20),children:[Text('Venta total del día: C\$\${widget.sales}'),Text('Préstamos/retiros: - C\$\${widget.loans}'),Text('Consumos: - C\$\${widget.cons}'),Text('Gastos y pedidos pagados: - C\$\${widget.adjustments}'),const SizedBox(height:12),Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Efectivo esperado después de las deducciones',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold)),const SizedBox(height:6),Text('C\$\${widget.expected}',style:const TextStyle(fontSize:26,fontWeight:FontWeight.bold))])),),const SizedBox(height:12),TextField(controller:c,onChanged:(_)=>setState((){}),keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Efectivo contado',border:OutlineInputBorder())),if(d!=null)Text(d==0?'Exacto':d<0?'Faltante: C\$\${d.abs()}':'Sobrante: C\$\${d.abs()}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),FilledButton(onPressed:a==null?null:()=>Navigator.pop(x,a),child:const Text('Confirmar arqueo'))]));}}
class RefillPage extends StatelessWidget{final List<Product> p;const RefillPage(this.p,{super.key});@override Widget build(BuildContext x){final c={for(final z in p)z.name:TextEditingController(text:'0')};return Scaffold(appBar:AppBar(title:const Text('Rellenar Freezer')),body:ListView(padding:const EdgeInsets.all(16),children:[const Text('Última acción de la jornada',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),...p.map((z)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(z.name,style:const TextStyle(fontWeight:FontWeight.bold)),Text('Bodega: ${z.warehouse} • Freezer: ${z.freezer}'),TextField(controller:c[z.name],keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Unidades a sacar de bodega'))])))),FilledButton(onPressed:(){final r=<String,int>{};for(final z in p){final n=int.tryParse(c[z.name]!.text)??0;if(n<0||n>z.warehouse)return;r[z.name]=n;}Navigator.pop(x,r);},child:const Text('Confirmar y cerrar jornada'))]));}}
class History extends StatefulWidget{final List<Day> history;const History({super.key,required this.history});@override State<History> createState()=>_HistoryState();}
class _HistoryState extends State<History>{String? month;@override Widget build(BuildContext c){final all=[...widget.history]..sort((a,b)=>b.date.compareTo(a.date));final months=all.map((r)=>DateFormat('yyyy-MM').format(r.date)).toSet().toList();month??=(months.isEmpty?null:months.first);final rs=all.where((r)=>month==null||DateFormat('yyyy-MM').format(r.date)==month).toList();return ListView(padding:const EdgeInsets.all(16),children:[const Text('Historial por meses',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),if(months.isNotEmpty)DropdownButtonFormField<String>(value:month,items:months.map((m)=>DropdownMenuItem(value:m,child:Text(m))).toList(),onChanged:(v)=>setState(()=>month=v),decoration:const InputDecoration(labelText:'Mes')),if(rs.isNotEmpty) ...[FilledButton.icon(onPressed:()=>PdfReport.makeMonth(rs,month!),icon:const Icon(Icons.picture_as_pdf),label:const Text('Generar PDF del mes')),FilledButton.icon(onPressed:()=>PdfReport.makeQuincena(rs,month!,1),icon:const Icon(Icons.picture_as_pdf),label:const Text('PDF quincena 1–15')),FilledButton.icon(onPressed:()=>PdfReport.makeQuincena(rs,month!,2),icon:const Icon(Icons.picture_as_pdf),label:const Text('PDF quincena 16–fin'))],const SizedBox(height:8),...rs.map((r){final diff=r.difference==0?'Exacto':r.difference<0?'Faltante':'Sobrante';return Card(child:ExpansionTile(title:Text(DateFormat('dd/MM/yyyy').format(r.date)),subtitle:Text('Ventas C\\$'+r.sales.toString()+' • '+diff),children:[ListTile(title:const Text('Gastos'),trailing:Text('C\\$'+r.expenses.toString())),ListTile(title:const Text('Esperado'),trailing:Text('C\\$'+r.expected.toString())),ListTile(title:const Text('Contado'),trailing:Text('C\\$'+r.actual.toString())),ListTile(title:const Text('Diferencia'),trailing:Text('C\\$'+r.difference.toString())),ListTile(title:const Text('Préstamos'),trailing:Text('C\\$'+r.loans.fold(0,(s,x)=>s+x.amount).toString())),ListTile(title:const Text('Consumos'),trailing:Text('C\\$'+r.consumptions.fold(0,(s,x)=>s+x.value).toString()))]));}),if(rs.isEmpty)const Text('No hay jornadas cerradas en este mes.')]);}}
class PdfReport {
  static Future<void> makeMonth(List<Day> days, String month) async {
    final document = pw.Document();
    final first = days.where((d) => d.date.day <= 15).toList();
    final second = days.where((d) => d.date.day >= 16).toList();
    await _addPeriod(document, first, month, 1);
    await _addPeriod(document, second, month, 2);
    if (first.isEmpty && second.isEmpty) return;
    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'Inventario-Billar-' + month + '.pdf',
    );
  }

  static Future<void> makeQuincena(List<Day> days, String month, int q) async {
    final period = days.where((d) => q == 1 ? d.date.day <= 15 : d.date.day >= 16).toList();
    if (period.isEmpty) return;
    final document = pw.Document();
    await _addPeriod(document, period, month, q);
    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'Inventario-Billar-' + month + '-Q' + q.toString() + '.pdf',
    );
  }

  static Future<void> _addPeriod(
    pw.Document document,
    List<Day> period,
    String month,
    int q,
  ) async {
    if (period.isEmpty) return;

    final sorted = [...period]..sort((a, b) => a.date.compareTo(b.date));
    final firstDate = sorted.first.date;
    final lastDate = sorted.last.date;
    final start = DateTime(firstDate.year, firstDate.month, q == 1 ? 1 : 16);
    final end = q == 1
        ? DateTime(firstDate.year, firstDate.month, 16)
        : DateTime(firstDate.year, firstDate.month + 1, 1);

    final orders = await FeatureStore.ordersForPeriod(start, end);

    int paidValue(Map<String, dynamic> order) {
      final value = order['paid'];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '0') ?? 0;
    }

    DateTime? orderDate(Map<String, dynamic> order) {
      final value = order['date'];
      return DateTime.tryParse(value?.toString() ?? '');
    }

    final orderTotal = orders.fold<int>(0, (sum, order) => sum + paidValue(order));
    final sales = sorted.fold<int>(0, (sum, d) => sum + d.sales);
    final expenses = sorted.fold<int>(0, (sum, d) => sum + d.expenses);
    final consumptions = sorted.fold<int>(
      0,
      (sum, d) => sum + d.consumptions.fold<int>(0, (s, x) => s + x.value),
    );
    final loans = sorted.fold<int>(
      0,
      (sum, d) => sum + d.loans.fold<int>(0, (s, x) => s + x.amount),
    );
    final distributable = sales - orderTotal;
    final share = distributable ~/ 5;

    final rows = sorted.map((d) {
      final dayStart = DateTime(d.date.year, d.date.month, d.date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final dailyOrders = orders.where((order) {
        final date = orderDate(order);
        return date != null && !date.isBefore(dayStart) && date.isBefore(dayEnd);
      }).fold<int>(0, (sum, order) => sum + paidValue(order));

      final dayConsumptions = d.consumptions.fold<int>(0, (sum, x) => sum + x.value);
      final dayLoans = d.loans.fold<int>(0, (sum, x) => sum + x.amount);

      return <String>[
        DateFormat('dd/MM/yyyy').format(d.date),
        'C\$' + d.sales.toString(),
        'C\$' + d.expenses.toString(),
        'C\$' + dailyOrders.toString(),
        'C\$' + dayConsumptions.toString(),
        'C\$' + dayLoans.toString(),
      ];
    }).toList();

    final periodLabel = q == 1 ? 'Días 1-15' : 'Días 16-fin';
    final dateLabel =
        'Período: ' +
        DateFormat('dd/MM/yyyy').format(start) +
        ' al ' +
        DateFormat('dd/MM/yyyy').format(lastDate);

    document.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Header(
            level: 0,
            child: pw.Text('Inventario Billar - Corte quincenal'),
          ),
          pw.Text('Mes ' + month + ' - ' + periodLabel),
          pw.Text(dateLabel),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: [
              'Fecha',
              'Ventas',
              'Gastos',
              'Pedidos',
              'Consumos',
              'Préstamos',
            ],
            data: rows,
          ),
          pw.SizedBox(height: 14),
          pw.Text('Ventas totales: C\$' + sales.toString()),
          pw.Text('Gastos totales: C\$' + expenses.toString()),
          pw.Text('Consumos totales: C\$' + consumptions.toString()),
          pw.Text('Préstamos totales: C\$' + loans.toString()),
          pw.SizedBox(height: 8),
          pw.Text(
            'Pedidos pagados de la quincena: C\$' + orderTotal.toString(),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Total después de deducir pedidos: C\$' + distributable.toString(),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Distribución entre 5 socios: C\$' + share.toString() + ' por socio',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static Future<void> autoGenerateIfCutoff(DateTime date, List<Day> days) async {
    final lastDay = DateTime(date.year, date.month + 1, 0).day;
    int q = 0;
    if (date.day == 15) {
      q = 1;
    } else if (date.day == lastDay) {
      q = 2;
    }
    if (q == 0) return;

    final month = DateFormat('yyyy-MM').format(date);
    final period = days.where((d) {
      return q == 1 ? d.date.day <= 15 : d.date.day >= 16;
    }).toList();

    if (period.isNotEmpty) {
      await makeQuincena(period, month, q);
    }
  }
}
