import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _chargement = true;
    });

    final email = _identifiantController.text.trim();
    final motDePasse = _motDePasseController.text;

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: motDePasse,
      );

      if (!mounted) return;

      // Connexion réussie
      Navigator.pop(context, true);

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-credential':
          message = 'Adresse e-mail ou mot de passe incorrect';
          break;

        case 'user-not-found':
          message = 'Aucun compte associé à cette adresse e-mail';
          break;

        case 'wrong-password':
          message = 'Mot de passe incorrect';
          break;

        case 'too-many-requests':
          message =
          'Trop de tentatives. Veuillez réessayer plus tard';
          break;

        case 'operation-not-allowed':
          message =
          'L’authentification par e-mail n’est pas activée';
          break;

        default:
          message = 'Erreur de connexion : ${e.message ?? e.code}';
      }

      setState(() {
        _chargement = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );

    } catch (e) {
      if (!mounted) return;

      setState(() {
        _chargement = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Une erreur est survenue lors de la connexion'),
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
                        labelText: 'Adresse e-mail',
                          prefixIcon: Icon(Icons.email),
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