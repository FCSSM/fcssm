import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/match.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import 'dart:async';


class PlanningService {
  // ===========================================================================
  // CONFIGURATION
  // ===========================================================================


  /// Asset embarqué dans l'application.
  static const String _assetPath = 'assets/planning.json';

  /// Clés utilisées dans le stockage local.
  static const String _cacheKey = 'planning_json';
  static const String _versionKey = 'planning_version';

// ===========================================================================
// SURVEILLANCE DU PLANNING
// ===========================================================================

  static StreamSubscription<String?>? _versionSubscription;

  static final StreamController<void> _planningController =
  StreamController<void>.broadcast();

  static Stream<void> get planningModifie =>
      _planningController.stream;

  static String? _versionPlanningConnue;

  static void demarrerSurveillancePlanning() {
    if (_versionSubscription != null) {
      debugPrint(
        '[PlanningService] Surveillance déjà active.',
      );
      return;
    }

    debugPrint(
      '[PlanningService] Démarrage de la surveillance du planning.',
    );

    _versionSubscription =
        FirestoreService.ecouterVersionPlanning().listen(
              (version) async {
            debugPrint(
              '[PlanningService] Version reçue : '
                  '${version ?? "aucune"}',
            );

            // Première réception :
            // on mémorise simplement la version.
            if (_versionPlanningConnue == null) {
              _versionPlanningConnue = version;

              debugPrint(
                '[PlanningService] Version initiale mémorisée : $version',
              );

              return;
            }

            // Même version :
            // aucune action.
            if (_versionPlanningConnue == version) {
              return;
            }

            // Nouvelle version.
            debugPrint(
              '[PlanningService] 🔄 Nouvelle version détectée : '
                  '$_versionPlanningConnue → $version',
            );

            _versionPlanningConnue = version;

            try {
              await reloadPlanning();

              debugPrint(
                '[PlanningService] Planning rechargé.',
              );

              _planningController.add(null);
            } catch (e) {
              debugPrint(
                '[PlanningService] Erreur lors du rechargement : $e',
              );
            }
          },
          onError: (error) {
            debugPrint(
              '[PlanningService] Erreur surveillance Firestore : $error',
            );
          },
        );
  }

  static Future<void> arreterSurveillancePlanning() async {
    await _versionSubscription?.cancel();

    _versionSubscription = null;

    debugPrint(
      '[PlanningService] Surveillance du planning arrêtée.',
    );
  }

// ===========================================================================
// FIRESTORE
// ===========================================================================

  static Future<String> _chargerPlanningFirestore() async {
    debugPrint(
      '[PlanningService] Chargement du planning depuis Firestore.',
    );

    final snapshot = await FirebaseFirestore.instance
        .collection('matchs')
        .get();

    debugPrint(
      '[PlanningService] ${snapshot.docs.length} matchs récupérés.',
    );

    final List<Map<String, dynamic>> matchs = [];

    for (final document in snapshot.docs) {
      final data = document.data();

      matchs.add({
        ...data,
        'no_match': data['no_match'] ?? document.id,
      });
    }

    // ----------------------------------------------------------
    // Tri par date puis par heure
    // ----------------------------------------------------------

    matchs.sort((a, b) {
      final dateA = a['date_match']?.toString() ?? '';
      final dateB = b['date_match']?.toString() ?? '';

      final comparaisonDate = dateA.compareTo(dateB);

      if (comparaisonDate != 0) {
        return comparaisonDate;
      }

      final heureA = a['heure_match']?.toString() ?? '';
      final heureB = b['heure_match']?.toString() ?? '';

      return heureA.compareTo(heureB);
    });

    return const JsonEncoder.withIndent('  ').convert(matchs);
  }


  // ===========================================================================
  // CHARGEMENT EN MÉMOIRE
  // ===========================================================================

  /// Future partagé pendant toute la session.
  ///
  /// Cela évite que planning_page.dart et impression_page.dart
  /// téléchargent chacun le planning.
  static Future<String>? _planningEnCours;


  //Rechargement force du planning
  static Future<String> reloadPlanning() async {
    debugPrint(
      '[PlanningService] Rechargement forcé du planning.',
    );

    _planningEnCours = null;

    return loadPlanning();
  }

  // ===========================================================================
  // API PUBLIQUE
  // ===========================================================================

