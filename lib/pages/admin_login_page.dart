import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _identifiantController = TextEditingController();
  final _motDePasseController = TextEditingController();

  bool _motDePasseVisible = false;
  bool _chargement = false;

  @override
  void dispose() {
    _identifiantController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  Future<void> _connexion() async {
    // Vérification des champs
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _chargement = true;
    });

    final identifiant = _identifiantController.text.trim();
    final motDePasse = _motDePasseController.text;

    // ------------------------------------------------
    // TEMPORAIRE
    // À remplacer plus tard par ta vraie authentification
    // ------------------------------------------------
    const identifiantAdmin = 'admin';
    const motDePasseAdmin = '1234';

    // Petite attente pour simuler une authentification
    await Future.delayed(
      const Duration(milliseconds: 300),
    );

    if (!mounted) return;

    if (identifiant == identifiantAdmin &&
        motDePasse == motDePasseAdmin) {
      // Mémorisation de l'administrateur
      await AdminService.setAdmin(true);

      if (!mounted) return;

      // Retour à la page précédente avec résultat positif
      Navigator.pop(context, true);
    } else {
      setState(() {
        _chargement = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Identifiant ou mot de passe incorrect',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Administration',
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),

            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
              ),

              child: Form(
                key: _formKey,

                child: Column(
                  children: [
                    // -------------------------
                    // LOGO
                    // -------------------------
                    Image.asset(
                      'assets/images/logo_club.png',
                      height: 110,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 25),

                    // -------------------------
                    // TITRE
                    // -------------------------
                    const Text(
                      'Accès administrateur',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // -------------------------
                    // IDENTIFIANT
                    // -------------------------
                    TextFormField(
                      controller: _identifiantController,

                      textInputAction:
                      TextInputAction.next,

                      decoration:
                      const InputDecoration(
                        labelText: 'Identifiant',
                        prefixIcon:
                        Icon(Icons.person),
                        border:
                        OutlineInputBorder(),
                      ),

                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Veuillez saisir votre identifiant';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // -------------------------
                    // MOT DE PASSE
                    // -------------------------
                    TextFormField(
                      controller:
                      _motDePasseController,

                      obscureText:
                      !_motDePasseVisible,

                      textInputAction:
                      TextInputAction.done,

                      onFieldSubmitted: (_) {
                        _connexion();
                      },

                      decoration:
                      InputDecoration(
                        labelText: 'Mot de passe',

                        prefixIcon:
                        const Icon(Icons.lock),

                        suffixIcon:
                        IconButton(
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

                        border:
                        const OutlineInputBorder(),
                      ),

                      validator: (value) {
                        if (value == null ||
                            value.isEmpty) {
                          return 'Veuillez saisir votre mot de passe';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 30),

                    // -------------------------
                    // BOUTON CONNEXION
                    // -------------------------
                    SizedBox(
                      width: double.infinity,
                      height: 50,

                      child: ElevatedButton(
                        onPressed: _chargement
                            ? null
                            : _connexion,

                        child: _chargement
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          'SE CONNECTER',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}