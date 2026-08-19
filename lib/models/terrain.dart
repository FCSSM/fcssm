class Terrain {
  final String id;
  final String nom;
  final String ville;

  const Terrain({
    required this.id,
    required this.nom,
    required this.ville,
  });

  factory Terrain.fromJson(Map<String, dynamic> json) {
    return Terrain(
      id: json['id'],
      nom: json['nom'],
      ville: json['ville']
    );
  }
}