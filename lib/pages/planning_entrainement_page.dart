import 'package:flutter/material.dart';

import '../models/entrainement.dart';
import '../services/planning_entrainement_service.dart';

enum PlanningViewMode {
  jour,
  categorie,
}

class PlanningEntrainementPage extends StatefulWidget {
  const PlanningEntrainementPage({super.key});

  @override
  State<PlanningEntrainementPage> createState() =>
      _PlanningEntrainementPageState();
}

class _PlanningEntrainementPageState
    extends State<PlanningEntrainementPage> {
  final PlanningEntrainementService _planningService =
  PlanningEntrainementService();

  List<Entrainement> _entrainements = [];

  bool _chargement = true;
  String? _erreur;

  PlanningViewMode _mode = PlanningViewMode.jour;

  // ---------------------------------------------------------------------------
  // ORDRE DES JOURS
  // ---------------------------------------------------------------------------

  static const List<String> _ordreJours = [
    'LUNDI',
    'MARDI',
    'MERCREDI',
    'JEUDI',
    'VENDREDI',
    'SAMEDI',
    'DIMANCHE',
  ];

  // ---------------------------------------------------------------------------
  // ORDRE DES CATEGORIES
  //
  static const List<String> _ordreCategories = [
    'BABY',
    'U6 U7',
    'U8 U9',
    'U10 U11',
    'U12 U13',
    'U13 F',
    'U14 U15',
    'U16 U17',
    'VETERANS',
    'SENIORS',
  ];

  // ---------------------------------------------------------------------------
  // INITIALISATION
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _chargerPlanningEntrainement();
  }

  // ---------------------------------------------------------------------------
  // CHARGEMENT DU PLANNING
  // ---------------------------------------------------------------------------

  Future<void> _chargerPlanningEntrainement() async {
    try {
      final planning =
      await _planningService.chargerPlanningEntrainement();

      if (!mounted) return;

      setState(() {
        _entrainements = planning;
        _chargement = false;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _erreur = 'Impossible de charger le planning.';
        _chargement = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD PRINCIPAL
  // ---------------------------------------------------------------------------

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
        title: Text("Planning entraînements"),

      ),
      body: _buildBody(),
    );
  }

  // ---------------------------------------------------------------------------
  // BODY
  // ---------------------------------------------------------------------------

  Widget _buildBody() {
    if (_chargement) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_erreur != null) {
      return _buildErreur();
    }

    return Column(
      children: [
        const SizedBox(height: 12),

        _buildModeSelector(),

        const SizedBox(height: 8),

        Expanded(
          child: _mode == PlanningViewMode.jour
              ? _buildVueParJour()
              : _buildVueParCategorie(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ERREUR
  // ---------------------------------------------------------------------------

  Widget _buildErreur() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),

          const SizedBox(height: 16),

          Text(_erreur!),

          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: () {
              setState(() {
                _chargement = true;
                _erreur = null;
              });

              _chargerPlanningEntrainement();
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SÉLECTEUR DE VUE
  // ---------------------------------------------------------------------------

  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<PlanningViewMode>(
        segments: const <ButtonSegment<PlanningViewMode>>[
          ButtonSegment<PlanningViewMode>(
            value: PlanningViewMode.jour,
            icon: Icon(Icons.calendar_month),
            label: Text('Par jour'),
          ),
          ButtonSegment<PlanningViewMode>(
            value: PlanningViewMode.categorie,
            icon: Icon(Icons.groups),
            label: Text('Par catégorie'),
          ),
        ],

        selected: <PlanningViewMode>{_mode},

        showSelectedIcon: false,

        onSelectionChanged:
            (Set<PlanningViewMode> selection) {
          setState(() {
            _mode = selection.first;
          });
        },
      ),
    );
  }

  // ===========================================================================
  // VUE PAR JOUR
  // ===========================================================================

  Widget _buildVueParJour() {
    final entrainements =
    List<Entrainement>.from(_entrainements);

    // Tri :
    // 1. jour
    // 2. heure de début
    // 3. lieu
    entrainements.sort((a, b) {
      final indexJourA = _ordreJours.indexOf(a.jour);
      final indexJourB = _ordreJours.indexOf(b.jour);

      if (indexJourA != indexJourB) {
        return indexJourA.compareTo(indexJourB);
      }

      final comparaisonHeure =
      a.heureDebut.compareTo(b.heureDebut);

      if (comparaisonHeure != 0) {
        return comparaisonHeure;
      }

      return a.lieu.compareTo(b.lieu);
    });

    if (entrainements.isEmpty) {
      return _buildPlanningVide();
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: entrainements.length,
      itemBuilder: (context, index) {
        final entrainement = entrainements[index];

        final bool afficherJour =
            index == 0 ||
                entrainement.jour != entrainements[index - 1].jour;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -----------------------------------------------------------------
            // NOM DU JOUR
            // -----------------------------------------------------------------

            if (afficherJour)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  8,
                ),
                child: Text(
                  entrainement.jour,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // -----------------------------------------------------------------
            // SÉANCE
            // -----------------------------------------------------------------

            _buildEntrainementCard(entrainement),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // VUE PAR CATÉGORIE
  // ===========================================================================

  Widget _buildVueParCategorie() {
    final entrainements =
    List<Entrainement>.from(_entrainements);

    entrainements.sort((a, b) {
      final indexCategorieA =
      _ordreCategories.indexOf(a.categorie);

      final indexCategorieB =
      _ordreCategories.indexOf(b.categorie);

      // Les catégories connues suivent l'ordre défini.
      // Une catégorie inconnue est placée à la fin.
      final ordreA = indexCategorieA == -1
          ? _ordreCategories.length
          : indexCategorieA;

      final ordreB = indexCategorieB == -1
          ? _ordreCategories.length
          : indexCategorieB;

      if (ordreA != ordreB) {
        return ordreA.compareTo(ordreB);
      }

      // À l'intérieur d'une catégorie :
      // 1. jour
      // 2. heure
      // 3. lieu

      final indexJourA = _ordreJours.indexOf(a.jour);
      final indexJourB = _ordreJours.indexOf(b.jour);

      if (indexJourA != indexJourB) {
        return indexJourA.compareTo(indexJourB);
      }

      final comparaisonHeure =
      a.heureDebut.compareTo(b.heureDebut);

      if (comparaisonHeure != 0) {
        return comparaisonHeure;
      }

      return a.lieu.compareTo(b.lieu);
    });

    if (entrainements.isEmpty) {
      return _buildPlanningVide();
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: entrainements.length,
      itemBuilder: (context, index) {
        final entrainement = entrainements[index];

        final bool afficherCategorie =
            index == 0 ||
                entrainement.categorie !=
                    entrainements[index - 1].categorie;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (afficherCategorie)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  8,
                ),
                child: Text(
                  entrainement.categorie,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            _buildEntrainementCard(
              entrainement,
              afficherJourDansCarte: true,
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // CARD D'UNE SÉANCE
  // ===========================================================================


  Widget _buildEntrainementCard(
      Entrainement entrainement, {
        bool afficherJourDansCarte = false,
      }) {
    final String informationPrincipale =
    afficherJourDansCarte
        ? entrainement.jour
        : entrainement.categorie;

    return Card(
      color: couleurEntrainement(entrainement.lieu),
      margin: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ===============================================================
            // HORAIRE + CATÉGORIE / JOUR
            // ===============================================================

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // -----------------------------------------------------------
                // HORAIRE
                // -----------------------------------------------------------

                Flexible(
                  flex: 0,
                  child: Text(
                    entrainement.horaire,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // -----------------------------------------------------------
                // CATÉGORIE / JOUR
                // -----------------------------------------------------------

                Expanded(
                  child: Text(
                    informationPrincipale,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // ===============================================================
            // LIEU
            // ===============================================================

            Row(
              children: [

                const Icon(
                  Icons.stadium_outlined,
                  size: 15,
                ),

                const SizedBox(width: 5),

                Expanded(
                  child: Text(
                    entrainement.lieu,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

/*  Widget _buildEntrainementCard(

      Entrainement entrainement, {
        bool afficherJourDansCarte = false,
      }) {
    final String informationPrincipale =
    afficherJourDansCarte
        ? entrainement.jour
        : entrainement.categorie;

    return Card(
      color: couleurEntrainement(entrainement.lieu),
      margin: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: [
            // ---------------------------------------------------------------
            // HORAIRE
            // ---------------------------------------------------------------

            SizedBox(
              width: 95,
              child: Text(
                entrainement.horaire,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // ---------------------------------------------------------------
            // CATÉGORIE OU JOUR
            // ---------------------------------------------------------------

            Expanded(
              flex: 2,
              child: Text(
                informationPrincipale,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(width: 8),

            // ---------------------------------------------------------------
            // LIEU
            // ---------------------------------------------------------------

            Expanded(
              flex: 2,
              child: Text(
                entrainement.lieu,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }*/

  // ===========================================================================
  // COULEUR SELON LE LIEU
  // ===========================================================================

  Color couleurEntrainement(String lieu) {
    switch (lieu) {
      case 'SAINT SATURNIN':
        return Colors.yellow.shade200;

      case 'LA MILESSE':
        return Colors.red.shade200;

      case 'SAINT SATURNIN SYNTHETIQUE':
        return Colors.green.shade200;

      default:
        return Colors.grey.shade200;
    }
  }

  // ===========================================================================
  // PLANNING VIDE
  // ===========================================================================

  Widget _buildPlanningVide() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 48,
            color: Colors.grey,
          ),

          SizedBox(height: 12),

          Text(
            'Aucun entraînement.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}