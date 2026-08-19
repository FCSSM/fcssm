import 'package:flutter/material.dart';
import 'planning_page.dart';
import 'impression_page.dart';
import 'planning_entrainement_page.dart';
import 'administration_page.dart';
import '../services/admin_service.dart';

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
    _chargerIsAdmin();
  }

  Future<void> _chargerIsAdmin() async {
    final admin = await AdminService.isAdmin();

    if (!mounted) return;

    setState(() {
      isAdmin = admin;
    });
  }

  void _adminConnecte() {
    setState(() {
      isAdmin = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      PlanningPage(
        onAdminConnecte: _adminConnecte,
      ),
      const PlanningEntrainementPage(),
      const ImpressionPage(),
    ];

    return Scaffold(
      body: pages[index],

      bottomNavigationBar: NavigationBar(
        selectedIndex: index,

        onDestinationSelected: (value) {
          // Administration = destination 3
          if (value == 3) {
            if (!isAdmin) {
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                const AdministrationPage(),
              ),
            );

            return;
          }

          setState(() {
            index = value;
          });
        },

        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: "Matchs",
          ),

          const NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: "Entraînements",
          ),

          const NavigationDestination(
            icon: Icon(Icons.print),
            label: "Impression",
          ),

          NavigationDestination(
            icon: const Icon(
              Icons.admin_panel_settings,
            ),
            label: "Administration",
            tooltip: "Administration",
            enabled: isAdmin,
          ),
        ],
      ),
    );
  }
}