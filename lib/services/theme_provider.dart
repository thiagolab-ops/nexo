import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark; // O padrão é o nosso tema escuro
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadThemeFromPrefs(); // Ao iniciar, carrega a preferência salva
  }

  void toggleTheme(bool isOn) async {
    // isOn (true) = Dark Mode, isOn (false) = Light Mode
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    
    // Salva a preferência no dispositivo
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', isOn);
  }

  void _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // O padrão é 'true' (dark mode) se nada estiver salvo
    final isDark = prefs.getBool('isDarkMode') ?? true; 
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
