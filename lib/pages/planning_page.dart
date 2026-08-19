import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:week_number/iso.dart';

import '../models/match.dart' ;
import '../models/terrain.dart';
import '../services/terrain_service.dart';
import '../services/planning_service.dart';
import 'admin_login_page.dart';
import '../services/admin_service.dart';


class PlanningPage extends StatefulWidget {
  final VoidCallback? onAdminConnecte;

  const PlanningPage({
    super.key,
    this.onAdminConnecte
  });

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}


class _PlanningPageState extends State<PlanningPage> {

  bool isAdmin = false;

  /// Tous les matchs provenant du JSON
  List<MatchFoot> tousLesMatchs = [];

  /// Matchs actuellement affichés
  List<MatchFoot> matchsSemaine = [];

  // Date actuellement sélectionnée
  DateTime dateSelectionnee = DateTime.now();

  // Semaine affichée
  int semaineSelectionnee = DateTime
      .now()
      .weekNumber;

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
    _chargerIsAdmin();
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

    return (jeudi
        .difference(lundiSemaine1)
        .inDays ~/ 7) + 1;
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

  DateTime _parseDateFrancaise(String date) {
    final morceaux = date.split('/');

    if (morceaux.length != 3) {
      throw FormatException(
        'Date invalide : $date',
      );
    }

    final jour = int.parse(morceaux[0]);
    final mois = int.parse(morceaux[1]);
    final annee = int.parse(morceaux[2]);

    return DateTime(
      annee,
      mois,
      jour,
    );
  }