  /// Charge le planning.
  ///
  /// Priorité :
  ///
  /// 1. Firebase si une nouvelle version est disponible
  /// 2. Cache local si la version est identique
  /// 3. Cache local en cas de problème réseau
  /// 4. assets/planning.json si aucun cache n'existe
  static Future<String> loadPlanning() {
    // Si le planning a déjà été chargé pendant cette session,
    // on réutilise le même Future.
    if (_planningEnCours != null) {
      debugPrint(
        '[PlanningService] Réutilisation du planning en mémoire.',
      );

      return _planningEnCours!;
    }

    _planningEnCours = _loadPlanning();

    return _planningEnCours!;
  }

  // ===========================================================================
  // CHARGEMENT PRINCIPAL
  // ===========================================================================

  static Future<String> _loadPlanning() async {
    debugPrint(
      '[PlanningService] Début du chargement du planning.',
    );

    final SharedPreferencesWithCache preferences =
    await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {
          _cacheKey,
        },
      ),
    );

    // =========================================================================
    // 1. FIRESTORE
    // =========================================================================

    try {
      final planning = await _chargerPlanningFirestore();

      _validatePlanningJson(planning);

      // Sauvegarde du planning dans le cache local
      await preferences.setString(
        _cacheKey,
        planning,
      );

      debugPrint(
        '[PlanningService] Planning chargé depuis Firestore '
            'et enregistré dans le cache.',
      );

      return planning;
    } catch (e) {
      debugPrint(
        '[PlanningService] Firestore indisponible : $e',
      );
    }

    // =========================================================================
    // 2. CACHE LOCAL
    // =========================================================================

    try {
      final String? cache =
      preferences.getString(_cacheKey);

      if (cache != null) {
        _validatePlanningJson(cache);

        debugPrint(
          '[PlanningService] Planning chargé depuis le cache local.',
        );

        return cache;
      }
    } catch (e) {
      debugPrint(
        '[PlanningService] Cache local invalide : $e',
      );
    }

    // =========================================================================
    // 3. ASSET DE SECOURS
    // =========================================================================

    try {
      final String planning =
      await rootBundle.loadString(_assetPath);

      _validatePlanningJson(planning);

      debugPrint(
        '[PlanningService] Planning chargé depuis les assets.',
      );

      return planning;
    } catch (e) {
      debugPrint(
        '[PlanningService] Impossible de charger le planning : $e',
      );

      rethrow;
    }
  }

  static Future<bool> verifierNouvelleVersion() async {
    try {
      final String? versionLocale =
      await FirestoreService.recupererVersionPlanning();

      debugPrint(
        '[PlanningService] Version Firestore : '
            '${versionLocale ?? "aucune"}',
      );

      return versionLocale != null;
    } catch (e) {
      debugPrint(
        '[PlanningService] Erreur récupération version Firestore : $e',
      );

      return false;
    }
  }

// ===========================================================================
// SURVEILLANCE DU PLANNING
// ===========================================================================

  static Stream<String?> ecouterVersionPlanning() {
    return FirestoreService.ecouterVersionPlanning();
  }



  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  /// Vérifie que planning.json contient bien une liste JSON.
  ///
  /// le code actuel attend :
  ///
  /// [
  ///   {...},
  ///   {...}
  /// ]
  static void _validatePlanningJson(String jsonString,) {
    final dynamic data = jsonDecode(jsonString);

    if (data is! List) {
      throw const FormatException(
        'planning.json doit contenir une liste JSON.',
      );
    }
  }

  // ===========================================================================
  // RESET POUR LES TESTS
  // ===========================================================================

  /// Réinitialise uniquement le cache en mémoire.
  ///
  /// Utile pendant les tests.
  ///
  /// Cela ne supprime PAS le cache persistant.
  static void reset() {
    _planningEnCours = null;

    debugPrint(
      '[PlanningService] Cache mémoire réinitialisé.',
    );
  }

  /// Supprime complètement le cache persistant.
  ///
  /// Très utile pour tester le "premier lancement".
  static Future<void> clearCache() async {
    final SharedPreferencesWithCache preferences =
    await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {
          _cacheKey,
          _versionKey,
        },
      ),
    );

    await preferences.remove(_cacheKey);
    await preferences.remove(_versionKey);

    _planningEnCours = null;

    debugPrint(
      '[PlanningService] Cache persistant supprimé.',
    );
  }

  // ===========================================================================
  // Publication du planning
  // ===========================================================================

  static String genererJson(List<MatchFoot> matchs,) {
    return jsonEncode(
      matchs.map((match) => match.toJson()).toList(),
    );
  }
}