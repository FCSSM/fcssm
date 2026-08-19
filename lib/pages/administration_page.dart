import 'package:excel_community/excel_community.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/excel_import_service.dart';
import '../services/github_service.dart';

class AdministrationPage extends StatefulWidget {
  const AdministrationPage({super.key});

  @override
  State<AdministrationPage> createState() => _AdministrationPageState();
}

class _AdministrationPageState extends State<AdministrationPage> {
  bool isAdmin = false;

  // ---------------------------------------------------------------------------
  // Contrôleurs
  // ---------------------------------------------------------------------------
  final ScrollController _scrollHorizontalController = ScrollController();

  final ScrollController _jsonVerticalController = ScrollController();

  final ScrollController _jsonHorizontalController = ScrollController();

  // ---------------------------------------------------------------------------
  // Informations fichier Excel
  // ---------------------------------------------------------------------------

  String? nomFichier;
  String? nomFeuille;

  int? nombreLignes;
  int? nombreColonnes;

  String? erreur;

  bool structureValide = false;

  List<String> entetes = [];
  List<List<String>> apercu = [];
  List<List<dynamic>> toutesLesLignes = [];

  ExcelImportResult? resultatImport;

  // ---------------------------------------------------------------------------
  // Colonnes attendues dans le fichier Excel
  // ---------------------------------------------------------------------------

