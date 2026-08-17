import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


class PlanningService {
  // ===========================================================================
  // CONFIGURATION
  // ===========================================================================

  /// URL du planning sur GitHub.
  static const String _planningUrl =
      'https://raw.githubusercontent.com/fcssm/planning-fcssm//main/planning.json';

  /// URL du fichier indiquant la version du planning.
  static const String _versionUrl =
      'https://raw.githubusercontent.com/fcssm/planning-fcssm//main/planning_version.json';

  /// Asset embarqué dans l'application.
  static const String _assetPath = 'assets/planning.json';

  /// Clés utilisées dans le stockage local.
  static const String _cacheKey = 'planning_json';
  static const String _versionKey = 'planning_version';

  /// Durée maximale d'une requête réseau.
  static const Duration _networkTimeout =
  Duration(seconds: 5);

  // ===========================================================================
  // CHARGEMENT EN MÉMOIRE
  // ===========================================================================

  /// Future partagé pendant toute la session.
  ///
  /// Cela évite que planning_page.dart et impression_page.dart
  /// téléchargent chacun le planning.
  static Future<String>? _planningEnCours;

  // ===========================================================================
  // API PUBLIQUE
  // ===========================================================================

  /// Charge le planning.
  ///
  /// Priorité :
  ///
  /// 1. GitHub si une nouvelle version est disponible
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
          _versionKey,
        },
      ),
    );

    // -------------------------------------------------------------------------
    // 1. Lire la version locale
    // -------------------------------------------------------------------------

    String? versionLocale;

    try {
      versionLocale = preferences.getString(_versionKey);
      debugPrint(
        '[PlanningService] Version locale : '
            '${versionLocale ?? "aucune"}',
      );
    } catch (e) {
      debugPrint(
        '[PlanningService] Impossible de lire la version locale : $e',
      );
    }

    // -------------------------------------------------------------------------
    // 2. Récupérer la version GitHub
    // -------------------------------------------------------------------------

    String? versionGitHub;

    try {
      versionGitHub = await _getRemoteVersion();

      debugPrint(
        '[PlanningService] Version GitHub : $versionGitHub',
      );
    } catch (e) {
      debugPrint(
        '[PlanningService] Impossible de récupérer la version GitHub : $e',
      );
    }

    // -------------------------------------------------------------------------
    // 3. Version identique → utiliser directement le cache
    // -------------------------------------------------------------------------

    if (versionGitHub != null &&
        versionLocale != null &&
        versionGitHub == versionLocale) {
      debugPrint(
        '[PlanningService] Version identique → utilisation du cache.',
      );

      try {
        final String? cache = preferences.getString(_cacheKey);

        if (cache != null) {
          _validatePlanningJson(cache);

          debugPrint(
            '[PlanningService] Planning chargé depuis le cache.',
          );

          return cache;
        }

        debugPrint(
          '[PlanningService] Version identique mais cache absent.',
        );
      } catch (e) {
        debugPrint(
          '[PlanningService] Cache invalide : $e',
        );
      }
    }

    // -------------------------------------------------------------------------
    // 4. Nouvelle version → télécharger planning.json
    // -------------------------------------------------------------------------

    if (versionGitHub != null &&
        (versionLocale == null ||
            versionGitHub != versionLocale)) {
      debugPrint(
        '[PlanningService] Nouvelle version détectée '
            '($versionLocale → $versionGitHub).',
      );

      try {
        final String planning =
        await _downloadPlanning();

        _validatePlanningJson(planning);

        // Le JSON est valide.
        // On peut maintenant remplacer le cache.
        await preferences.setString(
          _cacheKey,
          planning,
        );

        await preferences.setString(
          _versionKey,
          versionGitHub,
        );

        debugPrint(
          '[PlanningService] Nouveau planning téléchargé '
              'et enregistré dans le cache.',
        );

        return planning;
      } catch (e) {
        debugPrint(
          '[PlanningService] Échec du téléchargement '
              'du nouveau planning : $e',
        );
      }
    }

    // -------------------------------------------------------------------------
    // 5. Version GitHub indisponible
    //
    // On tente quand même de télécharger directement planning.json.
    // -------------------------------------------------------------------------

    if (versionGitHub == null) {
      debugPrint(
        '[PlanningService] Version GitHub indisponible. '
            'Tentative directe de téléchargement du planning.',
      );

      try {
        final String planning =
        await _downloadPlanning();

        _validatePlanningJson(planning);

        await preferences.setString(
          _cacheKey,
          planning,
        );

        debugPrint(
          '[PlanningService] Planning téléchargé directement '
              'depuis GitHub.',
        );

        return planning;
      } catch (e) {
        debugPrint(
          '[PlanningService] Téléchargement direct impossible : $e',
        );
      }
    }

    // -------------------------------------------------------------------------
    // 6. Fallback : cache local
    // -------------------------------------------------------------------------

    debugPrint(
      '[PlanningService] Tentative de chargement depuis le cache local.',
    );

    try {
      final String? cache = preferences.getString(_cacheKey);

      if (cache != null) {
        _validatePlanningJson(cache);

        debugPrint(
          '[PlanningService] Planning chargé depuis le cache local.',
        );

        return cache;
      }
    } catch (e) {
      debugPrint(
        '[PlanningService] Cache local indisponible ou invalide : $e',
      );
    }

    // -------------------------------------------------------------------------
    // 7. Fallback ultime : assets/planning.json
    // -------------------------------------------------------------------------

    debugPrint(
      '[PlanningService] Aucun cache disponible. '
          'Chargement depuis $_assetPath.',
    );

    try {
      final String assetPlanning =
      await rootBundle.loadString(_assetPath);

      _validatePlanningJson(assetPlanning);

      // Initialiser le cache.
      await preferences.setString(
        _cacheKey,
        assetPlanning,
      );

      // Si nous connaissons la version GitHub,
      // on la sauvegarde également.
      if (versionGitHub != null) {
        await preferences.setString(
          _versionKey,
          versionGitHub,
        );
      }

      debugPrint(
        '[PlanningService] Planning chargé depuis les assets '
            'et enregistré dans le cache.',
      );

      return assetPlanning;
    } catch (e) {
      debugPrint(
        '[PlanningService] Impossible de charger $_assetPath : $e',
      );

      rethrow;
    }
  }

  // ===========================================================================
  // INTERNET
  // ===========================================================================

  /// Récupère la version publiée sur GitHub.
  ///
  /// Format attendu :
  ///
  /// {
  ///   "version": "2026-08-13-01"
  /// }
  static Future<String> _getRemoteVersion() async {
    final response = await http
        .get(Uri.parse(_versionUrl))
        .timeout(_networkTimeout);

    if (response.statusCode != 200) {
      throw HttpException(
        'Erreur HTTP ${response.statusCode} '
            'pour $_versionUrl',
      );
    }

    final dynamic data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'planning_version.json doit contenir un objet JSON.',
      );
    }

    final dynamic version = data['version'];

    if (version is! String || version.trim().isEmpty) {
      throw const FormatException(
        'Le champ "version" est absent ou invalide.',
      );
    }

    return version.trim();
  }

  /// Télécharge planning.json depuis GitHub.
  static Future<String> _downloadPlanning() async {
    final response = await http
        .get(Uri.parse(_planningUrl))
        .timeout(_networkTimeout);

    if (response.statusCode != 200) {
      throw HttpException(
        'Erreur HTTP ${response.statusCode} '
            'pour $_planningUrl',
      );
    }

    return response.body;
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  /// Vérifie que planning.json contient bien une liste JSON.
  ///
  /// Ton code actuel attend :
  ///
  /// [
  ///   {...},
  ///   {...}
  /// ]
  static void _validatePlanningJson(
      String jsonString,
      ) {
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
}