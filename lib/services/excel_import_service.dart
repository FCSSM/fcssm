import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:week_number/iso.dart';
import 'package:excel_community/excel_community.dart';
import 'package:gzip/gzip.dart';
import 'package:flutter/foundation.dart';

class ExcelImportResult {
  final List<Map<String, dynamic>> matchs;
  final List<ExcelImportError> erreurs;

  ExcelImportResult({
    required this.matchs,
    required this.erreurs,
  });

  bool get estValide => erreurs.isEmpty;
}

class ExcelImportError {
  final int ligneExcel;
  final String message;

  ExcelImportError({
    required this.ligneExcel,
    required this.message,
  });

  @override
  String toString() {
    return 'Ligne $ligneExcel : $message';
  }
}

class ExcelImportService {

  static String _formaterDate(
      int annee,
      int mois,
      int jour,
      ) {
    return '${jour.toString().padLeft(2, '0')}/'
        '${mois.toString().padLeft(2, '0')}/'
        '$annee';
  }

  static String _formaterHeureExcel(
      int heure,
      int minute,
      ) {
    return '${heure.toString().padLeft(2, '0')}H'
        '${minute.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Transformation de toutes les lignes Excel
  //
  // La première ligne (index 0) contient les en-têtes.
  // Les données commencent donc à l'index 1.
  // ---------------------------------------------------------------------------

  static ExcelImportResult convertirToutesLesLignes(
      List<List<dynamic>> lignes,
      ) {
    final List<Map<String, dynamic>> matchs = [];
    final List<ExcelImportError> erreurs = [];

    for (int i = 1; i < lignes.length; i++) {
      final ligne = lignes[i];

      // Numéro réel dans Excel :
      //
      // index 0 = en-têtes
      // index 1 = ligne Excel 2
      //
      final numeroLigneExcel = i + 1;

      // Ligne complètement vide
      if (_ligneVide(ligne)) {
        continue;
      }

      try {
      // Une équipe sans adversaire est exempte.
      // On ignore simplement cette ligne.
      final equipeAdverse = _texte(ligne, 4);

      if (equipeAdverse.isEmpty) {
        continue;
      }

      final match = convertirLigne(ligne);

      _validerMatch(
      match,
      numeroLigneExcel,
      );

      matchs.add(match);
      } catch (e) {


        erreurs.add(
          ExcelImportError(
            ligneExcel: numeroLigneExcel,
            message: e.toString(),
          ),
        );
      }
    }

    return ExcelImportResult(
      matchs: matchs,
      erreurs: erreurs,
    );
  }

  // ---------------------------------------------------------------------------
  // Transformation d'une ligne Excel en Map JSON
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> convertirLigne(
      List<dynamic> ligne,
      ) {
    final equipeLocale = _texte(ligne, 0);
    final recevantVisiteur = _texte(ligne, 1);
    final dateMatch = _texte(ligne, 2);
    final heureMatch = _texte(ligne, 3);
    final equipeAdverse = _texte(ligne, 4);
    final installation = _texte(ligne, 5);
    final allerRetour = _texte(ligne, 6);
    final localite = _texte(ligne, 7);
    final competition = _texte(ligne, 8);
    final numeroMatch = _texte(ligne, 9);
    final clubAdverse = _texte(ligne, 10);
    final reporteRejoue = _texte(ligne, 11);
    final dateReport = _texte(ligne, 12);
    final categorie = _texte(ligne, 13);

    return {
      'equipe_locale': _determinerEquipeLocale(
        equipeLocale,
        categorie,
      ),

      'recevant': _determinerRecevant(
        recevantVisiteur,
      ),

      'date_match': dateMatch,

      'heure_match': _formaterHeure(
        heureMatch,
      ),

      'equipe_adverse': equipeAdverse,

      'stade': installation,

      'phase': allerRetour,

      'ville': localite,

      'competition': competition,

      'no_semaine': _calculerNumeroSemaine(
        dateMatch,
      ),

     // 'no_semaine': '33',

      'no_match': numeroMatch,

      'club_adverse': clubAdverse,

      'report': reporteRejoue,

      'date_report': dateReport,
    };
  }

  // ---------------------------------------------------------------------------
  // Validation d'un match
  // ---------------------------------------------------------------------------

  static void _validerMatch(
      Map<String, dynamic> match,
      int numeroLigneExcel,
      ) {
    final equipeLocale =
        match['equipe_locale']?.toString().trim() ?? '';

    final dateMatch =
        match['date_match']?.toString().trim() ?? '';

    final equipeAdverse =
        match['equipe_adverse']?.toString().trim() ?? '';

    final numeroMatch =
        match['no_match']?.toString().trim() ?? '';

    if (equipeLocale.isEmpty) {
      throw Exception(
        'Équipe locale impossible à déterminer.',
      );
    }

    if (dateMatch.isEmpty) {
      throw Exception(
        'Date du match absente.',
      );
    }

    if (match['no_semaine'] == null) {
      throw Exception(
        'Date du match invalide : "$dateMatch".',
      );
    }

    if (equipeAdverse.isEmpty) {
      throw Exception(
        'Équipe adverse absente.',
      );
    }


    if (numeroMatch.isEmpty) {
      throw Exception(
        'Numéro de match absent.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Vérification d'une ligne vide
  // ---------------------------------------------------------------------------

  static bool _ligneVide(
      List<dynamic> ligne,
      ) {
    for (int i = 0; i < ligne.length; i++) {
      if (_texte(ligne, i).isNotEmpty) {
        return false;
      }
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Récupération d'une cellule sous forme de texte
  // ---------------------------------------------------------------------------

  static String _texte(
      List<dynamic> ligne,
      int index,
      ) {
    if (index >= ligne.length) {
      return '';
    }

    final cellule = ligne[index];

    if (cellule == null) {
      return '';
    }

    final valeur = cellule.value;

    if (valeur == null) {
      return '';
    }

    switch (valeur) {
      case TextCellValue():
        return valeur.value.toString().trim();

      case IntCellValue():
        return valeur.value.toString();

      case DoubleCellValue():
        return valeur.value.toString();

      case BoolCellValue():
        return valeur.value.toString();

      case DateCellValue():
        return _formaterDate(
          valeur.year,
          valeur.month,
          valeur.day,
        );

      case DateTimeCellValue():
        return _formaterDate(
          valeur.year,
          valeur.month,
          valeur.day,
        );

      case TimeCellValue():
        return _formaterHeureExcel(
          valeur.hour,
          valeur.minute,
        );

      case FormulaCellValue():
        return valeur.formula;
    }

    // Sécurité : permet de garantir qu'un String est toujours retourné.
    return '';
  }
  // ---------------------------------------------------------------------------
  // Equipe locale
  // ---------------------------------------------------------------------------

  static String _determinerEquipeLocale(
      String equipeLocale,
      String categorie,
      ) {
    final categorieNormalisee = categorie.trim();

    // Numéro à la fin du nom de l'équipe
    final matchNumero = RegExp(r'(\d+)\s*$').firstMatch(equipeLocale);

    final numero = matchNumero != null
        ? int.tryParse(matchNumero.group(1)!)
        : null;

    // ------------------------------------------------------------
    // SENIORS
    // ------------------------------------------------------------
    if (categorieNormalisee.contains('Senior F')) {
      return 'Seniors F';
    }

    if (categorieNormalisee.contains('Libre / Senior')) {
      if (numero == null) {
        return 'Seniors';
      }

      // 1, 2, 3 => Seniors A, B, C
      if (numero >= 1 && numero <= 3) {
        return 'Seniors ${_numeroVersLettre(numero)}';
      }

      // 31, 32 => Vétéran A, B
      if (numero >= 31 && numero <= 56) {
        return 'Vétéran ${_numeroVersLettre(numero - 30)}';
      }

      return 'Seniors';
    }

    // ------------------------------------------------------------
    // U19 / U18
    // ------------------------------------------------------------
    if (categorieNormalisee.contains('U19 - U18')) {
      // Les équipes 21 et 1 correspondent à U18
      return 'U18';
    }

    // ------------------------------------------------------------
    // U17 / U16
    // ------------------------------------------------------------
    if (categorieNormalisee.contains('U17 - U16')) {
      return 'U17';
    }

    // ------------------------------------------------------------
    // U15 / U14
    // ------------------------------------------------------------
    if (categorieNormalisee.contains('U15 - U14')) {
      if (numero == null) {
        return 'U15';
      }

      // 1, 2 => U15 A / B
      if (numero >= 1 && numero <= 2) {
        return 'U15 ${_numeroVersLettre(numero)}';
      }

      // 21 ou 3 => U14
      if (numero == 21 || numero == 3) {
        return 'U14';
      }

      return 'U15';
    }

    // ------------------------------------------------------------
    // U13 / U12
    // ------------------------------------------------------------
    if (categorieNormalisee.contains('U13 - U12')) {
      if (numero == null) {
        return 'U13';
      }

      // 1, 2 => U13 A / B
      if (numero >= 1 && numero <= 2) {
        return 'U13 ${_numeroVersLettre(numero)}';
      }

      // 21 => U12
      if (numero == 21) {
        return 'U12';
      }

      return 'U13';
    }

    // ------------------------------------------------------------
    // U13 F / U12 F
    // ------------------------------------------------------------
    if (categorieNormalisee.contains('U13 F - U12 F')) {
      return 'U13 F';
    }

    // ------------------------------------------------------------
    // U15 F / U14 F
    // ------------------------------------------------------------
    if (categorieNormalisee.contains('U15 F - U14 F')) {
      return 'U15 F';
    }

    // ------------------------------------------------------------
    // Cas non reconnu
    // ------------------------------------------------------------
    return _nettoyerCategorie(categorieNormalisee);
  }


  static String _nettoyerCategorie(String categorie) {
    if (categorie.contains('/')) {
      return categorie.split('/').last.trim();
    }

    return categorie.trim();
  }

  // ---------------------------------------------------------------------------
  // 1 = A, 2 = B, 3 = C...
  // ---------------------------------------------------------------------------

  static String _numeroVersLettre(
      int numero,
      ) {
    if (numero < 1 || numero > 26) {
      return numero.toString();
    }

    return String.fromCharCode(
      'A'.codeUnitAt(0) + numero - 1,
    );
  }

  // ---------------------------------------------------------------------------
  // Recevant / Visiteur
  // ---------------------------------------------------------------------------

  static String _determinerRecevant(
      String valeur,
      ) {
    if (valeur.trim().toLowerCase() == 'recevant') {
      return 'oui';
    }

    return 'non';
  }

  // ---------------------------------------------------------------------------
  // Heure
  // ---------------------------------------------------------------------------

  static String _formaterHeure(
      String heure,
      ) {
    if (heure.isEmpty) {
      return '';
    }

    final valeur = heure.trim().toUpperCase();

    final match = RegExp(
      r'^(\d{1,2})H(\d{2})?$',
    ).firstMatch(valeur);

    if (match == null) {
      return valeur;
    }

    final heures = int.parse(
      match.group(1)!,
    );

    final minutes = match.group(2) ?? '00';

    return '${heures.toString().padLeft(2, '0')}H$minutes';
  }

  // ---------------------------------------------------------------------------
  // Numéro de semaine ISO
  // ---------------------------------------------------------------------------

  static int? _calculerNumeroSemaine(
      String date,
      ) {
    if (date.isEmpty) {
      return null;
    }
/*
    final match = RegExp(
      r'^(\d{2})/(\d{2})/(\d{4})$',
    ).firstMatch(date);

    if (match == null) {
      return null;
    }

    final jour = int.parse(
      match.group(1)!,
    );

    final mois = int.parse(
      match.group(2)!,
    );

    final annee = int.parse(
      match.group(3)!,
    );

    final dateTime = DateTime(
      annee,
      mois,
      jour,
    );
*/
    final dateTime= DateFormat('dd/MM/yyyy').parseStrict(date);
    return dateTime.weekNumber;
  }

  // ---------------------------------------------------------------------------
  // Génération du JSON
  // ---------------------------------------------------------------------------
  static String? _normaliserDateReport(
      dynamic valeur,
      ) {
    if (valeur == null) {
      return null;
    }

    final texte = valeur.toString().trim();

    if (texte.isEmpty) {
      return null;
    }

    return texte;
  }

  static DateTime? _parserDate(
      String valeur,
      ) {
    // -------------------------------------------------------------------------
    // Format ISO :
    //
    // 2026-09-15
    // 2026-09-15T00:00:00
    //
    // -------------------------------------------------------------------------

    final iso = DateTime.tryParse(valeur);

    if (iso != null) {
      return iso;
    }

    // -------------------------------------------------------------------------
    // Format français :
    //
    // 15/09/2026
    // 15-09-2026
    //
    // -------------------------------------------------------------------------

    final match = RegExp(
      r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$',
    ).firstMatch(valeur);

    if (match != null) {
      final jour = int.tryParse(match.group(1)!);
      final mois = int.tryParse(match.group(2)!);
      final annee = int.tryParse(match.group(3)!);

      if (jour != null &&
          mois != null &&
          annee != null) {
        return DateTime(
          annee,
          mois,
          jour,
        );
      }
    }

    return null;
  }

  static String dedoublonnerPlanningParNumeroMatch(
      String json,
      ) {
    final dynamic decoded = jsonDecode(json);

    if (decoded is! List) {
      throw Exception(
        'Le planning JSON doit contenir une liste de matchs.',
      );
    }

    // -------------------------------------------------------------------------
    // Matchs avec numéro de match
    // -------------------------------------------------------------------------

    final Map<String, Map<String, dynamic>> matchsAvecNumero = {};

    // -------------------------------------------------------------------------
    // Matchs sans numéro
    // -------------------------------------------------------------------------

    final List<Map<String, dynamic>> matchsSansNumero = [];

    int doublons = 0;

    for (final element in decoded) {
      if (element is! Map) {
        continue;
      }

      final match = Map<String, dynamic>.from(element);

      final noMatch = match['no_match'];

      // -----------------------------------------------------------------------
      // Aucun numéro de match
      // -----------------------------------------------------------------------
      //
      // IMPORTANT :
      // Un match sans no_match n'est jamais considéré comme un doublon.
      //
      if (noMatch == null ||
          noMatch.toString().trim().isEmpty) {
        matchsSansNumero.add(match);
        continue;
      }

      final numero = noMatch.toString().trim();

      // -----------------------------------------------------------------------
      // Premier match avec ce numéro
      // -----------------------------------------------------------------------

      if (!matchsAvecNumero.containsKey(numero)) {
        matchsAvecNumero[numero] = match;
        continue;
      }

      // -----------------------------------------------------------------------
      // Doublon
      // -----------------------------------------------------------------------

      doublons++;

      final matchExistant = matchsAvecNumero[numero]!;

      final String? dateReportExistante =
      _normaliserDateReport(
        matchExistant['date_report'],
      );

      final String? dateReportNouvelle =
      _normaliserDateReport(
        match['date_report'],
      );

      // -----------------------------------------------------------------------
      // Nouvelle ligne avec date_report
      // -----------------------------------------------------------------------

      if (dateReportNouvelle != null) {

        // L'ancienne n'a pas de date_report.
        //
        // La nouvelle est donc prioritaire.
        //
        if (dateReportExistante == null) {
          matchsAvecNumero[numero] = match;
          continue;
        }

        // ---------------------------------------------------------------------
        // Les deux ont une date_report
        // ---------------------------------------------------------------------

        final ancienneDate =
        _parserDate(dateReportExistante);

        final nouvelleDate =
        _parserDate(dateReportNouvelle);

        if (ancienneDate == null ||
            nouvelleDate == null) {
          // Si une date ne peut pas être interprétée,
          // on conserve la nouvelle occurrence.
          matchsAvecNumero[numero] = match;
          continue;
        }

        if (nouvelleDate.isAfter(ancienneDate)) {
          matchsAvecNumero[numero] = match;
        }

        continue;
      }

      // -----------------------------------------------------------------------
      // Nouvelle ligne sans date_report
      // -----------------------------------------------------------------------
      //
      // Si l'ancienne possède une date_report,
      // elle reste prioritaire.
      //
      if (dateReportExistante != null) {
        continue;
      }

      // -----------------------------------------------------------------------
      // Aucune des deux lignes n'a de date_report.
      //
      // On conserve la dernière occurrence.
      // -----------------------------------------------------------------------

      matchsAvecNumero[numero] = match;
    }

    // -------------------------------------------------------------------------
    // Reconstruction du planning
    // -------------------------------------------------------------------------

    final List<Map<String, dynamic>> matchsFinaux = [
      ...matchsAvecNumero.values,
      ...matchsSansNumero,
    ];

    // -------------------------------------------------------------------------
    // Statistiques
    // -------------------------------------------------------------------------

    debugPrint('======================================');
    debugPrint('DEDOUBLONNAGE PLANNING');
    debugPrint('======================================');

    debugPrint(
      'Matchs reçus       : ${decoded.length}',
    );

    debugPrint(
      'Matchs avec numéro : ${matchsAvecNumero.length}',
    );

    debugPrint(
      'Matchs sans numéro : ${matchsSansNumero.length}',
    );

    debugPrint(
      'Doublons supprimés : $doublons',
    );

    debugPrint(
      'Matchs finaux      : ${matchsFinaux.length}',
    );

    debugPrint('======================================');

    return const JsonEncoder.withIndent('  ').convert(
      matchsFinaux,
    );
  }



  static String genererJson(
      List<Map<String, dynamic>> matchs,
      ) {
    const encoder = JsonEncoder.withIndent('  ');

    return encoder.convert(matchs);
  }

  static String genererVersionJson(String version) {
    const encoder = JsonEncoder.withIndent('  ');

    return encoder.convert({
      'version': version,
    });
  }

  static String genererVersionProvisoire() {
    final maintenant = DateTime.now();

    final date =
        '${maintenant.year.toString().padLeft(4, '0')}-'
        '${maintenant.month.toString().padLeft(2, '0')}-'
        '${maintenant.day.toString().padLeft(2, '0')}';

    return '$date-01';
  }

  static Future<Map<String, dynamic>> mesurerTailleJson(
      String planningJson,
      ) async {
    // Taille du JSON original en UTF-8
    final bytes = utf8.encode(planningJson);

    // Compression GZIP
    final gzipCompressor = GZip();

    final compressedBytes = await gzipCompressor.compress(
      Uint8List.fromList(bytes),
    );

    // Base64 augmente légèrement la taille,
    // mais c'est nécessaire pour transporter les données
    // dans un JSON / client_payload.
    final base64String = base64Encode(compressedBytes);

    return {
      'tailleOriginale': bytes.length,
      'tailleCompressee': compressedBytes.length,
      'tailleBase64': base64String.length,
      'base64': base64String,
    };
  }
}