import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/match.dart';
import 'package:intl/intl.dart';
import '../services/pdf_service.dart';
import 'package:printing/printing.dart';
import '../services/excel_service.dart';
import '../services/file_service.dart';
import 'package:flutter/foundation.dart';
import '../services/planning_service.dart';

class ImpressionPage extends StatefulWidget {
  const ImpressionPage({super.key});

  @override
  State<ImpressionPage> createState() => _ImpressionPageState();
}

class _ImpressionPageState extends State<ImpressionPage> {

  @override
  void initState() {
    super.initState();

    chargerPlanning();
  }

  Uint8List? pdfGenere;

  // --------------------------------------------------
  // TYPE DE PLANNING
  // --------------------------------------------------

  // true  = mensuel
  // false = annuel
  bool modeMensuel = true;

  int moisSelectionne = DateTime.now().month;

  DateTime? convertirDate(String date) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(date);
    } catch (e) {
      debugPrint("Date invalide : $date");
      return null;
    }
  }

  final List<String> mois = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  // --------------------------------------------------
  // LIEU
  // --------------------------------------------------

  // 0 = tous
  // 1 = domicile
  // 2 = extérieur
  int typeLieu = 1;

  // --------------------------------------------------
  // JOUR
  // --------------------------------------------------

  // Pour le moment :
  // true = dimanche uniquement
  // false = tous les jours
  bool dimancheUniquement = true;

  // --------------------------------------------------
  // EQUIPES
  // --------------------------------------------------

  List<Match> tousLesMatchs = [];

  Set<String> equipesSelectionnees = {};

  //final Set<String> equipesSelectionnees = {};


  // ==========================================
  // GETTERS
  // ==========================================

  List<String> get equipesDisponibles {
    return tousLesMatchs
        .map((match) => match.equipeLocale)
        .toSet()
        .toList()
      ..sort();
  }

  List<Match> get matchsFiltres {
    final matchs = tousLesMatchs.where((match) {

      final date = convertirDate(match.dateMatch);

      // Date invalide
      if (date == null) {
        return false;
      }

      // ==========================================
      // FILTRE MENSUEL
      // ==========================================

      if (modeMensuel) {
        if (date.month != moisSelectionne) {
          return false;
        }
      }

      // ==========================================
      // FILTRE DOMICILE
      // ==========================================

      if (typeLieu == 1 && !match.estDomicile) {
        return false;
      }

      // ==========================================
      // FILTRE DIMANCHE
      // ==========================================

      if (dimancheUniquement) {
        if (date.weekday != DateTime.sunday) {
          return false;
        }
      }

      // ==========================================
      // FILTRE EQUIPES
      // ==========================================

      if (equipesSelectionnees.isNotEmpty &&
          !equipesSelectionnees.contains(
            match.equipeLocale,
          )) {
        return false;
      }

      return true;

    }).toList();

    // ==========================================
    // TRI PAR DATE PUIS PAR HEURE
    // ==========================================

    matchs.sort((a, b) {

      // D'abord la date
      final comparaisonDate =
      a.date.compareTo(b.date);

      if (comparaisonDate != 0) {
        return comparaisonDate;
      }

      // Si même date, alors l'heure
      return a.heureEnMinutes
          .compareTo(b.heureEnMinutes);
    });

    return matchs;
  }

  String get criteresExportExcel {
    final List<String> criteres = [];

    // ----------------------------------------------------------
    // LIEU
    // ----------------------------------------------------------

    if (typeLieu == 1) {
      criteres.add('Domicile');
    }

    // ----------------------------------------------------------
    // DIMANCHE
    // ----------------------------------------------------------

    if (dimancheUniquement) {
      criteres.add('Dimanches uniquement');
    }

    // ----------------------------------------------------------
    // MOIS
    // ----------------------------------------------------------

    if (modeMensuel) {
      final List<String> mois = [
        '',
        'Janvier',
        'Février',
        'Mars',
        'Avril',
        'Mai',
        'Juin',
        'Juillet',
        'Août',
        'Septembre',
        'Octobre',
        'Novembre',
        'Décembre',
      ];

      if (moisSelectionne >= 1 &&
          moisSelectionne <= 12) {
        criteres.add(
          mois[moisSelectionne],
        );
      }
    }

    // ----------------------------------------------------------
    // ÉQUIPES
    // ----------------------------------------------------------

    if (equipesSelectionnees.isNotEmpty) {
      criteres.add(
        equipesSelectionnees.join(', '),
      );
    }

    // ----------------------------------------------------------
    // AUCUN FILTRE
    // ----------------------------------------------------------

    if (criteres.isEmpty) {
      return 'Tous les matchs';
    }

    return criteres.join(' • ');
  }

  Future<void> chargerPlanning() async {
    try {
      final String jsonString =
      await PlanningService.loadPlanning();

      final List<Match> matchs =
      (jsonDecode(jsonString) as List)
          .cast<Map<String, dynamic>>()
          .map(Match.fromJson)
          .toList();

      setState(() {
        tousLesMatchs = matchs;
        pdfGenere = null;
      });
    } catch (e) {
      debugPrint("Erreur lors du chargement du planning : $e");
    }
  }


  Future<void> genererPdf() async {
    if (matchsFiltres.isEmpty) {
      return;
    }

    try {
      final bytes = await PdfService.genererPdf(
        matchs: matchsFiltres,
        titre: 'Planning des rencontres',
        sousTitre: modeMensuel
            ? mois[moisSelectionne - 1]
            : 'Toutes les rencontres',
      );

      setState(() {
        pdfGenere = bytes;
      });
    } catch (e) {
      debugPrint('Erreur génération PDF : $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de la génération du PDF : $e',
          ),
        ),
      );
    }
  }

  Future<void> imprimerPdf() async {
    if (matchsFiltres.isEmpty) {
      return;
    }

    try {
      final bytes = pdfGenere ??
          await PdfService.genererPdf(
            matchs: matchsFiltres,
            titre: 'Planning des rencontres',
            sousTitre: modeMensuel
                ? mois[moisSelectionne - 1]
                : 'Toutes les rencontres',
          );

      if (!mounted) return;

      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      debugPrint('Erreur impression PDF : $e');
    }
  }

  Future<void> partagerPdf() async {
    if (matchsFiltres.isEmpty) {
      return;
    }

    try {
      final bytes = pdfGenere ??
          await PdfService.genererPdf(
            matchs: matchsFiltres,
            titre: 'Planning des rencontres',
            sousTitre: modeMensuel
                ? mois[moisSelectionne - 1]
                : 'Toutes les rencontres',
          );

      await PdfService.partagerPdf(
        bytes: bytes,
        nomFichier: 'planning.pdf',
      );
    } catch (e) {
      debugPrint('Erreur partage PDF : $e');
    }
  }

  Future<void> exporterExcel() async {
    if (matchsFiltres.isEmpty) {
      return;
    }

    try {
      final bytes =
      await ExcelService.genererExcel(
        matchs: matchsFiltres,
        criteres: criteresExportExcel,
      );

      debugPrint(
        'Excel généré : ${bytes.length} octets',
      );

      await FileService.partagerExcel(
        bytes: bytes,
        nomFichier: 'planning.xlsx',
      );
    } catch (e) {
      debugPrint(
        'Erreur export Excel : $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de l’export Excel : $e',
          ),
        ),
      );
    }
  }



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
        title: const Text("Impression"),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // ==========================================
            // TYPE DE PLANNING
            // ==========================================

            const Text(
              "Type de planning",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.calendar_month),
                  label: Text("Mensuel"),
                ),

                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.calendar_today),
                  label: Text("Annuel"),
                ),
              ],

              selected: {modeMensuel},

              onSelectionChanged: (Set<bool> selection) {
                setState(() {
                  modeMensuel = selection.first;
                  pdfGenere = null;
                });
              },
            ),

            // ==========================================
            // MOIS
            // ==========================================

            if (modeMensuel) ...[
              const SizedBox(height: 30),

              const Text(
                "Mois",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<int>(
                initialValue: moisSelectionne,

                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.calendar_month,
                  ),
                ),

                items: List.generate(
                  mois.length,
                      (index) {
                    return DropdownMenuItem<int>(
                      value: index + 1,
                      child: Text(mois[index]),
                    );
                  },
                ),

                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    moisSelectionne = value;
                    pdfGenere = null;
                  });
                },
              ),
            ],

            const SizedBox(height: 30),

            const Divider(),

            const SizedBox(height: 20),

            // ==========================================
            // LIEU
            // ==========================================

            const Text(
              "Lieu des matchs",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  label: Text("Tous"),
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: Icon(Icons.home),
                  label: Text("Domicile"),
                ),
              ],

              selected: {typeLieu},

              onSelectionChanged: (Set<int> selection) {
                setState(() {
                  typeLieu = selection.first;
                  pdfGenere = null;
                });
              },
            ),

            // ==========================================
            // JOUR
            // ==========================================

            const Text(
              "Jour des matchs",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,

              value: dimancheUniquement,

              title: const Text(
                "Dimanche uniquement",
              ),

              subtitle: const Text(
                "Afficher uniquement les matchs du dimanche",
              ),

              secondary: const Icon(
                Icons.event,
              ),

              onChanged: (value) {
                setState(() {
                  dimancheUniquement = value ?? false;
                  pdfGenere = null;
                });
              },
            ),

            const SizedBox(height: 20),

            // ==========================================
            // EQUIPES
            // ==========================================

            const Text(
              "Équipes",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Aucune équipe sélectionnée = toutes les équipes",
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 8),

            Card(
              child: equipesDisponibles.isEmpty
                  ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Aucune équipe disponible.",
                ),
              )
                  : Column(
                children: equipesDisponibles.map((equipe) {
                  return CheckboxListTile(
                    title: Text(equipe),

                    value: equipesSelectionnees.contains(equipe),

                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          equipesSelectionnees.add(equipe);
                        } else {
                          equipesSelectionnees.remove(equipe);
                        }
                        pdfGenere = null;
                      });
                    },
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 30),

            const Divider(),

            const SizedBox(height: 20),

            // ==========================================
            // RÉSUMÉ
            // ==========================================

            const Text(
              "Sélection",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      modeMensuel
                          ? "Période : "
                          "${mois[moisSelectionne - 1]}"
                          : "Période : Année complète",
                    ),

                    const SizedBox(height: 8),

                    Text(
                        typeLieu == 0
                            ? "Lieu : Tous"
                            : "Lieu : Domicile",
                    ),

                    const SizedBox(height: 8),

                    Text(
                      dimancheUniquement
                          ? "Jour : Dimanche"
                          : "Jour : Tous les jours",
                    ),

                    const SizedBox(height: 8),

                    Text(
                      equipesSelectionnees.isEmpty
                          ? "Équipes : Toutes"
                          : "Équipes : "
                          "${equipesSelectionnees.join(', ')}",
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.sports_soccer),
                    const SizedBox(width: 12),
                    Text(
                      "${matchsFiltres.length} "
                          "match${matchsFiltres.length > 1 ? 's' : ''} "
                          "correspond${matchsFiltres.length > 1 ? 'ent' : ''} "
                          "à votre sélection.",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Row(
              children: [
                // =====================================================
                // PDF - APERÇU / IMPRESSION
                // =====================================================

                Expanded(
                  child: FilledButton.icon(
                    onPressed: matchsFiltres.isEmpty
                        ? null
                        : imprimerPdf,
                    icon: const Icon(
                      Icons.picture_as_pdf,
                      size: 18,
                    ),
                    label: const Text(
                      'PDF\nAperçu',
                      textAlign: TextAlign.center,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // =====================================================
                // PDF - PARTAGER
                // =====================================================

                if (!kIsWeb) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: matchsFiltres.isEmpty
                          ? null
                          : partagerPdf,
                      icon: const Icon(
                        Icons.share,
                        size: 18,
                      ),
                      label: const Text(
                        'PDF\nPartager',
                        textAlign: TextAlign.center,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),
                ],

                // =====================================================
                // EXCEL
                // =====================================================

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: matchsFiltres.isEmpty
                        ? null
                        : exporterExcel,
                    icon: Icon(
                          Icons.table_chart,
                          size: 18
                    ),
                    label: Text(
                      kIsWeb
                          ? 'Excel'
                          : 'Excel\nPartager',
                      textAlign: TextAlign.center,
                    ),

                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ],
            )

       /*     const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,

              child: FilledButton.icon(

                icon: const Icon(
                  Icons.picture_as_pdf,
                ),

                label: const Text(
                  "Exporter en PDF",
                ),

                onPressed: matchsFiltres.isEmpty
                    ? null
                    : () async {

                  final titre = modeMensuel
                      ? "Planning des rencontres"
                      : "Planning annuel";

                  final sousTitre = modeMensuel
                      ? mois[moisSelectionne - 1]
                      : "Toutes les rencontres";

                  await PdfService.exporterPlanning(
                    matchs: matchsFiltres,
                    titre: titre,
                    sousTitre: sousTitre,
                  );
                },
              ),
            ),*/
          ],
        ),
      ),
    );
  }
}