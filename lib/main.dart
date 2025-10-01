
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuoteBotApp());
}

class QuoteBotApp extends StatelessWidget {
  const QuoteBotApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuoteBot',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFCC00), brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final pages = const [HomePage(), QuotePage(), CustomersPage(), BusinessPage()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QuoteBot')),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: "Home"),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: "Quote"),
          NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt), label: "Customers"),
          NavigationDestination(icon: Icon(Icons.business_outlined), selectedIcon: Icon(Icons.business), label: "Business"),
        ],
        onDestinationSelected: (i)=> setState(()=> index = i),
      ),
      body: pages[index],
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
              onPressed: ()=> Navigator.of(context).push(MaterialPageRoute(builder: (_)=> const QuotePage())),
              child: const Text("New Quote"),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: ()=> Navigator.of(context).push(MaterialPageRoute(builder: (_)=> const CustomersPage())),
              child: const Text("Customers"),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: ()=> Navigator.of(context).push(MaterialPageRoute(builder: (_)=> const BusinessPage())),
              child: const Text("Business Profile"),
            ),
          ],
        ),
      ),
    );
  }
}

// Models & storage
class LineItem {
  final String service;
  final double price;
  LineItem(this.service, this.price);
  Map<String,dynamic> toJson()=> {'service':service,'price':price};
  static LineItem fromJson(Map<String,dynamic> j)=> LineItem(j['service']??'', (j['price']??0).toDouble());
}

class Customer {
  final String id;
  final String name;
  Customer(this.id, this.name);
  Map<String,dynamic> toJson()=> {'id':id,'name':name};
  static Customer fromJson(Map<String,dynamic> j)=> Customer(j['id']??'', j['name']??'');
}

class Business {
  String name;
  String phone;
  String email;
  Business({this.name='', this.phone='', this.email=''});
  Map<String,dynamic> toJson()=> {'name':name,'phone':phone,'email':email};
  static Business fromJson(Map<String,dynamic> j)=> Business(name: j['name']??'', phone: j['phone']??'', email: j['email']??'');
}

class Store {
  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static Future<void> saveItems(List<LineItem> items) async {
    final p = await _prefs();
    p.setString('items', jsonEncode(items.map((e)=> e.toJson()).toList()));
  }
  static Future<List<LineItem>> loadItems() async {
    final p = await _prefs();
    final s = p.getString('items');
    if (s==null) return [];
    final arr = jsonDecode(s) as List;
    return arr.map((e)=> LineItem.fromJson(e)).toList();
  }

  static Future<void> saveCustomers(List<Customer> items) async {
    final p = await _prefs();
    p.setString('customers', jsonEncode(items.map((e)=> e.toJson()).toList()));
  }
  static Future<List<Customer>> loadCustomers() async {
    final p = await _prefs();
    final s = p.getString('customers');
    if (s==null) return [];
    final arr = jsonDecode(s) as List;
    return arr.map((e)=> Customer.fromJson(e)).toList();
  }

  static Future<void> saveBusiness(Business b) async {
    final p = await _prefs();
    p.setString('business', jsonEncode(b.toJson()));
  }
  static Future<Business> loadBusiness() async {
    final p = await _prefs();
    final s = p.getString('business');
    if (s==null) return Business();
    return Business.fromJson(jsonDecode(s));
  }

  static Future<void> saveSelectedCustomer(String? id) async {
    final p = await _prefs();
    if (id==null) { p.remove('selected'); return; }
    p.setString('selected', id);
  }
  static Future<String?> loadSelectedCustomer() async {
    final p = await _prefs();
    return p.getString('selected');
  }
}

