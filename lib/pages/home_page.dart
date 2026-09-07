import 'package:flutter/material.dart';

import '../models/utilisateur.dart';
import '../services/planning_service.dart';
import '../services/auth_service.dart';

import 'planning_page.dart';
import 'impression_page.dart';
import 'planning_entrainement_page.dart';
import 'planning_equipes.dart';
import 'administration_page.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  final AuthService _authService = AuthService();
  Utilisateur? utilisateurConnecte;

  // ---------------------------------------------------------------------------
  // INITIALISATION
  // ---------------------------------------------------------------------------



  // ---------------------------------------------------------------------------
  // CHARGER L'UTILISATEUR DÉJÀ CONNECTÉ
  // ---------------------------------------------------------------------------

  Future<void> _chargerUtilisateurConnecte() async {
    final utilisateur =
    await _authService.utilisateurConnecte();

    if (!mounted) return;

    setState(() {
      utilisateurConnecte = utilisateur;
    });
  }

  // ---------------------------------------------------------------------------
  // CONNEXION
  // ---------------------------------------------------------------------------

  Future<void> _ouvrirConnexion() async {
    final Utilisateur? utilisateur = await Navigator.push<Utilisateur>(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );

    if (utilisateur == null) {
      return;
    }

    if (!mounted) return;

    setState(() {
      utilisateurConnecte = utilisateur;
      index = 0;
    });
  }

  // ---------------------------------------------------------------------------
  // DÉCONNEXION
  // ---------------------------------------------------------------------------

  Future<void> _deconnecter() async {
    await _authService.deconnecter();

    if (!mounted) return;

    setState(() {
      utilisateurConnecte = null;
      index = 0;
    });
  }

  @override
  void initState() {
    super.initState();

    _chargerUtilisateurConnecte();

    PlanningService.demarrerSurveillancePlanning();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool estAdmin = utilisateurConnecte?.estAdmin ?? false;

    final bool peutGererMatchs = utilisateurConnecte?.peutGererMatchs ?? false;

    final pages = [
      PlanningPage(
        onAdminConnecte: () {},
        peutGererMatchs: peutGererMatchs,
        utilisateurConnecte: utilisateurConnecte,
        onConnexion: _ouvrirConnexion,
        onDeconnexion: _deconnecter,
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

      const NavigationDestination(icon: Icon(Icons.groups), label: "Équipes"),

      const NavigationDestination(
        icon: Icon(Icons.calendar_month),
        label: "Entraînements",
      ),

      const NavigationDestination(icon: Icon(Icons.print), label: "Impression"),

      // ---------------------------------------------------------------
      // ADMINISTRATION UNIQUEMENT ADMIN
      // ---------------------------------------------------------------
      if (estAdmin)
        const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings),
          label: "Admin.",
          tooltip: "Administration",
        ),
    ];

    return Scaffold(

      body: pages[index < pages.length ? index : 0],

      bottomNavigationBar: NavigationBar(
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),


        selectedIndex: index,

        onDestinationSelected: (value) {
          // -------------------------------------------------------------
          // ADMINISTRATION
          // -------------------------------------------------------------

          if (estAdmin && value == 4) {
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
