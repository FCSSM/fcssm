import 'package:flutter/material.dart';

import '../models/utilisateur.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();

  final TextEditingController _identifiantController =
  TextEditingController();

  final TextEditingController _motDePasseController =
  TextEditingController();

  bool _chargement = false;
  String? _erreur;
  bool _motDePasseVisible = false;

  // ---------------------------------------------------------------------------
  // CONNEXION
  // ---------------------------------------------------------------------------

  Future<void> _connecter() async {
    final identifiant = _identifiantController.text.trim();
    final motDePasse = _motDePasseController.text;

    if (identifiant.isEmpty || motDePasse.isEmpty) {
      setState(() {
        _erreur = 'Veuillez renseigner votre identifiant et votre mot de passe.';
      });
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final Utilisateur? utilisateur =
      await _authService.connecter(
        identifiant: identifiant,
        motDePasse: motDePasse,
      );

      if (!mounted) return;

      if (utilisateur == null) {
        setState(() {
          _chargement = false;
          _erreur = 'Profil utilisateur introuvable.';
        });
        return;
      }

      if (!utilisateur.actif) {
        await _authService.deconnecter();

        if (!mounted) return;

        setState(() {
          _chargement = false;
          _erreur = 'Ce compte est désactivé.';
        });
        return;
      }

      Navigator.pop(
        context,
        utilisateur,
      );
    }  on Exception{
      if (!mounted) return;

      setState(() {
        _chargement = false;
        _erreur = 'Identifiant ou mot de passe incorrect.';
      });
    }
  }

  @override
  void dispose() {
    _identifiantController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 55,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Connexion',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 24),

                  TextField(
                    controller: _identifiantController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Identifiant',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _motDePasseController,
                    obscureText: !_motDePasseVisible,
                    onSubmitted: (_) {
                      if (!_chargement) {
                        _connecter();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _motDePasseVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _motDePasseVisible =
                            !_motDePasseVisible;
                          });
                        },
                      ),
                    ),
                  ),

                  if (_erreur != null) ...[
                    const SizedBox(height: 16),

                    Text(
                      _erreur!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                      _chargement ? null : _connecter,
                      icon: _chargement
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.login),
                      label: Text(
                        _chargement
                            ? 'Connexion...'
                            : 'Se connecter',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}