  Future<void> chargerPlanning(int semaine) async {
    try {
      final String jsonString =
      await PlanningService.loadPlanning();

      final List<MatchFoot> listeMatchs =
      (jsonDecode(jsonString) as List)
          .cast<Map<String, dynamic>>()
          .map(MatchFoot.fromJson)
          .toList();

      setState(() {
        // ---------------------------------------------
        // On conserve TOUS les matchs
        // ---------------------------------------------
        tousLesMatchs = listeMatchs;

        // ---------------------------------------------
        // On construit uniquement la liste affichée
        // ---------------------------------------------
        matchsSemaine = tousLesMatchs.where((listeMatchs) {
          // Filtre sur la semaine
          if (listeMatchs.noSemaine != semaine) {
            return false;
          }

          // Filtre domicile
          if (uniquementDomicile && !listeMatchs.estDomicile) {
            return false;
          }

          return true;
        }).toList();

        // ---------------------------------------------
        // Tri de la liste affichée
        // ---------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Demander le token GitHub
  // ---------------------------------------------------------------------------

  Future<String?> demanderTokenGitHub() {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mise à jour GitHub'),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Token GitHub',
              hintText: 'github_pat_...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final token = controller.text.trim();

                if (token.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(token);
              },
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Mettre à jour'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _modifierMatch(MatchFoot match) async {
    // ============================================================
    // CONTRÔLEUR HEURE
    // ============================================================

    final heureController = TextEditingController(
      text: match.heureMatch,
    );

    try {
      // ============================================================
      // DATE ACTUELLE
      // ============================================================

      DateTime dateSelectionnee =
      _parseDateFrancaise(match.dateMatch);

      // ============================================================
      // CHARGEMENT DES TERRAINS
      // ============================================================

      final terrains =
      await TerrainService.chargerTerrains();

      if (!mounted) {
        return;
      }

      // ============================================================
      // TERRAIN ACTUEL
      // ============================================================

      String? terrainSelectionne;

      for (final terrain in terrains) {
        if (terrain.nom == match.stade) {
          terrainSelectionne = terrain.id;
          break;
        }
      }

      // ============================================================
      // DIALOGUE
      // ============================================================

      final resultat = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
                dialogContext,
                setDialogState,
                ) {
              return AlertDialog(
                title: const Text(
                  'Modifier le match',
                ),

                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // ==================================================
                      // DATE
                      // ==================================================

                      InkWell(
                        onTap: () async {
                          final date =
                          await showDatePicker(
                            context: dialogContext,
                            initialDate:
                            dateSelectionnee,
                            firstDate:
                            DateTime(2020),
                            lastDate:
                            DateTime(2100),
                            locale:
                            const Locale(
                              'fr',
                              'FR',
                            ),
                          );

                          if (date != null) {
                            setDialogState(() {
                              dateSelectionnee =
                                  date;
                            });
                          }
                        },

                        child: InputDecorator(
                          decoration:
                          const InputDecoration(
                            labelText: 'Date',
                            border:
                            OutlineInputBorder(),
                            suffixIcon: Icon(
                              Icons.calendar_month,
                            ),
                          ),

                          child: Text(
                            '${dateSelectionnee.day.toString().padLeft(2, '0')}/'
                                '${dateSelectionnee.month.toString().padLeft(2, '0')}/'
                                '${dateSelectionnee.year}',
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ==================================================
                      // HEURE
                      // ==================================================

                      TextField(
                        controller:
                        heureController,

                        keyboardType:
                        TextInputType.datetime,

                        decoration:
                        const InputDecoration(
                          labelText: 'Heure',
                          hintText: '20:00',
                          border:
                          OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ==================================================
                      // TERRAIN
                      // ==================================================

                      DropdownButtonFormField<String>(
                        initialValue:
                        terrainSelectionne,

                        decoration:
                        const InputDecoration(
                          labelText: 'Terrain',
                          border:
                          OutlineInputBorder(),
                        ),

                        items: terrains
                            .map(
                              (terrain) {
                            return DropdownMenuItem<
                                String>(
                              value: terrain.id,
                              child:
                              Text(
                                terrain.nom,
                              ),
                            );
                          },
                        )
                            .toList(),

                        onChanged: (value) {
                          setDialogState(() {
                            terrainSelectionne =
                                value;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // ======================================================
                // BOUTONS
                // ======================================================

                actions: [

                  TextButton(
                    onPressed: () {
                      Navigator.of(
                        dialogContext,
                      ).pop(false);
                    },
                    child:
                    const Text('Annuler'),
                  ),

                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(
                        dialogContext,
                      ).pop(true);
                    },
                    icon: const Icon(
                      Icons.save,
                    ),
                    label:
                    const Text('Enregistrer'),
                  ),
                ],
              );
            },
          );
        },
      );

      // ============================================================
      // ANNULATION / FERMETURE DE LA PAGE
      // ============================================================

      if (!mounted) {
        return;
      }

      if (resultat != true) {
        return;
      }

      // ============================================================
      // RECHERCHE DU TERRAIN CHOISI
      // ============================================================

      Terrain? terrainChoisi;

      for (final terrain in terrains) {
        if (terrain.id == terrainSelectionne) {
          terrainChoisi = terrain;
          break;
        }
      }

      // ============================================================
      // NOUVELLE DATE AU FORMAT JJ/MM/AAAA
      // ============================================================

      final nouvelleDate =
          '${dateSelectionnee.day.toString().padLeft(2, '0')}/'
          '${dateSelectionnee.month.toString().padLeft(2, '0')}/'
          '${dateSelectionnee.year.toString().padLeft(4, '0')}';

      // ============================================================
      // NOUVELLE HEURE
      // ============================================================

      final nouvelleHeure =
      heureController.text.trim();

      // ============================================================
      // MISE À JOUR DU MATCH
      // ============================================================

      setState(() {
        match.dateMatch = nouvelleDate;

        match.heureMatch = nouvelleHeure;

        if (terrainChoisi != null) {
          match.stade = terrainChoisi.nom;
          match.ville = terrainChoisi.ville;
        }
      });

      // ============================================================
      // PUBLICATION SUR GITHUB
      // ============================================================

      final token =
      await demanderTokenGitHub();

      if (!mounted) {
        return;
      }

      if (token == null ||
          token.trim().isEmpty) {
        return;
      }

      try {

        debugPrint('========== AVANT PUBLICATION ==========');

        for (final m in tousLesMatchs) {
          debugPrint(
            '${m.equipeLocale} - ${m.equipeAdverse} | '
                '${m.dateMatch} | '
                '${m.heureMatch} | '
                '${m.stade} | '
                '${m.ville}',
          );
        }

        debugPrint('=======================================');
        await PlanningService.publierPlanning(
          listematchs: tousLesMatchs,
          token: token,
        );

        // ----------------------------------------------------------
        // Vérification après publication
        // ----------------------------------------------------------

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              'Match modifié et planning '
                  'publié sur GitHub.',
            ),
          ),
        );
      } catch (e) {
        // ----------------------------------------------------------
        // Erreur publication
        // ----------------------------------------------------------

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Erreur lors de la publication : $e',
            ),
          ),
        );
      }
    } finally {
      // ============================================================
      // LIBÉRATION DU CONTRÔLEUR
      // ============================================================

      heureController.dispose();
    }
  }


  Future<void> _chargerIsAdmin() async {
    final admin = await AdminService.isAdmin();

    if (!mounted) return;

    setState(() {
      isAdmin = admin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
            onLongPress: () async {
              final resultat = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminLoginPage(),
                ),
              );

              if (!mounted) return;

              if (resultat == true) {
                setState(() {
                  isAdmin = true;
                });
                // Informe la HomePage
                widget.onAdminConnecte?.call();
              }
            },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              'assets/images/logo_club.png',
              fit: BoxFit.contain,
            ),
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
                  trailing: isAdmin
                    ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(match.competition),

                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Modifier le match',
                          onPressed: () {
                             _modifierMatch(match);
                          },
                        ),
                      ],
                    )
                  : Text(
                        match.competition,
                    ),

                ),

              ),
             /* Card(
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
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${match.equipeLocale} - "
                              "${match.equipeAdverse}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          match.competition,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    "${match.stade} - ${match.ville}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )*/
            ],
          );
        },
      ),
    );
  }
}