class QuotePage extends StatefulWidget {
  const QuotePage({super.key});
  @override
  State<QuotePage> createState() => _QuotePageState();
}
class _QuotePageState extends State<QuotePage> {
  final serviceCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  List<LineItem> items = [];
  Customer? selectedCustomer;
  Business biz = Business();

  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final loaded = await Store.loadItems();
    final customers = await Store.loadCustomers();
    final bizx = await Store.loadBusiness();
    final selId = await Store.loadSelectedCustomer();
    setState(() {
      items = loaded;
      biz = bizx;
      selectedCustomer = customers.where((c)=> c.id==selId).cast<Customer?>().firstOrNull;
    });
  }

  void addItem() {
    final s = serviceCtrl.text.trim();
    final p = double.tryParse(priceCtrl.text.trim());
    if (s.isEmpty || p==null) return;
    setState(() {
      items.add(LineItem(s, p));
      serviceCtrl.clear(); priceCtrl.clear();
    });
    Store.saveItems(items);
  }

  double get total => items.fold(0.0, (sum, i)=> sum + i.price);

  Future<void> exportPdf() async {
    final doc = pw.Document();
    final df = DateFormat.yMd();
    doc.addPage(
      pw.Page(
        build: (ctx) {
          return pw.Container(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  color: PdfColor.fromHex("#0b0f1a"),
                  padding: const pw.EdgeInsets.all(14),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text("QuoteBot", style: pw.TextStyle(color: PdfColor.fromInt(0xffffffff), fontWeight: pw.FontWeight.bold, fontSize: 18)),
                        pw.SizedBox(height: 2),
                        pw.Text("${biz.name} · ${biz.phone} · ${biz.email}", style: pw.TextStyle(color: PdfColor.fromHex("#aab2d6"), fontSize: 10))
                      ]),
                      pw.Text("QUOTE", style: pw.TextStyle(color: PdfColor.fromInt(0xffffffff), fontWeight: pw.FontWeight.bold))
                    ]
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Customer: ${selectedCustomer?.name ?? "-"}"),
                      pw.Text("Date: ${df.format(DateTime.now())}")
                    ]
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.symmetric(inside: pw.BorderSide(color: PdfColor.fromHex("#e8ecf7"))),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex("#f1f4ff")),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text("Service")),
                        pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Price"))),
                      ]
                    ),
                    ...items.map((i)=> pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text(i.service)),
                      pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("\$${i.price.toStringAsFixed(2)}"))),
                    ]))
                  ]
                ),
                pw.SizedBox(height: 10),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("Prepared with QuoteBot", style: pw.TextStyle(color: PdfColor.fromHex("#223056"), fontSize: 10)),
                      pw.Text("Total: \$${total.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ]
                  ),
                )
              ]
            ),
          );
        }
      )
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Build Quote", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: serviceCtrl, decoration: const InputDecoration(hintText: "Service (e.g., Outlet install)"))),
            const SizedBox(width: 8),
            SizedBox(width: 140, child: TextField(controller: priceCtrl, decoration: const InputDecoration(hintText: "Price"), keyboardType: TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 8),
            FilledButton(onPressed: addItem, child: const Text("Add"))
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __)=> const Divider(height: 1),
              itemBuilder: (_, i){
                final it = items[i];
                return ListTile(
                  title: Text(it.service),
                  trailing: Text("\$${it.price.toStringAsFixed(2)}"),
                );
              }
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Total", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            Text("\$${total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: exportPdf, icon: const Icon(Icons.picture_as_pdf), label: const Text("Export PDF"))
        ],
      ),
    );
  }
}

extension FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}
class _CustomersPageState extends State<CustomersPage> {
  List<Customer> customers = [];
  String query = "";
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    customers = await Store.loadCustomers();
    setState(()=>{});
  }

  void addCustomer() async {
    final controller = TextEditingController();
    final ok = await showDialog<String>(context: context, builder: (ctx){
      return AlertDialog(
        title: const Text("New Customer"),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: "Customer name")),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(onPressed: ()=> Navigator.pop(ctx, controller.text.trim()), child: const Text("Add"))
        ],
      );
    });
    if (ok==null || ok.isEmpty) return;
    final c = Customer(DateTime.now().millisecondsSinceEpoch.toString(), ok);
    setState(()=> customers.insert(0, c));
    await Store.saveCustomers(customers);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = customers.where((c)=> c.name.toLowerCase().contains(query.toLowerCase())).toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: TextField(decoration: const InputDecoration(hintText: "Search"), onChanged: (v)=> setState(()=> query=v))),
            const SizedBox(width: 8),
            FilledButton(onPressed: addCustomer, child: const Text("Add"))
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __)=> const Divider(height: 1),
              itemBuilder: (_, i){
                final it = filtered[i];
                return ListTile(
                  title: Text(it.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Store.saveSelectedCustomer(it.id);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Selected ${it.name}")));
                  },
                );
              }
            ),
          )
        ],
      ),
    );
  }
}

class BusinessPage extends StatefulWidget {
  const BusinessPage({super.key});
  @override
  State<BusinessPage> createState() => _BusinessPageState();
}
class _BusinessPageState extends State<BusinessPage> {
  Business biz = Business();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    biz = await Store.loadBusiness();
    nameCtrl.text = biz.name; phoneCtrl.text = biz.phone; emailCtrl.text = biz.email;
    setState(()=>{});
  }

  Future<void> save() async {
    biz = Business(name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim(), email: emailCtrl.text.trim());
    await Store.saveBusiness(biz);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved")));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: "Business name")),
          const SizedBox(height: 8),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(hintText: "Phone"), keyboardType: TextInputType.phone),
          const SizedBox(height: 8),
          TextField(controller: emailCtrl, decoration: const InputDecoration(hintText: "Email"), keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          FilledButton(onPressed: save, child: const Text("Save"))
        ],
      ),
    );
  }
}
