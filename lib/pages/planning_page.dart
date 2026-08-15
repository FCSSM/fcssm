import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:week_number/iso.dart';

import '../models/match.dart';
import '../services/planning_service.dart';

class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  List<Match> matchsSemaine = [];

  // Date actuellement sélectionnée
  DateTime dateSelectionnee = DateTime.now();
  // Semaine affichée
  int semaineSelectionnee = DateTime.now().weekNumber;

  bool uniquementDomicile = false;

  String formatDate(DateTime date) {
    const jours = [
      "Lundi",
      "Mardi",
      "Mercredi",
      "Jeudi",
      "Vendredi",
      "Samedi",
      "Dimanche",
    ];

    const mois = [
      "janvier",
      "février",
      "mars",
      "avril",
      "mai",
      "juin",
      "juillet",
      "août",
      "septembre",
      "octobre",
      "novembre",
      "décembre",
    ];

    return "${jours[date.weekday - 1]} "
        "${date.day} "
        "${mois[date.month - 1]}";
  }



  Color couleurMatch(String couleurMatch) {
    switch (couleurMatch) {
      case "jaune":
        return Colors.yellow.shade200;

      case "rouge":
        return Colors.red.shade200;

      default:
        return Colors.grey.shade200;
    }
  }

  @override
  void initState() {
    super.initState();

    // Au démarrage :
    // on affiche automatiquement la semaine actuelle
    chargerPlanning(semaineSelectionnee);
  }

  int numeroSemaine(DateTime date) {
    final jeudi = date.add(
      Duration(days: DateTime.thursday - date.weekday),
    );

    final debutAnnee = DateTime(jeudi.year, 1, 4);

    final lundiSemaine1 = debutAnnee.subtract(
      Duration(days: debutAnnee.weekday - DateTime.monday),
    );

    return (jeudi.difference(lundiSemaine1).inDays ~/ 7) + 1;
  }

  Future<void> choisirDate() async {
    final DateTime? dateChoisie = await showDatePicker(
      context: context,
      initialDate: dateSelectionnee,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('fr', 'FR'),
    );

    if (dateChoisie == null) {
      return;
    }

    final int semaine = numeroSemaine(dateChoisie);
    // final int semaine = 33;
    setState(() {
      dateSelectionnee = dateChoisie;
      semaineSelectionnee = semaine;
    });

    chargerPlanning(semaine);
  }

  Future<void> chargerPlanning(int semaine) async {
    try {
      final String jsonString =
      await PlanningService.loadPlanning();

      final List<Match> tousLesMatchs =
      (jsonDecode(jsonString) as List)
          .cast<Map<String, dynamic>>()
          .map(Match.fromJson)
          .toList();

      setState(() {
        matchsSemaine = tousLesMatchs.where((match) {
          // Filtre sur la semaine
          if (match.noSemaine != semaine) {
            return false;
          }

          // Filtre domicile
          if (uniquementDomicile && !match.estDomicile) {
            return false;
          }

          return true;
        }).toList();

        matchsSemaine.sort((a, b) {
          final cmp = a.date.compareTo(b.date);

          if (cmp != 0) {
            return cmp;
          }

          return a.heureEnMinutes.compareTo(b.heureEnMinutes);
        });
      });
    } catch (e, stackTrace) {
      debugPrint('Erreur lors du chargement du planning : $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Image.asset(
            'assets/images/logo_club.png',
            fit: BoxFit.contain,
          ),
        ),

        title: Text(
          "Planning - Semaine $semaineSelectionnee",
          overflow: TextOverflow.ellipsis,
        ),

        // Deuxième ligne
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(55),
          child: SizedBox(
            height: 55,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  uniquementDomicile
                      ? "🏠 Domicile"
                      : "🏠 Tous",
                ),

                Switch(
                  value: uniquementDomicile,
                  onChanged: (value) {
                    setState(() {
                      uniquementDomicile = value;
                    });
                    chargerPlanning(semaineSelectionnee);
                  },
                ),

                const SizedBox(width: 20),

                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  tooltip: "Choisir une date",
                  onPressed: choisirDate,
                ),

                const Text("Choisir une date"),
              ],
            ),
          ),
        ),
      ),
      body: matchsSemaine.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_soccer,
              size: 64,
              color: Colors.blue,
            ),
            SizedBox(height: 16),
            Text(
              "Aucun match cette semaine",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Profitez-en pour vous reposer ! 😊",
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      )
          :  ListView.builder(
        itemCount: matchsSemaine.length,
        itemBuilder: (context, index) {
          final match = matchsSemaine[index];

          final bool afficherDate = index == 0 ||
              match.date != matchsSemaine[index - 1].date;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (afficherDate)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    8,
                  ),
                  child: Text(
                    formatDate(match.date),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              Card(
                color: couleurMatch(match.couleur),
                margin: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: ListTile(
                  leading: Text(
                    match.heureMatch,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  title: Text(
                    "${match.equipeLocale} - "
                        "${match.equipeAdverse}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    "${match.stade} - ${match.ville}",
                  ),
                  trailing: Text(
                    match.competition,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}