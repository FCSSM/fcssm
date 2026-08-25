import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:week_number/iso.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/match.dart' ;
import '../models/terrain.dart';
import '../services/firestore_service.dart';
import '../services/terrain_service.dart';
import '../services/planning_service.dart';
import 'admin_login_page.dart';



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

  StreamSubscription<void>? _planningSubscription;

  bool isAdmin = false;

  final PageController _semainePageController =
  PageController(initialPage: 1);

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

  List<String> get equipesDisponibles {
    return tousLesMatchs
        .map((match) => match.equipeLocale)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> get listeCompetitions {
    return tousLesMatchs
        .map((match) => match.competition)
        .toSet()
        .toList()
      ..sort();
  }


  Widget _buildStatutMatch(MatchFoot match) {
    String? texte;
    IconData? icone;
    Color? couleur;

    switch (match.statut) {
      case MatchFoot.statutReporte:
        texte = 'REPORTÉ';
        icone = Icons.event_busy;
        couleur = Colors.orange.shade700;
        break;

      case MatchFoot.statutForfaitFc:
        texte = 'FORFAIT FCSSM';
        icone = Icons.cancel;
        couleur = Colors.red.shade700;
        break;

      case MatchFoot.statutForfaitAdverse:
        texte = 'FORFAIT ADVERSE';
        icone = Icons.block;
        couleur = Colors.blue.shade700;
        break;

      default:
        return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 3),
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: couleur,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icone,
              color: Colors.white,
              size: 13,
            ),
            const SizedBox(width: 4),
            Text(
              texte,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.authStateChanges().listen(
          (User? user) async {
        if (!mounted) return;

        if (user == null) {
          setState(() {
            isAdmin = false;
          });
          return;
        }

        try {
          // Force le rafraîchissement du token afin de récupérer
          // les dernières custom claims.
          final idTokenResult =
          await user.getIdTokenResult(true);

          final admin =
              idTokenResult.claims?['admin'] == true;

          debugPrint(
            '[PlanningPage] Utilisateur : ${user.email}',
          );

          debugPrint(
            '[PlanningPage] Admin : $admin',
          );

          if (!mounted) return;

          setState(() {
            isAdmin = admin;
          });
        } catch (e) {
          debugPrint(
            '[PlanningPage] Erreur récupération rôle admin : $e',
          );

          if (!mounted) return;

          setState(() {
            isAdmin = false;
          });
        }
      },
    );


    // Surveillance des modifications du planning
    _planningSubscription =
        PlanningService.planningModifie.listen((_) {
          debugPrint(
            '[PlanningPage] 🔄 Planning modifié, rechargement.',
          );

          if (!mounted) {
            return;
          }

          // Recharger les matchs depuis Firestore
          chargerPlanning(semaineSelectionnee);
        });

    // Chargement initial
    chargerPlanning(semaineSelectionnee);
  }

  @override
  void dispose() {
    _planningSubscription?.cancel();
    _semainePageController.dispose();
    super.dispose();

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

      await _actualiserPlanning(
        jsonString,
        semaine,
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Erreur lors du chargement du planning : $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }


  void actualiserMatchsSemaine() {

    matchsSemaine = tousLesMatchs.where((match) {
      if (match.noSemaine != semaineSelectionnee) {
        return false;
      }

      if (uniquementDomicile && !match.estDomicile) {
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
  }

  Future<void> _actualiserPlanning(

      String jsonString,
      int semaine,
      ) async {
    try {
      final List<MatchFoot> listeMatchs =
      (jsonDecode(jsonString) as List)
          .cast<Map<String, dynamic>>()
          .map(MatchFoot.fromJson)
          .toList();

      // On vérifie que le State existe toujours avant setState.
      // C'est particulièrement important après un await.
      if (!mounted) {
        return;
      }

      setState(() {
        // ---------------------------------------------
        // On conserve TOUS les matchs
        // ---------------------------------------------
        tousLesMatchs = listeMatchs;

        // ---------------------------------------------
        // On construit uniquement la liste affichée
        // ---------------------------------------------
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
      debugPrint(
        'Erreur lors de l\'actualisation du planning : $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void semainePrecedente() {
    if (semaineSelectionnee > 1) {
      setState(() {
        semaineSelectionnee--;
      });
      actualiserMatchsSemaine();
    }
  }

  void semaineSuivante() {
    setState(() {
      semaineSelectionnee++;
    });
    actualiserMatchsSemaine();
  }


  Future<void> _modifierMatch(MatchFoot match) async {
    // ============================================================
    // CONTRÔLEUR HEURE
    // ============================================================
    final initialData = 'Match initial:\n'
    '📅 ${match.dateMatch}\n'
    '🕐 ${match.heureMatch}\n'
    '📍 ${match.stade}';

    String statutSelectionne =
        match.statut ?? MatchFoot.statutNormal;

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

                      DropdownButtonFormField<String>(
                        initialValue: statutSelectionne,
                        decoration: const InputDecoration(
                          labelText: 'Statut du match',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: MatchFoot.statutNormal,
                            child: Text('Match normal'),
                          ),
                          DropdownMenuItem(
                            value: MatchFoot.statutReporte,
                            child: Text('Match reporté'),
                          ),
                          DropdownMenuItem(
                            value: MatchFoot.statutForfaitFc,
                            child: Text('Forfait FCSSM'),
                          ),
                          DropdownMenuItem(
                            value: MatchFoot.statutForfaitAdverse,
                            child: Text('Forfait adverse'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            statutSelectionne = value;
                          });
                        },
                      ),

                      const SizedBox(height: 16),

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

      match.statut = statutSelectionne;

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

        match.modification= initialData;

      });

      // ============================================================
      // PUBLICATION SUR GITHUB
      // ============================================================

      try {
          await FirestoreService.modifierMatch(
          match: match,
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
              'Match modifié.',
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


  void _afficherModification(MatchFoot match) {

    final modification = match.modification?.trim();

    // Aucun message de modification :
    // on ne fait rien.
    if (modification == null || modification.isEmpty) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Match modifié',
                ),
              ),
            ],
          ),

          content: Text(
            modification,
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> ajouterMatch() async {

    DateTime? dateMatch;
    TimeOfDay? heureMatch;

    String? equipeLocale;
    String? equipeAdverse;
    String? stade;
    String? competition;

    final formKey = GlobalKey<FormState>();

    final terrains =
    await TerrainService.chargerTerrains();

    String formatDate2(DateTime date) {
      return DateFormat('dd/MM/yyyy').format(date);
    }

    if (!mounted) {
      return;
    }

    final resultat = await showDialog<MatchFoot>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Ajouter un match"),

              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // ----------------------------------------
                      // Équipe locale
                      // ----------------------------------------
                      DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                          labelText: "Équipe locale",
                          prefixIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(
                            'assets/images/logo_club.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      initialValue: equipeLocale,
                      isExpanded: true,

                      items: equipesDisponibles.map((equipe) {
                        return DropdownMenuItem<String>(
                          value: equipe,
                          child: Text(equipe),
                        );
                      }).toList(),

                      onChanged: (value) {
                        setDialogState(() {
                          equipeLocale = value;
                        });
                      },

                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Sélectionnez une équipe";
                        }
                        return null;
                      },
                    ),

                      const SizedBox(height: 16),

                      // ----------------------------------------
                      // Date
                      // ----------------------------------------
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: dateMatch ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            locale: const Locale('fr', 'FR'),
                          );

                          if (date != null) {
                            setDialogState(() {
                              dateMatch = date;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: "Date du match",
                            prefixIcon: Icon(Icons.calendar_month),
                          ),
                          child: Text(
                            dateMatch == null
                                ? "Sélectionner une date"
                                : "${dateMatch!.day.toString().padLeft(2, '0')}/"
                                "${dateMatch!.month.toString().padLeft(2, '0')}/"
                                "${dateMatch!.year}",
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ----------------------------------------
                      // Heure
                      // ----------------------------------------
                      InkWell(
                        onTap: () async {
                          final heure = await showTimePicker(
                            context: context,
                            initialTime: heureMatch ?? const TimeOfDay(hour: 15, minute: 0),
                            initialEntryMode: TimePickerEntryMode.dial,
                            cancelText: 'Annuler',
                            confirmText: 'Valider',
                            helpText: 'Sélectionner l’heure',
                            builder: (context, child) {
                              return MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                  alwaysUse24HourFormat: true,
                                ),
                                child: child!,
                              );
                            },
                          );

                          if (heure != null) {
                            setDialogState(() {
                              heureMatch = heure;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: "Heure du match",
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          child: Text(
                            heureMatch == null
                                ? "Sélectionner une heure"
                                : formatHeure(heureMatch!),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ----------------------------------------
                      // Équipe adverse
                      // ----------------------------------------
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: "Équipe adverse",
                          prefixIcon: Icon(Icons.groups),
                        ),
                        onChanged: (value) {
                          equipeAdverse = value;
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Saisissez l'équipe adverse";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // ==================================================
                      // TERRAIN
                      // ==================================================

                      DropdownButtonFormField<String>(
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
                        ).toList(),

                        onChanged: (value) {
                          setDialogState(() {
                            stade =
                                value;
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      // ----------------------------------------
                      // Compétition
                      // ----------------------------------------
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: "Compétition",
                          prefixIcon: Icon(Icons.emoji_events),
                        ),
                        initialValue: competition,
                        isExpanded: true,
                        items: listeCompetitions.map((competition) {
                          return DropdownMenuItem<String>(
                            value: competition,
                            child: Text(competition),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            competition = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Sélectionnez une compétition";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Annuler"),
                ),

                FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text("Ajouter"),
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    if (dateMatch == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Sélectionnez une date"),
                        ),
                      );
                      return;
                    }

                    // ============================================================
                    // RECHERCHE DU TERRAIN SELECTIONE
                    // ============================================================

                    Terrain? terrainSelectionne;

                    for (final terrain in terrains) {
                      if (terrain.id == stade) {
                        terrainSelectionne = terrain;
                        break;
                      }
                    }

                    final nouveauMatch = MatchFoot(
                      numeroMatch: '1',
                      equipeLocale: equipeLocale!,
                      recevant: 'oui',
                      dateMatch: formatDate2(dateMatch!),
                      heureMatch: formatHeure(heureMatch!),
                      equipeAdverse: equipeAdverse!.trim(),
                      stade: terrainSelectionne?.nom ?? '',
                      phase: 'aller',
                      ville: terrainSelectionne?.ville ?? '',
                      competition: competition!,
                      noSemaine: numeroSemaine(dateMatch!),
                      modification: '',
                    );

                    Navigator.pop(context, nouveauMatch);

                  },
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted) {
      return;
    }

    if (resultat == null) {
      return;
    }



    // Ici : enregistrement dans ta base
    setState(() {
      tousLesMatchs.add(resultat);
      actualiserMatchsSemaine();
    });


    await FirestoreService.ajouterMatch(
        match: resultat,
    );


  }

  String formatHeure(TimeOfDay heure) {
    final h = heure.hour.toString().padLeft(2, '0');
    final m = heure.minute.toString().padLeft(2, '0');

    return '${h}H$m';
  }


  Future<void> supprimerMatch(MatchFoot match) async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer le match ?'),
          content: Text(
            '${match.equipeLocale} - ${match.equipeAdverse}\n'
                '${match.dateMatch} à ${match.heureMatch}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (confirmer != true) {
      return;
    }

    // Ici : suppression dans ta base
    // Puis rechargement du planning

    // ============================================================
    // PUBLICATION SUR FIREBASE
    // ============================================================

    setState(() {
      tousLesMatchs.remove(match);
      actualiserMatchsSemaine();
    });

    final numeroMatch = match.numeroMatch;

    debugPrint('Match a supprimer: $numeroMatch');

    if (numeroMatch == null ||
      numeroMatch.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Impossible de supprimer le match : '
              'numéro de match absent.',
            ),
          ),
         );
        return;
    }

    await FirestoreService.supprimerMatch(
      numeroMatch: numeroMatch,
    );

  }

  void _semaineSwipee(int page) {
    if (page == 1) {
      return;
    }

    if (page == 0) {
      if (semaineSelectionnee <= 1) {
        // On est déjà à la première semaine.
        _semainePageController.jumpToPage(1);
        return;
      }

      semainePrecedente();
    }

    if (page == 2) {
      semaineSuivante();
    }

    // On remet immédiatement le PageView
    // sur la semaine centrale.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (_semainePageController.hasClients) {
        _semainePageController.jumpToPage(1);
      }
    });
  }

  Widget _buildListeMatchs() {
    if (matchsSemaine.isEmpty) {
      return const Center(
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
      );
    }

    return ListView.builder(
      itemCount: matchsSemaine.length,

      itemBuilder: (context, index) {
        final match = matchsSemaine[index];

        final bool afficherDate =
            index == 0 ||
                match.date != matchsSemaine[index - 1].date;

        return Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            // ---------------------------------------------------
            // DATE
            // ---------------------------------------------------

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

            // ---------------------------------------------------
            // CARD DU MATCH
            // ---------------------------------------------------

            Card(
              color: couleurMatch(match.couleur),
              margin: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),

              child: ListTile(
                dense: true,

                // -------------------------------------------------
                // Appui sur le match
                // -------------------------------------------------

                onTap:
                match.modification != null &&
                    match.modification!
                        .trim()
                        .isNotEmpty
                    ? () => _afficherModification(match)
                    : null,

                // -------------------------------------------------
                // HEURE
                // -------------------------------------------------

                leading: Text(
                  match.heureMatch,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),

                // -------------------------------------------------
                // ÉQUIPES + STATUT
                // -------------------------------------------------

                title: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  mainAxisSize:
                  MainAxisSize.min,

                  children: [
                    Row(
                      children: [

                        Expanded(
                          child: Text(
                            '${match.equipeLocale} - '
                                '${match.equipeAdverse}',
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),

                        // -----------------------------------------
                        // ⚠️ Modification
                        // -----------------------------------------

                        if (match.modification != null &&
                            match.modification!
                                .trim()
                                .isNotEmpty &&
                            (match.statut == null ||
                                match.statut ==
                                    MatchFoot.statutNormal))
                          const Padding(
                            padding:
                            EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons
                                  .warning_amber_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                      ],
                    ),

                    // -----------------------------------------
                    // STATUT
                    // -----------------------------------------

                    _buildStatutMatch(match),
                  ],
                ),

                // -------------------------------------------------
                // STADE - VILLE
                // -------------------------------------------------

                subtitle: Text(
                  '${match.stade} - ${match.ville}',
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),

                // -------------------------------------------------
                // ADMINISTRATION
                // -------------------------------------------------

                trailing: isAdmin
                    ? Row(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [

                    // Compétition
                    Text(
                      match.competition,
                      style:
                      const TextStyle(
                        fontSize: 11,
                      ),
                    ),

                    // Modifier
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 20,
                      ),
                      tooltip:
                      'Modifier le match',
                      onPressed: () {
                        _modifierMatch(match);
                      },
                    ),

                    // Supprimer
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                      ),
                      tooltip:
                      'Supprimer le match',
                      onPressed: () =>
                          supprimerMatch(match),
                    ),
                  ],
                )
                    : Text(
                  match.competition,
                  style:
                  const TextStyle(
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
            onLongPress: () async {
              if (isAdmin) {
                final confirmer = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Déconnexion'),
                      content: const Text(
                        'Voulez-vous vous déconnecter du mode administrateur ?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context, false);
                          },
                          child: const Text('Annuler'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(context, true);
                          },
                          child: const Text('Déconnexion'),
                        ),
                      ],
                    );
                  },
                );

                if (confirmer == true) {
                  await FirebaseAuth.instance.signOut();
                }

                return;
              }

              // -------------------------------------------------
              // Utilisateur normal : ouverture de la connexion
              // -------------------------------------------------

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminLoginPage(),
                ),
              );

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

                //const Text("Date:"),
                // -------------------------------------------------
                // Semaine précédente
                // -------------------------------------------------
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Semaine précédente',
                  onPressed: semaineSelectionnee > 1
                      ? semainePrecedente
                      : null,
                ),

                //const SizedBox(width: 10),

                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  tooltip: "Choisir une date",
                  onPressed: choisirDate,
                ),

                //const SizedBox(width: 20),

                // -------------------------------------------------
                // Semaine suivante
                // -------------------------------------------------
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Semaine suivante',
                  onPressed: semaineSuivante,
                ),

                const SizedBox(width: 20),

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
              ],
            ),
          ),
        ),
      ),
      // 👇 Nouvelle action principale
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
        onPressed: ajouterMatch,
        icon: const Icon(Icons.add),
        label: const Text("Ajouter un match"),
        tooltip: "Ajouter un match",
      )
          : null,
      body: PageView(
      controller: _semainePageController,

      // ---------------------------------------------------------
      // Détection du balayage
      // ---------------------------------------------------------

      onPageChanged: _semaineSwipee,

      children: [
        // =======================================================
        // SEMAINE PRÉCÉDENTE
        // =======================================================

        _buildListeMatchs(),

        // =======================================================
        // SEMAINE ACTUELLE
        // =======================================================

        _buildListeMatchs(),

        // =======================================================
        // SEMAINE SUIVANTE
        // =======================================================

        _buildListeMatchs(),
      ],
    ),

          /*
      matchsSemaine.isEmpty
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
                  dense: true,

                  // ---------------------------------------------------
                  // Appui sur le match
                  // ---------------------------------------------------

                  onTap: match.modification != null &&
                      match.modification!.trim().isNotEmpty
                      ? () => _afficherModification(match)
                      : null,

                  // ---------------------------------------------------
                  // HEURE
                  // ---------------------------------------------------

                  leading: Text(
                    match.heureMatch,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),

                  // ---------------------------------------------------
                  // ÉQUIPES + STATUT
                  // ---------------------------------------------------

                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // -------------------------------------------------
                      // Équipes
                      // -------------------------------------------------

                      Row(
                        children: [

                          Expanded(
                            child: Text(
                              '${match.equipeLocale} - '
                                  '${match.equipeAdverse}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),

                          // ---------------------------------------------
                          // ⚠️ Match modifié
                          // ---------------------------------------------

                          if (match.modification != null &&
                              match.modification!.trim().isNotEmpty &&
                              (match.statut == null ||
                                  match.statut == MatchFoot.statutNormal))
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),

                          // -------------------------------------------------
                          // STATUT
                          // -------------------------------------------------

                          _buildStatutMatch(match),
                        ],
                      ),

                      // -------------------------------------------------
                      // STATUT
                      // -------------------------------------------------

                      if (match.statut == MatchFoot.statutReporte)
                        const Text(
                          'MATCH REPORTÉ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),

                      if (match.statut == MatchFoot.statutForfaitFc)
                        const Text(
                          'FORFAIT FCSSM',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),

                      if (match.statut == MatchFoot.statutForfaitAdverse)
                        const Text(
                          'FORFAIT ADVERSE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),

                  // ---------------------------------------------------
                  // STADE - VILLE
                  // ---------------------------------------------------

                  subtitle: Text(
                    '${match.stade} - ${match.ville}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),

                  // ---------------------------------------------------
                  // ADMINISTRATION
                  // ---------------------------------------------------

                  trailing: isAdmin
                      ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // Compétition
                      Text(
                        match.competition,
                        style: const TextStyle(
                          fontSize: 11,
                        ),
                      ),

                      // Modifier
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          size: 20,
                        ),
                        tooltip: 'Modifier le match',
                        onPressed: () {
                          _modifierMatch(match);
                        },
                      ),

                      // Supprimer
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                        ),
                        tooltip: 'Supprimer le match',
                        onPressed: () => supprimerMatch(match),
                      ),
                    ],
                  )
                      : Text(
                    match.competition,
                    style: const TextStyle(
                      fontSize: 11,
                    ),
                  ),
                ),
              ),

            ],
          );
        },
      ),
      */
    );
  }
}