import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      debugShowCheckedModeBanner: false,

      localizationsDelegates: GlobalMaterialLocalizations.delegates,

      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],

      title: 'FCSSM',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.amber,
      ),
      home: const HomePage(),
    );
  }
}
