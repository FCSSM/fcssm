import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/planning_service.dart';
import 'planning_page.dart';
import 'impression_page.dart';
import 'planning_entrainement_page.dart';
import 'planning_equipes.dart';
import 'administration_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (!mounted) return;
      setState(() {
        isAdmin = user != null;
      });
    });
    PlanningService.demarrerSurveillancePlanning();
  }

  void _adminConnecte() {
    setState(() {
      isAdmin = true;
      index = 0;
    });
  }

  @override

  Widget build(BuildContext context) {
    final pages = [
      PlanningPage(
        onAdminConnecte: _adminConnecte,
      ),
      const PlanningEquipes(),
      const PlanningEntrainementPage(),
      const ImpressionPage(),
    ];

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.calendar_month),
        label: "Matchs",
      ),

      const NavigationDestination(
        icon: Icon(Icons.groups),
        label: "Équipes",
      ),

      const NavigationDestination(
        icon: Icon(Icons.calendar_month),
        label: "Entraînements",
      ),

      const NavigationDestination(
        icon: Icon(Icons.print),
        label: "Impression",
      ),

      // Administration uniquement pour les administrateurs
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings),
          label: "Admin.",
          tooltip: "Administration",
        ),
    ];


    return Scaffold(
      body: pages[
      index < pages.length ? index : 0
      ],

      bottomNavigationBar: NavigationBar(
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11,
          ),
        ),

        selectedIndex: index,

        onDestinationSelected: (value) {
          if (isAdmin && value == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdministrationPage(),
              ),
            );
            return;
          }

          setState(() {
            index = value;
          });
        },

        destinations: destinations,
      ),
    );
  }
}