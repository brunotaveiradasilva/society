import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/checkin_screen.dart';
import 'screens/draw_screen.dart';
import 'screens/futs_screen.dart';
import 'screens/list_screen.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(SocietyApp(store: FutStore(prefs)));
}

class SocietyApp extends StatelessWidget {
  const SocietyApp({super.key, required this.store});
  final FutStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Society',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      themeMode: ThemeMode.light,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: FutsScreen(store: store),
    );
  }
}

/// Um fut aberto: abas Lista, Sorteio e Chamada.
class FutScreen extends StatefulWidget {
  const FutScreen({super.key, required this.fut});
  final Fut fut;

  @override
  State<FutScreen> createState() => _FutScreenState();
}

class _FutScreenState extends State<FutScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final fut = widget.fut;
    return ListenableBuilder(
      listenable: fut,
      builder: (context, _) {
        final pages = [
          ListScreen(state: fut),
          DrawScreen(state: fut),
          CheckinScreen(state: fut),
        ];
        return Scaffold(
          body: IndexedStack(index: _tab, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.list_alt_outlined),
                selectedIcon: const Icon(Icons.list_alt),
                label: 'Lista (${fut.players.length})',
              ),
              const NavigationDestination(
                icon: Icon(Icons.shuffle_outlined),
                selectedIcon: Icon(Icons.shuffle),
                label: 'Sorteio',
              ),
              const NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check),
                label: 'Chamada',
              ),
            ],
          ),
        );
      },
    );
  }
}
