import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../models/match.dart';

import 'package:flutter/foundation.dart';

class FirestoreService {
  static final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  static final CollectionReference<Map<String, dynamic>> _matchs =
  _db.collection('matchs');


  // ---------------------------------------------------------------------------
  // Remplace complètement le planning Firestore
  // ---------------------------------------------------------------------------

  static Future<void> remplacerPlanning({
    required String json,
    required String version,
  }) async {
    final dynamic decoded = jsonDecode(json);

    if (decoded is! List) {
      throw Exception(
        'Le planning JSON doit contenir une liste de matchs.',
      );
    }

    // 1. Suppression de l'ancien planning
    await _supprimerTousLesMatchs();

    // 2. Import du nouveau planning
    await _importerMatchs(decoded);

    // 3. Mise à jour de la version
    await mettreAJourVersionPlanning(version);
  }

// ---------------------------------------------------------------------------
  // Suppression de tous les matchs
  // ---------------------------------------------------------------------------

  static Future<void> _supprimerTousLesMatchs() async {
    while (true) {
      final snapshot = await _matchs.limit(450).get();

      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch = _db.batch();

      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }

      await batch.commit();

      debugPrint(
        'Matchs supprimés : ${snapshot.docs.length}',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Import des matchs
  // ---------------------------------------------------------------------------

  static Future<void> _importerMatchs(List<dynamic> matchs,) async {
    const tailleLot = 450;

    for (int debut = 0;
    debut < matchs.length;
    debut += tailleLot) {
      final fin = (debut + tailleLot < matchs.length)
          ? debut + tailleLot
          : matchs.length;

      final batch = _db.batch();

      for (int i = debut; i < fin; i++) {
        final element = matchs[i];

        if (element is! Map) {
          continue;
        }

        final match =
        Map<String, dynamic>.from(element);

        final numeroMatch =
        match['no_match']?.toString().trim();

        // ---------------------------------------------------------------
        // Numéro de match obligatoire
        // ---------------------------------------------------------------

        if (numeroMatch == null ||
            numeroMatch.isEmpty) {
          continue;
        }

        // ---------------------------------------------------------------
        // Le numéro de match devient l'ID Firestore
        // ---------------------------------------------------------------

        final document =
        _matchs.doc(numeroMatch);

        batch.set(document, match);
      }

      await batch.commit();

      debugPrint(
        'Matchs importés : '
            '$debut → ${fin - 1}',
      );
    }
  }

  // ===========================================================================
  // LECTURE
  // ===========================================================================

  static Future<List<MatchFoot>> chargerTousLesMatchs() async {
    final snapshot = await _matchs.get();

    debugPrint(
      '[FirestoreService] Matchs récupérés : ${snapshot.docs.length}',
    );

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return MatchFoot.fromJson(data);
    }).toList();
  }

  static final DocumentReference<Map<String, dynamic>> _planningConfig =
  _db.collection('configuration').doc('planning');

  static Future<void> mettreAJourVersionPlanning(
      String version,
      ) async {
    await _planningConfig.set({
      'version': version,
      'derniere_modification': FieldValue.serverTimestamp(),
    });

    debugPrint(
      'Version planning mise à jour : $version',
    );
  }

  static Future<String?> recupererVersionPlanning() async {
    final document = await _planningConfig.get();

    if (!document.exists) {
      return null;
    }

    final data = document.data();

    return data?['version']?.toString();
  }


  // ---------------------------------------------------------------------------
// MODIFIER UN MATCH + VERSION
// ---------------------------------------------------------------------------