  static const List<String> colonnesAttendues = [
    'Equipe locale',
    'Recevant-visiteur',
    'Date du match',
    'Heure du match',
    'Equipe adverse',
    'Nom de l\'installation',
    'Aller-Retour',
    'Localité installation',
    'Compétition / Phase',
    'Numéro match',
    'Club adverse',
    'Reporté-rejoué',
    'Date report',
    'Catégorie équipe locale',
  ];

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _chargerIsAdmin();
  }

  @override
  void dispose() {
    _scrollHorizontalController.dispose();
    _jsonVerticalController.dispose();
    _jsonHorizontalController.dispose();
    super.dispose();
  }

  Future<void> _chargerIsAdmin() async {
    final admin = await AdminService.isAdmin();

    if (!mounted) return;

    setState(() {
      isAdmin = admin;
    });
  }

  // ---------------------------------------------------------------------------
  // Import du fichier Excel
  // ---------------------------------------------------------------------------

  Future<void> importerExcel() async {
    setState(() {
      erreur = null;

      nomFichier = null;
      nomFeuille = null;

      nombreLignes = null;
      nombreColonnes = null;

      structureValide = false;

      entetes = [];
      apercu = [];

      toutesLesLignes = [];

      resultatImport = null;
    });

    try {
      // -----------------------------------------------------------------------
      // Sélection du fichier
      // -----------------------------------------------------------------------

      final fichier = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (!mounted) {
        return;
      }

      if (fichier == null) {
        return;
      }

      // -----------------------------------------------------------------------
      // Lecture du fichier
      // -----------------------------------------------------------------------

      final bytes = await fichier.readAsBytes();

      if (!mounted) {
        return;
      }

      if (bytes.isEmpty) {
        throw Exception('Le fichier Excel est vide.');
      }

      final excel = Excel.decodeBytes(bytes);

      // -----------------------------------------------------------------------
      // Vérification des feuilles
      // -----------------------------------------------------------------------

      if (excel.tables.isEmpty) {
        throw Exception('Le fichier Excel ne contient aucune feuille.');
      }

      // -----------------------------------------------------------------------
      // Première feuille
      // -----------------------------------------------------------------------

      final nomPremiereFeuille = excel.tables.keys.first;

      final feuille = excel.tables[nomPremiereFeuille]!;

      // -----------------------------------------------------------------------
      // Vérification qu'il existe au moins une ligne
      // -----------------------------------------------------------------------

      if (feuille.rows.isEmpty) {
        throw Exception('La feuille Excel est vide.');
      }

      // -----------------------------------------------------------------------
      // Informations générales
      // -----------------------------------------------------------------------

      final int lignes = feuille.maxRows;
      final int colonnes = feuille.maxColumns;

      // -----------------------------------------------------------------------
      // Conservation de toutes les lignes
      // -----------------------------------------------------------------------

      final lignesCompletes = feuille.rows;

      // -----------------------------------------------------------------------
      // Lecture des en-têtes
      // -----------------------------------------------------------------------

      final premiereLigne = feuille.rows.first;

      final List<String> headers = premiereLigne.map((cell) {
        return cell?.value?.toString().trim() ?? '';
      }).toList();

      // -----------------------------------------------------------------------
      // Validation du nombre de colonnes
      // -----------------------------------------------------------------------

      if (headers.length != colonnesAttendues.length) {
        throw Exception(
          'Le fichier contient ${headers.length} colonnes '
          'alors que ${colonnesAttendues.length} sont attendues.',
        );
      }

      // -----------------------------------------------------------------------
      // Validation des noms de colonnes
      // -----------------------------------------------------------------------

      for (int i = 0; i < colonnesAttendues.length; i++) {
        final String attendu = colonnesAttendues[i];
        final String recu = headers[i];

        if (recu != attendu) {
          throw Exception(
            'Colonne ${i + 1} incorrecte.\n\n'
            'Attendu : "$attendu"\n'
            'Trouvé : "$recu"',
          );
        }
      }

      // -----------------------------------------------------------------------
      // Lecture des premières lignes pour aperçu
      // -----------------------------------------------------------------------

      final List<List<String>> lignesApercu = [];

      // La première ligne contient les en-têtes.
      // On affiche au maximum 5 lignes de données.

      final int derniereLigne = feuille.rows.length < 6
          ? feuille.rows.length
          : 6;

      for (int i = 1; i < derniereLigne; i++) {
        final ligne = feuille.rows[i];

        final valeurs = ligne.map((cell) {
          return cell?.value?.toString() ?? '';
        }).toList();

        lignesApercu.add(valeurs);
      }

      // -----------------------------------------------------------------------
      // Tout est correct
      // -----------------------------------------------------------------------

      if (!mounted) {
        return;
      }

      setState(() {
        nomFichier = fichier.name;
        nomFeuille = nomPremiereFeuille;

        nombreLignes = lignes;
        nombreColonnes = colonnes;

        structureValide = true;

        entetes = headers;
        apercu = lignesApercu;

        toutesLesLignes = lignesCompletes;
      });

      // -----------------------------------------------------------------------
      // Debug
      // -----------------------------------------------------------------------

      debugPrint('======================================');
      debugPrint('IMPORT EXCEL');
      debugPrint('======================================');

      debugPrint('Fichier : $nomFichier');
      debugPrint('Feuille : $nomFeuille');
      debugPrint('Lignes : $nombreLignes');
      debugPrint('Colonnes : $nombreColonnes');

      debugPrint('');
      debugPrint('EN-TÊTES :');

      for (int i = 0; i < entetes.length; i++) {
        debugPrint('${i + 1} : ${entetes[i]}');
      }

      debugPrint('');
      debugPrint('PREMIÈRES LIGNES :');

      for (final ligne in apercu) {
        debugPrint(ligne.toString());
      }

      debugPrint('======================================');
    } catch (e, stackTrace) {
      debugPrint('Erreur import Excel : $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        erreur = e.toString();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Analyse du fichier
  // ---------------------------------------------------------------------------

  Future<void> analyserFichier() async {
    if (toutesLesLignes.isEmpty) {
      return;
    }

    final resultat = await ExcelImportService.convertirToutesLesLignes(
      toutesLesLignes,
    );

    setState(() {
      resultatImport = resultat;
    });

    _afficherResultatAnalyse(resultat);
  }

  // ---------------------------------------------------------------------------
  // Affichage résultat analyse
  // ---------------------------------------------------------------------------

  Future<void> _afficherResultatAnalyse(ExcelImportResult resultat) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                resultat.estValide ? Icons.check_circle : Icons.warning,
                color: resultat.estValide ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 10),
              const Text('Analyse du fichier'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${resultat.matchs.length} matchs valides',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (resultat.erreurs.isEmpty)
                  const Row(
                    children: [
                      Icon(Icons.check, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Aucune erreur détectée'),
                    ],
                  )
                else ...[
                  Text(
                    '${resultat.erreurs.length} erreur(s)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final erreur in resultat.erreurs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Ligne ${erreur.ligneExcel} : '
                        '${erreur.message}',
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Afficher JSON
  // ---------------------------------------------------------------------------

  Future<void> afficherJson() async {
    if (resultatImport == null) {
      return;
    }

    if (!resultatImport!.estValide) {
      return;
    }

    final jsonBrut = ExcelImportService.genererJson(resultatImport!.matchs);

    final json = ExcelImportService.dedoublonnerPlanningParNumeroMatch(
      jsonBrut,
    );

    /*
final json = ExcelImportService.genererJson(
resultatImport!.matchs,
);
*/

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Aperçu du JSON'),
          content: SizedBox(
            width: MediaQuery.of(dialogContext).size.width * 0.85,
            height: MediaQuery.of(dialogContext).size.height * 0.75,
            child: Scrollbar(
              controller: _jsonVerticalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _jsonVerticalController,
                child: Scrollbar(
                  controller: _jsonHorizontalController,
                  thumbVisibility: true,
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: _jsonHorizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      json,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Préparer import
  // ---------------------------------------------------------------------------

  void preparerImport() {
    if (resultatImport == null || !resultatImport!.estValide) {
      return;
    }

    final jsonBrut = ExcelImportService.genererJson(resultatImport!.matchs);

    final planningJson = ExcelImportService.dedoublonnerPlanningParNumeroMatch(
      jsonBrut,
    );

    final version = ExcelImportService.genererVersionProvisoire();

    final versionJson = ExcelImportService.genererVersionJson(version);

    debugPrint('======================================');
    debugPrint('IMPORT PRÉPARÉ');
    debugPrint('======================================');

    debugPrint('planning.json :');
    debugPrint(planningJson);

    debugPrint('');
    debugPrint('planning_version.json :');
    debugPrint(versionJson);

    debugPrint('======================================');

    _afficherImportPrepare(planningJson, versionJson);
  }

  // ---------------------------------------------------------------------------
  // Afficher import préparé
  // ---------------------------------------------------------------------------

  Future<void> _afficherImportPrepare(
    String planningJson,
    String versionJson,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Import prêt'),
          content: SizedBox(
            width: MediaQuery.of(dialogContext).size.width * 0.85,
            height: MediaQuery.of(dialogContext).size.height * 0.75,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'planning_version.json',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    versionJson,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'planning.json',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    planningJson,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Mesurer taille planning
  // ---------------------------------------------------------------------------

  Future<void> mesurerTaillePlanning() async {
    if (resultatImport == null || !resultatImport!.estValide) {
      return;
    }

    final jsonBrut = ExcelImportService.genererJson(resultatImport!.matchs);

    final planningJson = ExcelImportService.dedoublonnerPlanningParNumeroMatch(
      jsonBrut,
    );

    final resultat = await ExcelImportService.mesurerTailleJson(planningJson);

    if (!mounted) {
      return;
    }

    final int original = resultat['tailleOriginale'] as int;

    final int compresse = resultat['tailleCompressee'] as int;

    final int base64 = resultat['tailleBase64'] as int;

    final double pourcentage = original == 0 ? 0 : (base64 / original) * 100;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Taille du planning'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Matchs : '
                '${resultatImport!.matchs.length}',
              ),
              const SizedBox(height: 16),
              Text(
                'JSON original : '
                '${_formatOctets(original)}',
              ),
              Text(
                'GZIP : '
                '${_formatOctets(compresse)}',
              ),
              Text(
                'Base64 : '
                '${_formatOctets(base64)}',
              ),
              const SizedBox(height: 16),
              Text(
                'Taille finale : '
                '${pourcentage.toStringAsFixed(1)} % '
                'du JSON original',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Icon(
                base64 < 60000 ? Icons.check_circle : Icons.warning,
                color: base64 < 60000 ? Colors.green : Colors.orange,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                base64 < 60000
                    ? 'Compatible avec notre payload GitHub.'
                    : 'Trop volumineux pour être envoyé '
                          'directement dans client_payload.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Formatage taille
  // ---------------------------------------------------------------------------

  String _formatOctets(int octets) {
    if (octets < 1024) {
      return '$octets octets';
    }

    if (octets < 1024 * 1024) {
      return '${(octets / 1024).toStringAsFixed(1)} Ko';
    }

    return '${(octets / (1024 * 1024)).toStringAsFixed(2)} Mo';
  }

  // ---------------------------------------------------------------------------
  // Demander le token GitHub
  // ---------------------------------------------------------------------------

  Future<String?> demanderTokenGitHub() {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mise à jour GitHub'),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Token GitHub',
              hintText: 'github_pat_...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final token = controller.text.trim();

                if (token.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(token);
              },
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Mettre à jour'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  // ---------------------------------------------------------------------------
  // Publier le planning sur GitHub
  // ---------------------------------------------------------------------------

  Future<void> publierPlanningSurGitHub() async {
    try {
      // -----------------------------------------------------------------------
      // Vérification import
      // -----------------------------------------------------------------------

      if (resultatImport == null) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun planning importé.')),
        );

        return;
      }

      // -----------------------------------------------------------------------
      // Vérification des matchs
      // -----------------------------------------------------------------------

      final matchs = resultatImport!.matchs;

      if (matchs.isEmpty) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Aucun match à publier.')));

        return;
      }

      // -----------------------------------------------------------------------
      // Génération JSON
      // -----------------------------------------------------------------------

      final jsonBrut = ExcelImportService.genererJson(resultatImport!.matchs);

      final planningJson =
          ExcelImportService.dedoublonnerPlanningParNumeroMatch(jsonBrut);

      // -----------------------------------------------------------------------
      // Compression GZIP + Base64
      // -----------------------------------------------------------------------

      final resultat = await ExcelImportService.mesurerTailleJson(planningJson);

      if (!mounted) {
        return;
      }

      final planningBase64 = resultat['base64'] as String;

      final int tailleBase64 = resultat['tailleBase64'] as int;

      // -----------------------------------------------------------------------
      // Vérification taille
      // -----------------------------------------------------------------------

      if (tailleBase64 >= 60000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text(
              'Le planning est trop volumineux pour être envoyé '
              'directement à GitHub.',
            ),
          ),
        );

        return;
      }

      // -----------------------------------------------------------------------
      // Génération version
      // -----------------------------------------------------------------------

      final version = ExcelImportService.genererVersionProvisoire();

      // -----------------------------------------------------------------------
      // Confirmation avant publication
      // -----------------------------------------------------------------------

      final confirmer = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Publier le planning ?'),
            content: SingleChildScrollView(
              child: Text(
                'Version : $version\n\n'
                'Nombre de matchs : ${matchs.length}\n\n'
                'JSON : '
                '${resultat['tailleOriginale']} octets\n'
                'GZIP : '
                '${resultat['tailleCompressee']} octets\n'
                'Base64 : '
                '${resultat['tailleBase64']} caractères',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Annuler'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Publier'),
              ),
            ],
          );
        },
      );

      // -----------------------------------------------------------------------
      // Le dialogue est terminé.
      // Vérification du State avant de continuer.
      // -----------------------------------------------------------------------

      if (!mounted) {
        return;
      }

      if (confirmer != true) {
        return;
      }

      // -----------------------------------------------------------------------
      // Demande du token
      // -----------------------------------------------------------------------

      final token = await demanderTokenGitHub();

      // -----------------------------------------------------------------------
      // Le dialogue du token est terminé.
      // -----------------------------------------------------------------------

      if (!mounted) {
        return;
      }

      if (token == null || token.trim().isEmpty) {
        return;
      }

      // -----------------------------------------------------------------------
      // Envoi à GitHub
      // -----------------------------------------------------------------------

      await GithubService.envoyerPlanning(
        token: token,
        version: version,
        planningBase64: planningBase64,
      );

      // -----------------------------------------------------------------------
      // Vérification après l'appel réseau
      // -----------------------------------------------------------------------

      if (!mounted) {
        return;
      }

      // -----------------------------------------------------------------------
      // Succès
      // -----------------------------------------------------------------------

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Planning envoyé à GitHub avec succès.'),
        ),
      );
    } catch (e) {
      // -----------------------------------------------------------------------
      // Erreur
      // -----------------------------------------------------------------------

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Erreur lors de la publication : $e'),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -----------------------------------------------------------------
            // Titre
            // -----------------------------------------------------------------
            const Text(
              'Import des matchs',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              'Sélectionnez le fichier Excel contenant '
              'le planning des matchs.',
            ),

            const SizedBox(height: 30),

            // -----------------------------------------------------------------
            // Sélection Excel
            // -----------------------------------------------------------------
            FilledButton.icon(
              onPressed: importerExcel,
              icon: const Icon(Icons.upload_file),
              label: const Text('Sélectionner le fichier Excel'),
            ),

            // -----------------------------------------------------------------
            // Analyse
            // -----------------------------------------------------------------
            if (structureValide && toutesLesLignes.isNotEmpty)
              FilledButton.icon(
                onPressed: analyserFichier,
                icon: const Icon(Icons.fact_check),
                label: const Text('Analyser le fichier'),
              ),

            // -----------------------------------------------------------------
            // Afficher JSON
            // -----------------------------------------------------------------
            if (resultatImport != null && resultatImport!.estValide)
              FilledButton.icon(
                onPressed: afficherJson,
                icon: const Icon(Icons.code),
                label: const Text('Afficher le JSON'),
              ),

            // -----------------------------------------------------------------
            // Préparer import
            // -----------------------------------------------------------------
            if (resultatImport != null && resultatImport!.estValide)
              FilledButton.icon(
                onPressed: preparerImport,
                icon: const Icon(Icons.upload_file),
                label: const Text('Préparer l\'import'),
              ),

            // -----------------------------------------------------------------
            // Mesurer taille
            // -----------------------------------------------------------------
            if (resultatImport != null && resultatImport!.estValide)
              FilledButton.icon(
                onPressed: mesurerTaillePlanning,
                icon: const Icon(Icons.compress),
                label: const Text('Mesurer la taille'),
              ),

            // -----------------------------------------------------------------
            // Publier GitHub
            // -----------------------------------------------------------------
            ElevatedButton.icon(
              onPressed: toutesLesLignes.isEmpty
                  ? null
                  : publierPlanningSurGitHub,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Publier sur GitHub'),
            ),

            const SizedBox(height: 30),

            // -----------------------------------------------------------------
            // Informations fichier
            // -----------------------------------------------------------------
            if (nomFichier != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fichier sélectionné',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text('Fichier : $nomFichier'),
                      const SizedBox(height: 5),
                      Text('Feuille : $nomFeuille'),
                      const SizedBox(height: 5),
                      Text('Lignes : $nombreLignes'),
                      const SizedBox(height: 5),
                      Text('Colonnes : $nombreColonnes'),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 15),

            // -----------------------------------------------------------------
            // Validation structure
            // -----------------------------------------------------------------
            if (nomFichier != null && structureValide)
              Card(
                color: Colors.green.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Le format du fichier Excel est valide.',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // -----------------------------------------------------------------
            // Erreur
            // -----------------------------------------------------------------
            if (erreur != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          erreur!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // -----------------------------------------------------------------
            // Colonnes
            // -----------------------------------------------------------------
            if (structureValide && entetes.isNotEmpty) ...[
              const SizedBox(height: 20),

              const Text(
                'Colonnes détectées',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < entetes.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('${i + 1}. ${entetes[i]}'),
                        ),
                    ],
                  ),
                ),
              ),
            ],

            // -----------------------------------------------------------------
            // Aperçu
            // -----------------------------------------------------------------
            if (structureValide && apercu.isNotEmpty) ...[
              const SizedBox(height: 20),

              const Text(
                'Aperçu des premières lignes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Card(
                child: Scrollbar(
                  controller: _scrollHorizontalController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  child: SingleChildScrollView(
                    controller: _scrollHorizontalController,
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        for (final entete in entetes)
                          DataColumn(
                            label: Text(
                              entete,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                      rows: [
                        for (final ligne in apercu)
                          DataRow(
                            cells: [
                              for (int i = 0; i < entetes.length; i++)
                                DataCell(
                                  Text(i < ligne.length ? ligne[i] : ''),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
