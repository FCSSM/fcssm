
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import '../models/match.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class ExcelService {
  /// Génère un fichier Excel à partir de la liste des matchs.
static Future<Uint8List> genererExcel({
required List<MatchFoot> matchs,
required String criteres,
}) async  {
    // ==========================================================
    // CRÉATION DU CLASSEUR
    // ==========================================================

    final Workbook workbook = Workbook();

    final Worksheet sheet = workbook.worksheets[0];

    // ==========================================================
// LOGO DU CLUB
// ==========================================================

    final ByteData logoData =
        await rootBundle.load('assets/images/logo_club.png');

    final List<int> logoBytes = logoData.buffer.asUint8List(
      logoData.offsetInBytes,
      logoData.lengthInBytes,
    );

    final String logoBase64 =
    base64Encode(logoBytes);

    final Picture logo = sheet.pictures.addBase64(
      1,
      1,
      logoBase64,
    );

// Taille du logo
    logo.width = 80;
    logo.height = 80;

    sheet.name = 'Planning';

    // ==========================================================
    // TITRE
    // ==========================================================

  // ==========================================================
// TITRE
// ==========================================================

  final Range titre =
  sheet.getRangeByName('C1:J1');

  titre.merge();

  titre.setText(
    'PLANNING DES RENCONTRES',
  );

  titre.cellStyle.fontSize = 18;
  titre.cellStyle.bold = true;
  titre.cellStyle.hAlign =
      HAlignType.center;
  titre.cellStyle.vAlign =
      VAlignType.center;

// ==========================================================
// CRITÈRES DE SÉLECTION
// ==========================================================

  final Range criteresRange =
  sheet.getRangeByName('C2:J2');

  criteresRange.merge();

  criteresRange.setText(
    criteres,
  );

  criteresRange.cellStyle.fontSize = 11;
  criteresRange.cellStyle.italic = true;
  criteresRange.cellStyle.hAlign =
      HAlignType.center;
  criteresRange.cellStyle.vAlign =
      VAlignType.center;

    titre.rowHeight = 30;

    // ==========================================================
    // EN-TÊTES
    // ==========================================================

    final List<String> entetes = [
      'Équipe',
      'Domicile',
      'Date',
      'Heure',
      'Adversaire',
      'Stade',
      'Ville',
      'Phase',
      'Compétition',
      'Semaine',
    ];

    for (int i = 0; i < entetes.length; i++) {
      final Range cellule =
      sheet.getRangeByIndex(3, i + 1);

      cellule.setText(
        entetes[i],
      );

      cellule.cellStyle.bold = true;
      cellule.cellStyle.hAlign =
          HAlignType.center;
      cellule.cellStyle.vAlign =
          VAlignType.center;

      cellule.cellStyle.backColor =
      '#1F4E78';

      cellule.cellStyle.fontColor =
      '#FFFFFF';
    }

    // Hauteur de l'en-tête
    sheet.getRangeByName('A3:J3').rowHeight = 25;

    // ==========================================================
    // MATCHS
    // ==========================================================

    for (int i = 0; i < matchs.length; i++) {
      final MatchFoot match = matchs[i];

      final int ligne = i + 4;

      sheet
          .getRangeByIndex(ligne, 1)
          .setText(match.equipeLocale);

      sheet
          .getRangeByIndex(ligne, 2)
          .setText(
        match.estDomicile
            ? 'Oui'
            : 'Non',
      );

      sheet
          .getRangeByIndex(ligne, 3)
          .setText(match.dateMatch);

      sheet
          .getRangeByIndex(ligne, 4)
          .setText(match.heureMatch);

      sheet
          .getRangeByIndex(ligne, 5)
          .setText(match.equipeAdverse);

      sheet
          .getRangeByIndex(ligne, 6)
          .setText(match.stade);

      sheet
          .getRangeByIndex(ligne, 7)
          .setText(match.ville);

      sheet
          .getRangeByIndex(ligne, 8)
          .setText(match.phase);

      sheet
          .getRangeByIndex(ligne, 9)
          .setText(match.competition);

      sheet
          .getRangeByIndex(ligne, 10)
          .setNumber(
        match.noSemaine.toDouble(),
      );
    }

    // ==========================================================
    // STYLE DES DONNÉES
    // ==========================================================

    if (matchs.isNotEmpty) {
      final int derniereLigne =
          matchs.length + 3;

      final Range donnees =
      sheet.getRangeByName(
        'A4:J$derniereLigne',
      );

      donnees.cellStyle.vAlign =
          VAlignType.center;

      donnees.cellStyle.wrapText = true;

      // Bordures
      donnees.cellStyle.borders.all.lineStyle =
          LineStyle.thin;

      donnees.cellStyle.borders.all.color =
      '#D9D9D9';
    }

    // ==========================================================
    // COULEURS SELON LA VILLE
    // ==========================================================

    for (int i = 0; i < matchs.length; i++) {
      final MatchFoot match = matchs[i];

      final int ligne = i + 4;

      final Range range =
      sheet.getRangeByName(
        'A$ligne:J$ligne',
      );

      final String ville =
      match.ville.toUpperCase();

      if (ville == 'ST SATURNIN') {
        range.cellStyle.backColor =
        '#FFF2CC';
      } else if (ville == 'LA MILESSE') {
        range.cellStyle.backColor =
        '#F4CCCC';
      } else {
        range.cellStyle.backColor =
        '#E7E6E6';
      }
    }

    // ==========================================================
    // LARGEUR DES COLONNES
    // ==========================================================

    sheet.getRangeByName('A1').columnWidth = 20;
    sheet.getRangeByName('B1').columnWidth = 12;
    sheet.getRangeByName('C1').columnWidth = 14;
    sheet.getRangeByName('D1').columnWidth = 10;
    sheet.getRangeByName('E1').columnWidth = 25;
    sheet.getRangeByName('F1').columnWidth = 30;
    sheet.getRangeByName('G1').columnWidth = 20;
    sheet.getRangeByName('H1').columnWidth = 12;
    sheet.getRangeByName('I1').columnWidth = 25;
    sheet.getRangeByName('J1').columnWidth = 10;

    // ==========================================================
    // GEL DE L'EN-TÊTE
    // ==========================================================

    sheet.getRangeByName('A4').freezePanes();

    // ==========================================================
    // TABLEAU EXCEL
    // ==========================================================

    if (matchs.isNotEmpty) {
      final int derniereLigne =
          matchs.length + 3;

      final ExcelTable table =
      sheet.tableCollection.create(
        'PlanningTable',
        sheet.getRangeByName(
          'A3:J$derniereLigne',
        ),
      );

      table.builtInTableStyle =
          ExcelTableBuiltInStyle.tableStyleMedium2;
    }

    // ==========================================================
    // AFFICHAGE
    // ==========================================================

    sheet.showGridlines = false;

    // ==========================================================
    // MISE EN PAGE
    // ==========================================================

    sheet.pageSetup.orientation =
        ExcelPageOrientation.landscape;

    sheet.pageSetup.isCenterHorizontally =
    true;

    // ==========================================================
    // SAUVEGARDE
    // ==========================================================

    final List<int> bytes =
    workbook.saveSync();

    workbook.dispose();

    return Uint8List.fromList(
      bytes,
    );
  }
}