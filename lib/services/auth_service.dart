import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/utilisateur.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // CONNEXION
  // ---------------------------------------------------------------------------

  Future<Utilisateur?> connecter({
    required String identifiant,
    required String motDePasse,
  }) async {
    final email =
        '${identifiant.trim().toLowerCase()}@fcssm.fr';

    final credential =
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: motDePasse,
    );

    final user = credential.user;

    if (user == null) {
      return null;
    }

    return await _chargerUtilisateur(user.uid);
  }

  // ---------------------------------------------------------------------------
  // UTILISATEUR CONNECTÉ
  // ---------------------------------------------------------------------------

  Future<Utilisateur?> utilisateurConnecte() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    return await _chargerUtilisateur(user.uid);
  }

  // ---------------------------------------------------------------------------
  // CHARGER LE PROFIL FIRESTORE
  // ---------------------------------------------------------------------------

  Future<Utilisateur?> _chargerUtilisateur(String uid) async {
    final document = await _firestore
        .collection('utilisateurs')
        .doc(uid)
        .get();

    if (!document.exists) {
      return null;
    }

    return Utilisateur.fromFirestore(
      document.id,
      document.data()!,
    );
  }

  // ---------------------------------------------------------------------------
  // DÉCONNEXION
  // ---------------------------------------------------------------------------

  Future<void> deconnecter() async {
    await _auth.signOut();
  }
}