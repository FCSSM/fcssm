class Entrainement {
  final String lieu;
  final String jour;
  final String categorie;
  final String horaire;

  const Entrainement({
    required this.lieu,
    required this.jour,
    required this.categorie,
    required this.horaire,
  });

  String get heureDebut {
    if (horaire.contains('-')) {
      return horaire.split('-').first;
    }
    return horaire;
  }

  String get heureFin {
    if (horaire.contains('-')) {
      return horaire.split('-').last;
    }
    return '';
  }

  @override
  String toString() {
    return '$jour - $categorie - $lieu - $horaire';
  }
}