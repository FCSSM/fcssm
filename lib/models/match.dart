import 'package:intl/intl.dart';

class MatchFoot {

  // ===========================================================================
  // STATUTS DU MATCH
  // ===========================================================================

  static const String statutNormal = 'normal';
  static const String statutReporte = 'reporte';
  static const String statutForfaitFc = 'forfait_fc';
  static const String statutForfaitAdverse = 'forfait_adverse';


  String? numeroMatch;
  final String equipeLocale;
  final String recevant;
  String dateMatch;
  String heureMatch;
  final String equipeAdverse;
  String stade;
  final String phase;
  String ville;
  final String competition;
  final int noSemaine;
  String? modification;
  String? statut;

  MatchFoot({
    required this.numeroMatch,
    required this.equipeLocale,
    required this.recevant,
    required this.dateMatch,
    required this.heureMatch,
    required this.equipeAdverse,
    required this.stade,
    required this.phase,
    required this.ville,
    required this.competition,
    required this.noSemaine,
    this.modification,
    this.statut,
  });

  factory MatchFoot.fromJson(Map<String, dynamic> json) {
    return MatchFoot(
      numeroMatch: json['no_match']?.toString(),
      equipeLocale: json['equipe_locale'],
      recevant: json['recevant'],
      dateMatch: json['date_match'],
      heureMatch: json['heure_match'],
      equipeAdverse: json['equipe_adverse'],
      stade: json['stade'],
      phase: json['phase'],
      ville: json['ville'],
      competition: json['competition'],
      noSemaine: json['no_semaine'],
      modification: json['modification'],
      statut: json['statut'],
    );
  }


  // ==========================================================
  // JSON
  // ==========================================================

  Map<String, dynamic> toJson() {
    return {
      'numero_match': numeroMatch,
      'equipe_locale': equipeLocale,
      'recevant': recevant,
      'date_match': dateMatch,
      'heure_match': heureMatch,
      'equipe_adverse': equipeAdverse,
      'stade': stade,
      'phase': phase,
      'ville': ville,
      'competition': competition,
      'no_semaine': noSemaine,
      'modification': modification,
      'statut': statut,
    };
  }
  /// Date convertie en DateTime
  DateTime get date {
    return DateFormat('dd/MM/yyyy').parseStrict(dateMatch);
  }

  /// Heure convertie en minutes depuis minuit
  int get heureEnMinutes {
    final h = heureMatch.replaceAll('H', ':');
    final morceaux = h.split(':');

    return int.parse(morceaux[0]) * 60 +
        int.parse(morceaux[1]);
  }

  /// Heure au format 15:00
  String get heureFormatee {
    return heureMatch.replaceAll('H', ':');
  }

  /// Match à domicile ?
  bool get estDomicile => recevant.toLowerCase() == "oui";

  /// Couleur utilisée dans l'application et le PDF
  String get couleur {
    switch (ville.toUpperCase()) {
      case "ST SATURNIN":
        return "jaune";
      case "LA MILESSE":
        return "rouge";
      default:
        return "gris";
    }
  }
}