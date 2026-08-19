import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

class GithubService {
// ---------------------------------------------------------------------------
// Configuration du repository GitHub
// ---------------------------------------------------------------------------

static const String _owner = 'FCSSM';
static const String _repository = 'planning-fcssm';

// Version de l'API GitHub utilisée.
static const String _apiVersion = '2026-03-10';


  static Future<String?> recupererVersion() async {
    final response = await http.get(
      Uri.parse(
        'https://api.github.com/repos/'
            'fcssm/planning-fcssm/contents/planning_version.json',
          /// URL du fichier indiquant la version du planning.
      //   static const String _versionUrl =
       //   'https://raw.githubusercontent.com/fcssm/planning-fcssm//main/planning_version.json';

      ),
      headers: {
        'Accept':
        'application/vnd.github+json',
      },
    );

    if (response.statusCode != 200) {
      debugPrint(
        'Erreur récupération version GitHub : '
            '${response.statusCode}',
      );

      return null;
    }

    final data =
    jsonDecode(response.body)
    as Map<String, dynamic>;

    final content =
    data['content'] as String;

    final contenuDecode =
    utf8.decode(
      base64Decode(
        content.replaceAll('\n', ''),
      ),
    );

    final json =
    jsonDecode(contenuDecode)
    as Map<String, dynamic>;

    return json['version'] as String?;
  }



// ---------------------------------------------------------------------------
// Envoi du planning à GitHub Actions
// ---------------------------------------------------------------------------

/// Envoie le planning compressé à GitHub Actions.
///
/// Le token GitHub est fourni par l'administrateur au moment de l'appel.
///
/// IMPORTANT :
/// - Aucun token n'est stocké dans cette classe.
/// - Aucun token n'est présent dans le code source.
/// - Le token doit être un Fine-grained Personal Access Token.
/// - Pour ce repository, la permission nécessaire est :
///     Contents -> Read and write
///
/// GitHub déclenche ensuite le workflow via :
///     repository_dispatch
///
/// avec :
///     event_type = import_planning
///
/// et :
///     client_payload.version
///     client_payload.planning
static Future<void> envoyerPlanning({
required String token,
required String version,
required String planningBase64,
}) async {
// -------------------------------------------------------------------------
// Vérifications locales
// -------------------------------------------------------------------------

final tokenNettoye = token.trim();

if (tokenNettoye.isEmpty) {
throw Exception(
'Le token GitHub est vide.',
);
}

if (version.trim().isEmpty) {
throw Exception(
'La version du planning est vide.',
);
}

if (planningBase64.trim().isEmpty) {
throw Exception(
'Le planning compressé est vide.',
);
}

// -------------------------------------------------------------------------
// URL GitHub API
// -------------------------------------------------------------------------

final uri = Uri.parse(
'https://api.github.com/repos/'
'$_owner/$_repository/dispatches',
);

// -------------------------------------------------------------------------
// Données envoyées à GitHub Actions
// -------------------------------------------------------------------------

final body = <String, dynamic>{
'event_type': 'import_planning',
'client_payload': {
'version': version,
'planning': planningBase64,
},
};

// -------------------------------------------------------------------------
// Appel GitHub
// -------------------------------------------------------------------------

late final http.Response response;

try {
response = await http.post(
uri,
headers: {
'Accept': 'application/vnd.github+json',
'Authorization': 'Bearer $tokenNettoye',
'X-GitHub-Api-Version': _apiVersion,
'Content-Type': 'application/json',
},
body: jsonEncode(body),
);
} catch (e) {
throw Exception(
'Impossible de contacter GitHub : $e',
);
}

// -------------------------------------------------------------------------
// Vérification de la réponse
// -------------------------------------------------------------------------

if (response.statusCode == 204) {
// GitHub a accepté le repository_dispatch.
return;
}

// -------------------------------------------------------------------------
// Gestion des erreurs GitHub
// -------------------------------------------------------------------------

String message;

switch (response.statusCode) {
case 401:
message =
'Token GitHub invalide ou expiré.';
break;

case 403:
message =
'Accès refusé par GitHub. '
'Vérifiez les permissions du token '
'(Contents → Read and write).';
break;

case 404:
message =
'Repository GitHub introuvable ou inaccessible.';
break;

case 422:
message =
'GitHub a refusé les données envoyées '
'(payload invalide ou trop volumineux).';
break;

default:
message =
'Erreur GitHub (${response.statusCode}).';
}

// -------------------------------------------------------------------------
// IMPORTANT :
// Ne jamais afficher le token dans le message d'erreur.
// -------------------------------------------------------------------------

final details = response.body.trim();

if (details.isNotEmpty) {
throw Exception(
'$message\n'
'Réponse GitHub : $details',
);
}

throw Exception(message);
}
}


/*import 'dart:convert';

import 'package:http/http.dart' as http;

class GithubService {
  static const String _owner = 'FCSSM';
  static const String _repository = 'planning-fcssm';

  // ⚠️ Remplace cette valeur par TON PAT.
  // Ne me l'envoie pas.
  static const String _token = 'github_pat_xxxxxxxx';

  static const String _apiVersion = '2026-03-10';

  /// Envoie le planning compressé à GitHub Actions.
  static Future<void> envoyerPlanning({
    required String version,
    required String planningBase64,
  }) async {
    final uri = Uri.parse(
      'https://api.github.com/repos/'
          '$_owner/$_repository/dispatches',
    );

    final body = {
      'event_type': 'import_planning',
      'client_payload': {
        'version': version,
        'planning': planningBase64,
      },
    };

    final response = await http.post(
      uri,
      headers: {
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $_token',
        'X-GitHub-Api-Version': _apiVersion,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 204) {
      throw Exception(
        'Erreur GitHub (${response.statusCode}) : '
            '${response.body}',
      );
    }
  }
}

 */