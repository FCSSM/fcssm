import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';

import '../models/match.dart';
import '../services/planning_service.dart';

class PlanningEquipes extends StatefulWidget {
  const PlanningEquipes({
    super.key,
  });

  @override
  State<PlanningEquipes> createState() =>
      _PlanningEquipesState();
}

class _PlanningEquipesState
    extends State<PlanningEquipes> {

  // ===========================================================================
  // DONNÉES
  // ===========================================================================

  List<MatchFoot> _tousLesMatchs = [];

  List<String> _equipes = [];

  String? _equipeSelectionnee;

  // Afficher uniquement les matchs à venir
  bool _matchsAVenirUniquement = true;

  bool _chargement = true;

  String? _erreur;

  StreamSubscription? _planningSubscription;

  // ===========================================================================
  // INITIALISATION
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _chargerPlanning();

    // -------------------------------------------------------------------------
    // Surveillance des modifications du planning
    // -------------------------------------------------------------------------

    _planningSubscription =
        PlanningService.planningModifie.listen((_) {

          debugPrint(
            '[PlanningEquipes] 🔄 Planning modifié, actualisation.',
          );

          if (!mounted) {
            return;
          }

          _chargerPlanning();
        });
  }

  // ===========================================================================
  // DESTRUCTION
  // ===========================================================================

  @override
  void dispose() {
    _planningSubscription?.cancel();

    super.dispose();
  }

  // ===========================================================================
  // CHARGEMENT DU PLANNING
  // ===========================================================================

  Future<void> _chargerPlanning() async {

    if (mounted) {
      setState(() {
        _chargement = true;
        _erreur = null;
      });
    }

    try {

      final json =
      await PlanningService.loadPlanning();

      final dynamic decoded =
      jsonDecode(json);

      if (decoded is! List) {
        throw Exception(
          'Le planning doit contenir une liste de matchs.',
        );
      }

      final List<MatchFoot> matchs = [];

      for (final element in decoded) {

        if (element is! Map) {
          continue;
        }

        try {

          final match =
          MatchFoot.fromJson(
            Map<String, dynamic>.from(element),
          );

          matchs.add(match);

        } catch (e) {

          debugPrint(
            '[PlanningEquipes] Match ignoré : $e',
          );
        }
      }

      // -----------------------------------------------------------------------
      // Tri chronologique
      // -----------------------------------------------------------------------

      matchs.sort((a, b) {

        final comparaisonDate =
        a.date.compareTo(b.date);

        if (comparaisonDate != 0) {
          return comparaisonDate;
        }

        return a.heureEnMinutes
            .compareTo(b.heureEnMinutes);
      });

      // -----------------------------------------------------------------------
      // Construction de la liste des équipes
      // -----------------------------------------------------------------------

      final Set<String> equipesSet = {};

      for (final match in matchs) {

        final equipe =
        match.equipeLocale.trim();

        if (equipe.isNotEmpty) {
          equipesSet.add(equipe);
        }
      }

      final equipes =
      equipesSet.toList();

      equipes.sort(
            (a, b) => a.compareTo(b),
      );

      // -----------------------------------------------------------------------
      // Conserver l'équipe actuellement sélectionnée si elle existe encore
      // -----------------------------------------------------------------------

      String? nouvelleEquipe =
          _equipeSelectionnee;

      if (nouvelleEquipe == null ||
          !equipes.contains(nouvelleEquipe)) {

        nouvelleEquipe =
        equipes.isNotEmpty
            ? equipes.first
            : null;
      }

      if (!mounted) {
        return;
      }

      setState(() {

        _tousLesMatchs = matchs;

        _equipes = equipes;

        _equipeSelectionnee =
            nouvelleEquipe;

        _chargement = false;
      });

      debugPrint(
        '[PlanningEquipes] '
            '${matchs.length} matchs chargés.',
      );

      debugPrint(
        '[PlanningEquipes] '
            '${equipes.length} équipes trouvées.',
      );

    } catch (e) {

      debugPrint(
        '[PlanningEquipes] Erreur chargement : $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {

        _chargement = false;

        _erreur =
        'Impossible de charger le planning.\n\n$e';
      });
    }
  }

  // ===========================================================================
  // MATCHS DE L'ÉQUIPE SÉLECTIONNÉE
  // ===========================================================================

  List<MatchFoot> get _matchsEquipe {

    if (_equipeSelectionnee == null) {
      return [];
    }

    // Date du jour à minuit
    final maintenant = DateTime.now();

    final dateDuJour = DateTime(
      maintenant.year,
      maintenant.month,
      maintenant.day,
    );

    return _tousLesMatchs
        .where((match) {

      // Filtre sur l'équipe sélectionnée
      if (match.equipeLocale.trim() !=
          _equipeSelectionnee!.trim()) {
        return false;
      }

      // Si l'interrupteur est désactivé :
      // afficher tous les matchs
      if (!_matchsAVenirUniquement) {
        return true;
      }

      // Sinon :
      // uniquement les matchs d'aujourd'hui et futurs
      return !match.date.isBefore(dateDuJour);
    })
        .toList();
  }

 /* List<MatchFoot> get _matchsEquipe {

    if (_equipeSelectionnee == null) {
      return [];
    }

    // Date du jour à minuit
    final aujourdHui = DateTime.now();

    final dateDuJour = DateTime(
      aujourdHui.year,
      aujourdHui.month,
      aujourdHui.day,
    );

    return _tousLesMatchs
        .where((match) {

      // Filtre sur l'équipe sélectionnée
      if (match.equipeLocale.trim() !=
          _equipeSelectionnee!.trim()) {
        return false;
      }

      // Conserver uniquement les matchs
      // d'aujourd'hui et futurs
      return !match.date.isBefore(dateDuJour);
    })
        .toList();
  }*/
  /*List<MatchFoot> get _matchsEquipe {

    if (_equipeSelectionnee == null) {
      return [];
    }

    return _tousLesMatchs
        .where(
          (match) =>
      match.equipeLocale.trim() ==
          _equipeSelectionnee!.trim(),
    )
        .toList();
  }*/

  // ===========================================================================
  // COULEUR DU MATCH
  // ===========================================================================

  Color _couleurMatch(MatchFoot match) {

    if (match.estDomicile) {

      if (match.ville.toUpperCase() ==
          'ST SATURNIN') {

        return Colors.yellow.shade200;
      }

      if (match.ville.toUpperCase() ==
          'LA MILESSE') {

        return Colors.red.shade200;
      }
    }

    return Colors.grey.shade200;
  }

  // ===========================================================================
  // CARTE MATCH
  // ===========================================================================

  Widget _buildMatchCard(
      MatchFoot match,
      ) {
    final bool domicile = match.estDomicile;

    final String adversaire =
    match.equipeAdverse.trim().isEmpty
        ? 'Adversaire non renseigné'
        : match.equipeAdverse;

    final String equipeGauche =
    domicile
        ? match.equipeLocale
        : adversaire;

    final String equipeDroite =
    domicile
        ? adversaire
        : match.equipeLocale;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 6,
      ),
      color: _couleurMatch(match),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [

            // ===============================================================
            // DATE / HEURE / DOMICILE - EXTÉRIEUR
            // ===============================================================

            Row(
              children: [

                const Icon(
                  Icons.calendar_month,
                  size: 16,
                ),

                const SizedBox(width: 5),

                Text(
                  match.dateMatch,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(width: 12),

                const Icon(
                  Icons.access_time,
                  size: 16,
                ),

                const SizedBox(width: 4),

                Text(
                  match.heureFormatee,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const Spacer(),

                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius:
                    BorderRadius.circular(5),
                    color: Colors.white
                        .withValues(alpha: 0.65),
                  ),
                  child: Text(
                    domicile
                        ? 'DOMICILE'
                        : 'EXTÉRIEUR',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // ===============================================================
            // ÉQUIPES : UNE SEULE LIGNE
            // ===============================================================

            // ===============================================================
// ÉQUIPES : UNE SEULE LIGNE
// ===============================================================

            Text(
              '$equipeGauche - $equipeDroite',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            // ===============================================================
            // COMPÉTITION / PHASE : UNE SEULE LIGNE
            // ===============================================================

            Row(
              children: [

                const Icon(
                  Icons.emoji_events_outlined,
                  size: 15,
                ),

                const SizedBox(width: 5),

                Expanded(
                  child: Text(
                    match.competition.trim().isEmpty
                        ? '-'
                        : match.competition,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                    ),
                  ),
                ),

                if (match.phase.trim().isNotEmpty) ...[

                  const SizedBox(width: 8),

                  Flexible(
                    child: Text(
                      match.phase,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                        Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // ===============================================================
            // STADE / VILLE : UNE SEULE LIGNE
            // ===============================================================

            if (domicile &&
                (match.stade.trim().isNotEmpty ||
                    match.ville.trim().isNotEmpty))

              Padding(
                padding:
                const EdgeInsets.only(
                  top: 3,
                ),
                child: Row(
                  children: [

                    const Icon(
                      Icons.stadium_outlined,
                      size: 15,
                    ),

                    const SizedBox(width: 5),

                    Expanded(
                      child: Text(
                        [
                          if (match.stade
                              .trim()
                              .isNotEmpty)
                            match.stade,
                          if (match.ville
                              .trim()
                              .isNotEmpty)
                            match.ville,
                        ].join(' = '),
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ===============================================================
            // PHASE
            // ===============================================================
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // EN-TÊTE
  // ===========================================================================

  Widget _buildHeader() {

    final matchs =
        _matchsEquipe;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [

        DropdownButtonFormField<String>(
          initialValue:
          _equipeSelectionnee,
          decoration:
          const InputDecoration(
            labelText:
            'Équipe',
            prefixIcon:
            Icon(Icons.groups),
            border:
            OutlineInputBorder(),
          ),
          items: _equipes
              .map(
                (equipe) =>
                DropdownMenuItem<String>(
                  value: equipe,
                  child: Text(
                    equipe,
                    overflow:
                    TextOverflow.ellipsis,
                  ),
                ),
          )
              .toList(),
          onChanged: (value) {

            if (value == null) {
              return;
            }

            setState(() {
              _equipeSelectionnee =
                  value;
            });
          },
        ),

        const SizedBox(height: 8),

        if (_equipeSelectionnee != null)

          Row(
            children: [

              // =============================================================
              // INTERRUPTEUR
              // =============================================================

             /* Switch(
                value: _matchsAVenirUniquement,
                onChanged: (value) {
                  setState(() {
                    _matchsAVenirUniquement = value;
                  });
                },
              ),*/
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: _matchsAVenirUniquement,
                  onChanged: (value) {
                    setState(() {
                      _matchsAVenirUniquement = value;
                    });
                  },
                ),
              ),

              const SizedBox(width: 4),

              const Expanded(
                child: Text(
                  'Masquer les matchs passés',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // =============================================================
              // COMPTEUR
              // =============================================================

              const SizedBox(width: 8),

              const Icon(
                Icons.calendar_month,
                size: 18,
              ),

              const SizedBox(width: 5),

              Text(
                '${matchs.length} match'
                    '${matchs.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ===========================================================================
  // AFFICHAGE
  // ===========================================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    Widget body;

    // ============================================================
    // CHARGEMENT
    // ============================================================

    if (_chargement) {
      body = const Center(
        child: CircularProgressIndicator(),
      );
    }

    // ============================================================
    // ERREUR
    // ============================================================

    else if (_erreur != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 50,
              ),

              const SizedBox(height: 16),

              Text(
                _erreur!,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: _chargerPlanning,
                icon: const Icon(
                  Icons.refresh,
                ),
                label: const Text(
                  'Réessayer',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ============================================================
    // AUCUN MATCH DANS LE PLANNING
    // ============================================================

    else if (_tousLesMatchs.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 60,
            ),

            const SizedBox(height: 16),

            const Text(
              'Aucun match dans le planning.',
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _chargerPlanning,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Actualiser',
              ),
            ),
          ],
        ),
      );
    }

    // ============================================================
    // PLANNING
    // ============================================================

    else {
      final matchs = _matchsEquipe;

      body = RefreshIndicator(
        onRefresh: _chargerPlanning,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [

            // -----------------------------------------------------
            // SÉLECTION DE L'ÉQUIPE
            // -----------------------------------------------------

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _buildHeader(),
              ),
            ),

            // -----------------------------------------------------
            // AUCUN MATCH POUR CETTE ÉQUIPE
            // -----------------------------------------------------

            if (matchs.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'Aucun match pour cette équipe.',
                  ),
                ),
              )

            // -----------------------------------------------------
            // LISTE DES MATCHS
            // -----------------------------------------------------

            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  20,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      return _buildMatchCard(
                        matchs[index],
                      );
                    },
                    childCount: matchs.length,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // ============================================================
    // AFFICHAGE
    // ============================================================

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Image.asset(
            'assets/images/logo_club.png',
            fit: BoxFit.contain,
          ),
        ),
        title: const Text(
          "Planning équipes",
        ),
      ),

      body: body,
    );
  }

}