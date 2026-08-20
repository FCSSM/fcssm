import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:week_number/iso.dart';

import '../models/match.dart' ;
import '../models/terrain.dart';
import '../services/terrain_service.dart';
import '../services/planning_service.dart';
import 'admin_login_page.dart';
import '../services/admin_service.dart';
import '../services/github_service.dart';


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
  Timer? _planningSyncTimer;
  bool _synchronisationEnCours = false;
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

  @override
  void initState() {
    super.initState();
    _chargerIsAdmin();
    // Au démarrage :
    // on affiche automatiquement la semaine actuelle
    // Chargement initial
    chargerPlanning(semaineSelectionnee);

    // Démarrage de la synchronisation
    _demarrerSynchronisation();
  }

  @override
  void dispose() {
    _planningSyncTimer?.cancel();
    super.dispose();
  }

  void _demarrerSynchronisation() {
    _planningSyncTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) {
        _verifierSynchronisation();
      },
    );
  }

  Future<void> _verifierSynchronisation() async {
    if (_synchronisationEnCours) {
      return;
    }

    _synchronisationEnCours = true;

    try {
      debugPrint(
        '[PlanningPage] Vérification du planning...',
      );

      final bool nouvelleVersion =
      await PlanningService.verifierNouvelleVersion();

      if (!nouvelleVersion) {
        debugPrint(
          '[PlanningPage] Planning déjà à jour.',
        );

        return;
      }

      debugPrint(
        '[PlanningPage] 🔄 Nouvelle version du planning détectée.',
      );

      final String jsonString =
      await PlanningService.reloadPlanning();

      if (!mounted) {
        return;
      }

      // Ici tu peux reprendre exactement
      // ton traitement actuel du JSON.
      await _actualiserPlanning(jsonString,semaineSelectionnee);

    } catch (e) {
      debugPrint(
        '[PlanningPage] Erreur synchronisation : $e',
      );
    } finally {
      _synchronisationEnCours = false;
    }
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

        match.modification= initialData;

      });

      // ============================================================
      // PUBLICATION SUR GITHUB
      // ============================================================

      final githubService = GithubService();
      final token = await githubService.demanderTokenGitHub(context);

      if (!mounted) {
        return;
      }

      if (token == null ||
          token.trim().isEmpty) {
        return;
      }

      try {
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



    // ============================================================
    // PUBLICATION SUR GITHUB
    // ============================================================

    final githubService = GithubService();
    final token = await githubService.demanderTokenGitHub(context);

    if (token == null ||
        token.trim().isEmpty) {
      return;
    }

    // Ici : enregistrement dans ta base
    setState(() {
      tousLesMatchs.add(resultat);
      actualiserMatchsSemaine();
    });

    await PlanningService.publierPlanning(
      listematchs: tousLesMatchs,
      token: token,
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
    // PUBLICATION SUR GITHUB
    // ============================================================

    final githubService = GithubService();
    final token = await githubService.demanderTokenGitHub(context);

    if (token == null ||
        token.trim().isEmpty) {
      return;
    }

    setState(() {
      tousLesMatchs.remove(match);
      actualiserMatchsSemaine();
    });

    await PlanningService.publierPlanning(
      listematchs: tousLesMatchs,
      token: token,
    );

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
                  // ---------------------------------------------------
                  // Appui sur le match
                  // ---------------------------------------------------
                  onTap: match.modification != null &&
                  match.modification!.trim().isNotEmpty
                  ? () => _afficherModification(match)
                      : null,
                  leading: Text(
                    match.heureMatch,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  title: Row(
                    children: [
                      // Nom des équipes
                      Expanded(
                        child: Text(
                          "${match.equipeLocale} - "
                              "${match.equipeAdverse}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),

                      // ------------------------------------------------
                      // ⚠️ Match modifié
                      // ------------------------------------------------
                      if (match.modification != null &&
                          match.modification!.trim().isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    "${match.stade} - ${match.ville}",
                    style: const TextStyle(
                      fontSize: 12,
                    ),
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

                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Supprimer le match',
                          onPressed: () => supprimerMatch(match),
                        ),
                      ],
                    )
                  : Text(
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