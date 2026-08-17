import 'package:flutter/material.dart';
import 'planning_page.dart';
import 'impression_page.dart';
import 'planning_entrainement_page.dart';
import 'administration_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  int index = 0;

  final pages = const [
    PlanningPage(),
    PlanningEntrainementPage(),
    ImpressionPage(),
  ];


  // Mot de passe administrateur
  // Temporaire pour le moment.
  static const String adminPassword = '1234';

  Future<void> ouvrirAdministration() async {
    final motDePasse = await showDialog<String>(
      context: context,
      builder: (context) {
        return const _AdministrationDialog();
      },
    );

    if (!mounted) return;

    if (motDePasse == adminPassword) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AdministrationPage(),
        ),
      );
    } else if (motDePasse != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mot de passe incorrect'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: pages[index],

      bottomNavigationBar: NavigationBar(

        selectedIndex: index,

        onDestinationSelected: (value) {
         // Administration = destination 3
          if (value == 3) {
            ouvrirAdministration();
            return;
          }

          setState(() {
            index = value;
          });
        },

        destinations: const [

          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: "Matchs",
          ),

          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: "Entraînements",
          ),

          NavigationDestination(
            icon: Icon(Icons.print),
            label: "Impression",
          ),

          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings),
            label: "Administration",
            tooltip: "Administration",
          ),


        ],
      ),
    );
  }
}

class _AdministrationDialog extends StatefulWidget {
  const _AdministrationDialog();

  @override
  State<_AdministrationDialog> createState() =>
      _AdministrationDialogState();
}

class _AdministrationDialogState extends State<_AdministrationDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void valider() {
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Administration'),
      content: TextField(
        controller: _controller,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Mot de passe',
          prefixIcon: Icon(Icons.lock),
        ),
        onSubmitted: (_) => valider(),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: valider,
          child: const Text('Valider'),
        ),
      ],
    );
  }
}