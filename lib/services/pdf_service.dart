import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/match.dart';

class PdfService {
  // ============================================================
  // CACHE
  // ============================================================

  static pw.MemoryImage? _logo;

  static pw.Font? _fontRegular;
  static pw.Font? _fontBold;

  // ============================================================
  // CHARGEMENT DU LOGO
  // ============================================================

  static Future<pw.MemoryImage?> _chargerLogo() async {
    if (_logo != null) {
      return _logo;
    }

    try {
      final data = await rootBundle.load(
        'assets/images/logo_club.png',
      );

      _logo = pw.MemoryImage(
        data.buffer.asUint8List(),
      );

      return _logo;
    } catch (e) {
      print('PDF : impossible de charger le logo : $e');
      return null;
    }
  }

  // ============================================================
  // CHARGEMENT DES POLICES
  // ============================================================

  static Future<void> _chargerPolices() async {
    if (_fontRegular != null && _fontBold != null) {
      return;
    }

    final regularData = await rootBundle.load(
      'assets/fonts/NotoSans-Regular.ttf',
    );

    final boldData = await rootBundle.load(
      'assets/fonts/NotoSans-Bold.ttf',
    );

    _fontRegular = pw.Font.ttf(
      regularData,
    );

    _fontBold = pw.Font.ttf(
      boldData,
    );
  }

  // ============================================================
  // GÉNÉRATION DU PDF
  // ============================================================

