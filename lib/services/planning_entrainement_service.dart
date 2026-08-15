import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/entrainement.dart';

class PlanningEntrainementService {
  static const String _assetPath =
      'assets/planning_entrainement.json';

  Future<List<Entrainement>> chargerPlanningEntrainement() async {
    final jsonString = await rootBundle.loadString(_assetPath);

    final Map<String, dynamic> data = json.decode(jsonString);

    final List<Entrainement> entrainements = [];

    data.forEach((lieu, jours) {
      if (jours is! Map<String, dynamic>) {
        return;
      }

      jours.forEach((jour, categories) {
        if (categories is! Map<String, dynamic>) {
          return;
        }

        categories.forEach((categorie, horaire) {
          if (horaire is String) {
            entrainements.add(
              Entrainement(
                lieu: lieu,
                jour: jour,
                categorie: categorie,
                horaire: horaire,
              ),
            );
          }
        });
      });
    });

    return entrainements;
  }
}