import 'package:intl/intl.dart';

class Match {
  final String equipeLocale;
  final String recevant;
  final String dateMatch;
  final String heureMatch;
  final String equipeAdverse;
  final String stade;
  final String phase;
  final String ville;
  final String competition;
  final int noSemaine;

  Match({
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
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
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
    );
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