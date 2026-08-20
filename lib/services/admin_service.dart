import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminService {
  static Future<bool> isAdmin() async {
    final prefs = await SharedPreferences.getInstance();

    final value = prefs.getBool('isAdmin') ?? false;

    debugPrint('>>> ADMIN SERVICE : isAdmin = $value');

    return value;
  }

  static Future<void> setAdmin(bool value) async {
    final prefs = await SharedPreferences.getInstance();

  //  await prefs.setBool('isAdmin', value);
    await prefs.remove('isAdmin');
    debugPrint('>>> ADMIN SERVICE : sauvegarde isAdmin = $value');
  }
}