  static Future<Uint8List> genererPdf({
    required List<Match> matchs,
    required String titre,
    required String sousTitre,
  }) async {
    final chrono = Stopwatch()..start();

    print('PDF : début génération');

    // ----------------------------------------------------------
    // Ressources
    // ----------------------------------------------------------

    final logo = await _chargerLogo();

    await _chargerPolices();

    print(
      'PDF : ressources chargées en '
          '${chrono.elapsedMilliseconds} ms',
    );

    // ----------------------------------------------------------
    // Document
    // ----------------------------------------------------------

    final pdf = pw.Document();

    // ----------------------------------------------------------
    // Regroupement par jour
    // ----------------------------------------------------------

    final Map<DateTime, List<Match>> matchsParJour = {};

    for (final match in matchs) {
      final jour = DateTime(
        match.date.year,
        match.date.month,
        match.date.day,
      );

      matchsParJour.putIfAbsent(
        jour,
            () => [],
      );

      matchsParJour[jour]!.add(match);
    }

    // ----------------------------------------------------------
    // Tri des journées
    // ----------------------------------------------------------

    final dates = matchsParJour.keys.toList()
      ..sort();

    // ----------------------------------------------------------
    // Construction du document
    // ----------------------------------------------------------

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,

        margin: const pw.EdgeInsets.fromLTRB(
          30,
          30,
          30,
          25,
        ),

        header: (context) {
          return _entete(
            logo: logo,
            titre: titre,
            sousTitre: sousTitre,
          );
        },

        footer: (context) {
          return _piedDePage(
            context,
          );
        },

        build: (context) {
          final widgets = <pw.Widget>[];

          // ----------------------------------------------------
          // Aucun match
          // ----------------------------------------------------

          if (matchs.isEmpty) {
            widgets.add(
              _messageAucunMatch(),
            );

            return widgets;
          }

          // ----------------------------------------------------
          // Journées
          // ----------------------------------------------------

          for (final date in dates) {
            final matchsDuJour =
            matchsParJour[date]!;

            widgets.add(
              _titreJour(date),
            );

            widgets.add(
              pw.SizedBox(height: 8),
            );

            for (final match in matchsDuJour) {
              widgets.add(
                _matchCard(match),
              );

              widgets.add(
                pw.SizedBox(height: 7),
              );
            }

            widgets.add(
              pw.SizedBox(height: 12),
            );
          }

          return widgets;
        },
      ),
    );

    print(
      'PDF : document construit en '
          '${chrono.elapsedMilliseconds} ms',
    );

    // ----------------------------------------------------------
    // Génération des octets
    // ----------------------------------------------------------

    final bytes = await pdf.save();

    print(
      'PDF : pdf.save() terminé en '
          '${chrono.elapsedMilliseconds} ms',
    );

    print(
      'PDF : taille = '
          '${(bytes.length / 1024).toStringAsFixed(1)} Ko',
    );

    return bytes;
  }


  static Future<void> partagerPdf({
    required Uint8List bytes,
    required String nomFichier,
  }) async {
    await Printing.sharePdf(
      bytes: bytes,
      filename: nomFichier,
    );
  }

  // ============================================================
  // EXPORT + APERÇU / IMPRESSION
  // ============================================================

  static Future<void> exporterPlanning({
    required List<Match> matchs,
    required String titre,
    required String sousTitre,
  }) async {
    final bytes = await genererPdf(
      matchs: matchs,
      titre: titre,
      sousTitre: sousTitre,
    );

    await Printing.layoutPdf(
      onLayout: (format) async {
        return bytes;
      },
    );
  }

  // ============================================================
  // ENTÊTE
  // ============================================================

  static pw.Widget _entete({
    required pw.MemoryImage? logo,
    required String titre,
    required String sousTitre,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(
        bottom: 15,
      ),

      child: pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment:
            pw.CrossAxisAlignment.center,

            children: [
              // Logo
              if (logo != null)
                pw.Container(
                  width: 55,
                  height: 55,

                  margin:
                  const pw.EdgeInsets.only(
                    right: 15,
                  ),

                  child: pw.Image(
                    logo,
                    fit: pw.BoxFit.contain,
                  ),
                ),

              // Titres
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment:
                  pw.CrossAxisAlignment.start,

                  children: [
                    pw.Text(
                      titre,
                      style: pw.TextStyle(
                        font: _fontBold,
                        fontSize: 20,
                      ),
                    ),

                    pw.SizedBox(height: 4),

                    pw.Text(
                      sousTitre,
                      style: pw.TextStyle(
                        font: _fontRegular,
                        fontSize: 11,
                        color:
                        PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 10),

          pw.Container(
            height: 2,
            color: PdfColors.black,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TITRE JOUR
  // ============================================================

  static pw.Widget _titreJour(
      DateTime date,
      ) {
    const jours = [
      'LUNDI',
      'MARDI',
      'MERCREDI',
      'JEUDI',
      'VENDREDI',
      'SAMEDI',
      'DIMANCHE',
    ];

    const mois = [
      'JANVIER',
      'FÉVRIER',
      'MARS',
      'AVRIL',
      'MAI',
      'JUIN',
      'JUILLET',
      'AOÛT',
      'SEPTEMBRE',
      'OCTOBRE',
      'NOVEMBRE',
      'DÉCEMBRE',
    ];

    final texte =
        '${jours[date.weekday - 1]} '
        '${date.day} '
        '${mois[date.month - 1]} '
        '${date.year}';

    return pw.Container(
      width: double.infinity,

      padding: const pw.EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),

      decoration: pw.BoxDecoration(
        color: PdfColors.grey300,

        borderRadius:
        const pw.BorderRadius.all(
          pw.Radius.circular(5),
        ),
      ),

      child: pw.Text(
        texte,
        style: pw.TextStyle(
          font: _fontBold,
          fontSize: 12,
        ),
      ),
    );
  }

  // ============================================================
  // CARTE MATCH
  // ============================================================

  static pw.Widget _matchCard(
      Match match,
      ) {
    final couleur =
    _couleurMatch(match);

    return pw.Container(
      width: double.infinity,

      padding: const pw.EdgeInsets.all(
        10,
      ),

      decoration: pw.BoxDecoration(
        color: couleur,

        border: pw.Border.all(
          color: PdfColors.grey400,
          width: 0.5,
        ),

        borderRadius:
        const pw.BorderRadius.all(
          pw.Radius.circular(5),
        ),
      ),

      child: pw.Row(
        crossAxisAlignment:
        pw.CrossAxisAlignment.start,

        children: [
          // ----------------------------------------------------
          // Heure
          // ----------------------------------------------------

          pw.Container(
            width: 52,

            child: pw.Text(
              match.heureFormatee,

              style: pw.TextStyle(
                font: _fontBold,
                fontSize: 14,
              ),
            ),
          ),

          pw.SizedBox(width: 8),

          // ----------------------------------------------------
          // Informations
          // ----------------------------------------------------

          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment:
              pw.CrossAxisAlignment.start,

              children: [
                // Équipe
                pw.Text(
                  match.equipeLocale,
                  style: pw.TextStyle(
                    font: _fontBold,
                    fontSize: 12,
                  ),
                ),

                pw.SizedBox(height: 2),

                // Adversaire
                pw.Text(
                  'vs ${match.equipeAdverse}',
                  style: pw.TextStyle(
                    font: _fontRegular,
                    fontSize: 11,
                  ),
                ),

                pw.SizedBox(height: 4),

                // Stade / ville
                pw.Text(
                  '${match.stade} - ${match.ville}',
                  style: pw.TextStyle(
                    font: _fontRegular,
                    fontSize: 9,
                    color:
                    PdfColors.grey800,
                  ),
                ),

                pw.SizedBox(height: 2),

                // Compétition
                pw.Text(
                  match.competition,
                  style: pw.TextStyle(
                    font: _fontRegular,
                    fontSize: 8,
                    color:
                    PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),

          // ----------------------------------------------------
          // Domicile
          // ----------------------------------------------------

          if (match.estDomicile)
            pw.Container(
              padding:
              const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),

              decoration:
              const pw.BoxDecoration(
                color: PdfColors.white,

                borderRadius:
                pw.BorderRadius.all(
                  pw.Radius.circular(4),
                ),
              ),

              child: pw.Text(
                'DOMICILE',
                style: pw.TextStyle(
                  font: _fontBold,
                  fontSize: 7,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // COULEUR DU MATCH
  // ============================================================

  static PdfColor _couleurMatch(
      Match match,
      ) {
    switch (match.couleur) {
      case 'jaune':
        return PdfColors.yellow100;

      case 'rouge':
        return PdfColors.red100;

      default:
        return PdfColors.grey200;
    }
  }

  // ============================================================
  // PIED DE PAGE
  // ============================================================

  static pw.Widget _piedDePage(
      pw.Context context,
      ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(
        top: 10,
      ),

      child: pw.Row(
        mainAxisAlignment:
        pw.MainAxisAlignment.spaceBetween,

        children: [
          pw.Text(
            'Planning des rencontres',
            style: pw.TextStyle(
              font: _fontRegular,
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),

          pw.Text(
            'Page ${context.pageNumber} / '
                '${context.pagesCount}',
            style: pw.TextStyle(
              font: _fontRegular,
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AUCUN MATCH
  // ============================================================

  static pw.Widget _messageAucunMatch() {
    return pw.Container(
      width: double.infinity,

      padding: const pw.EdgeInsets.all(
        25,
      ),

      child: pw.Center(
        child: pw.Text(
          'Aucun match ne correspond '
              'aux critères sélectionnés.',
          textAlign: pw.TextAlign.center,

          style: pw.TextStyle(
            font: _fontBold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}