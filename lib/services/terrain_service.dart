import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/terrain.dart';

class TerrainService {
  static Future<List<Terrain>> chargerTerrains() async {
    final jsonString = await rootBundle.loadString(
      'assets/data/terrain.json',
    );

    final Map<String, dynamic> data =
    json.decode(jsonString);

    final List<dynamic> terrainJson =
    data['terrains'];

    return terrainJson
        .map((json) => Terrain.fromJson(json))
        .toList();
  }
}