  static Future<void> modifierMatch({
    required MatchFoot match
  }) async {

    final numeroMatch =
    match.numeroMatch.toString().trim();

    if (numeroMatch.isEmpty) {
      throw Exception(
        'Impossible de modifier le match : '
            'numéro de match absent.',
      );
    }

    final matchReference =
    _matchs.doc(numeroMatch);

    final versionReference =
    _db
        .collection('configuration')
        .doc('planning');

    final batch = _db.batch();

    // Mise à jour du match
    batch.set(
      matchReference,
      match.toJson(),
    );

    final version =
    await incrementerVersionPlanning();

    // Mise à jour de la version
    batch.set(
      versionReference,
      {
        'version': version,
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    debugPrint(
      '[FirestoreService] Match $numeroMatch modifié.',
    );

    debugPrint(
      '[FirestoreService] Nouvelle version : $version',
    );
  }

  static Future<void> supprimerMatch({
    required String numeroMatch,
  }) async {

    final noMatch = numeroMatch.trim();

    if (noMatch.isEmpty) {
      throw Exception(
        'Impossible de supprimer le match : '
            'numéro de match absent.',
      );
    }

    final matchReference =
    _matchs.doc(noMatch);

    final versionReference =
    _db
        .collection('configuration')
        .doc('planning');

    // ---------------------------------------------------------------
    // Génération de la nouvelle version
    // ---------------------------------------------------------------

    final version =
    await incrementerVersionPlanning();

    // ---------------------------------------------------------------
    // Batch Firestore
    // ---------------------------------------------------------------

    final batch = _db.batch();

    // Suppression du match
    batch.delete(matchReference);

    // Mise à jour de la version
    batch.set(
      versionReference,
      {
        'version': version,
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    debugPrint(
      '[FirestoreService] Match $noMatch supprimé.',
    );

    debugPrint(
      '[FirestoreService] Nouvelle version : $version',
    );
  }

  static Future<String> ajouterMatch({
    required MatchFoot match,
  }) async {

    // ============================================================
    // Génération du numéro
    // ============================================================

    final numeroMatch =
    await _genererNumeroMatchManuel();

    // ============================================================
    // Référence du nouveau match
    // ============================================================

    final matchReference =
    _matchs.doc(numeroMatch);

    // ============================================================
    // Version du planning
    // ============================================================

    final versionReference =
    _db
        .collection('configuration')
        .doc('planning');

    // ============================================================
    // Affectation du numéro au modèle
    // ============================================================

    match.numeroMatch = numeroMatch;

    // ============================================================
    // Nouvelle version
    // ============================================================

    final version =
    await incrementerVersionPlanning();

    // ============================================================
    // Batch
    // ============================================================

    final batch = _db.batch();

    // Nouveau match
    batch.set(
      matchReference,
      match.toJson(),
    );

    // Nouvelle version
    batch.set(
      versionReference,
      {
        'version': version,
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    debugPrint(
      '[FirestoreService] Match ajouté : $numeroMatch',
    );

    return numeroMatch;
  }
  // ---------------------------------------------------------------------------
// Écoute de la version du planning
// ---------------------------------------------------------------------------

  static Stream<String?> ecouterVersionPlanning() {
    return _db
        .collection('configuration')
        .doc('planning')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();

      return data?['version']?.toString();
    });
  }


  static Future<String> incrementerVersionPlanning() async {

    final versionActuelle = await recupererVersionPlanning();

    final maintenant = DateTime.now();

    final date =
        '${maintenant.year.toString().padLeft(4, '0')}-'
        '${maintenant.month.toString().padLeft(2, '0')}-'
        '${maintenant.day.toString().padLeft(2, '0')}';

    // ----------------------------------------------------------
    // Aucune version existante
    // ----------------------------------------------------------

    if (versionActuelle == null ||
        versionActuelle.isEmpty) {
      return '$date-01';
    }

// ----------------------------------------------------------
// Exemple :
// 2026-08-19-03
// ----------------------------------------------------------

    final morceaux = versionActuelle.split('-');

    if (morceaux.length != 4) {
// Format inattendu
      return '$date-01';
    }

    final ancienneDate =
        '${morceaux[0]}-'
        '${morceaux[1]}-'
        '${morceaux[2]}';

    final ancienNumero =
        int.tryParse(morceaux[3]) ?? 0;

// ----------------------------------------------------------
// Même jour
// ----------------------------------------------------------

    if (ancienneDate == date) {
      final nouveauNumero =
          ancienNumero + 1;

      return '$date-'
          '${nouveauNumero.toString().padLeft(2, '0')}';
    }

// ----------------------------------------------------------
// Nouveau jour
// ----------------------------------------------------------

    return '$date-01';
  }

  static Future<String> _genererNumeroMatchManuel() async {
    final compteurReference = _db
        .collection('configuration')
        .doc('numero_match_manuel');

    return await _db.runTransaction<String>((transaction) async {
      final snapshot =
      await transaction.get(compteurReference);

      int dernierNumero = 0;

      if (snapshot.exists) {
        final data = snapshot.data();

        dernierNumero =
            (data?['dernier_numero'] as num?)?.toInt() ?? 0;
      }

      final nouveauNumero =
          dernierNumero + 1;

      transaction.set(
        compteurReference,
        {
          'dernier_numero': nouveauNumero,
        },
        SetOptions(merge: true),
      );

      final maintenant = DateTime.now();

      final date =
          '${maintenant.year.toString().padLeft(4, '0')}'
          '${maintenant.month.toString().padLeft(2, '0')}'
          '${maintenant.day.toString().padLeft(2, '0')}';

      return 'M-$date-${nouveauNumero.toString().padLeft(3, '0')}';
    });
  }
}



