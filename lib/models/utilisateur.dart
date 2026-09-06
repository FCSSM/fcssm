enum RoleUtilisateur {
  utilisateur,
  gestionnaireMatchs,
  admin,
}

class Utilisateur {
  final String uid;
  final String identifiant;
  final String email;
  final RoleUtilisateur role;
  final bool actif;

  const Utilisateur({
    required this.uid,
    required this.identifiant,
    required this.email,
    required this.role,
    required this.actif,
  });

  bool get estAdmin => role == RoleUtilisateur.admin;

  bool get peutGererMatchs =>
      role == RoleUtilisateur.admin ||
          role == RoleUtilisateur.gestionnaireMatchs;

  factory Utilisateur.fromFirestore(
      String uid,
      Map<String, dynamic> data,
      ) {
    final roleString =
        data['role']?.toString() ?? 'utilisateur';

    return Utilisateur(
      uid: uid,
      identifiant:
      data['identifiant']?.toString() ?? '',
      email:
      data['email']?.toString() ?? '',
      role: _roleDepuisString(roleString),
      actif: data['actif'] == true,
    );
  }

  static RoleUtilisateur _roleDepuisString(
      String role,
      ) {
    switch (role) {
      case 'admin':
        return RoleUtilisateur.admin;

      case 'gestionnaire_matchs':
        return RoleUtilisateur.gestionnaireMatchs;

      default:
        return RoleUtilisateur.utilisateur;
    }
  }
}