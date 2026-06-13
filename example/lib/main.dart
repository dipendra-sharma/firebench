import 'package:firebase_core/firebase_core.dart';
import 'package:firebench/firebench.dart';
import 'package:flutter/material.dart';

String? friendlyRouteName(RouteSettings settings) => switch (settings.name) {
  '/' => 'home',
  '/details' => 'details',
  '/catalog' => 'catalog',
  '/nested' => 'nested_host',
  _ => settings.name,
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Firebench.init(
    config: const FirebenchConfig(
      enableTtfd: true,
      ignoreRoutes: {'home'},
      routeNameExtractor: friendlyRouteName,
    ),
  );
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [FirebenchNavigatorObserver()],
      routes: {
        '/': (_) => const HomeScreen(),
        '/details': (_) => const DetailsScreen(),
        '/catalog': (_) => const CatalogScreen(),
        '/nested': (_) => const NestedHostScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _NavButton(route: '/details', label: 'Details (manual TTFD + attrs)'),
            SizedBox(height: 12),
            _NavButton(route: '/catalog', label: 'Catalog (display widget + trace)'),
            SizedBox(height: 12),
            _NavButton(route: '/nested', label: 'Nested navigator'),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.route, required this.label});

  final String route;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => Navigator.of(context).pushNamed(route),
      child: Text(label),
    );
  }
}

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({super.key});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  late final FirebenchDisplay? _display;

  @override
  void initState() {
    super.initState();
    _display = Firebench.instance.currentDisplay();
    _display?.putAttribute('opened_from', 'home');
    _display?.setMetric('retry_count', 0);
    _loadData();
  }

  Future<void> _loadData() async {
    await Firebench.instance.trace('load_details', () async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    if (mounted) _display?.reportFullyDisplayed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: const Center(child: Text('Loaded')),
    );
  }
}

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FirebenchDisplayWidget(child: _CatalogBody());
  }
}

class _CatalogBody extends StatefulWidget {
  const _CatalogBody();

  @override
  State<_CatalogBody> createState() => _CatalogBodyState();
}

class _CatalogBodyState extends State<_CatalogBody> {
  FirebenchDisplay? _display;
  List<String> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _display = FirebenchDisplayWidget.of(context);
  }

  Future<void> _load() async {
    final items = await Firebench.instance.trace('load_catalog', _fetchItems);
    if (!mounted) return;
    setState(() => _items = items);
    _display?.setMetric('item_count', items.length);
    _display?.reportFullyDisplayed();
  }

  Future<List<String>> _fetchItems() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return const ['Keyboard', 'Mouse', 'Monitor', 'Webcam'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalog')),
      body: _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _items.length,
              itemExtent: 64,
              itemBuilder: (context, index) =>
                  _CatalogItem(name: _items[index], position: index),
            ),
    );
  }
}

class _CatalogItem extends StatelessWidget {
  const _CatalogItem({required this.name, required this.position});

  final String name;
  final int position;

  Future<void> _addToCart() async {
    final trace = Firebench.instance.startTrace('add_to_cart');
    trace.putAttribute('item', name);
    trace.setMetric('position', position);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await trace.stop();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name),
      trailing: IconButton(
        icon: const Icon(Icons.add_shopping_cart),
        onPressed: _addToCart,
      ),
    );
  }
}

class NestedHostScreen extends StatelessWidget {
  const NestedHostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nested host')),
      body: Navigator(
        initialRoute: 'inner_a',
        observers: [FirebenchNavigatorObserver()],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              settings.name == 'inner_b' ? const _InnerB() : const _InnerA(),
        ),
      ),
    );
  }
}

class _InnerA extends StatelessWidget {
  const _InnerA();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pushNamed('inner_b'),
        child: const Text('Push inner B'),
      ),
    );
  }
}

class _InnerB extends StatelessWidget {
  const _InnerB();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Pop inner B'),
      ),
    );
  }
}
