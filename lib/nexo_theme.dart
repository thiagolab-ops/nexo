import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NexoTheme {
  
  static final ThemeData dark = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF121212),
    primaryColor: Colors.blueAccent,
    
    textTheme: GoogleFonts.latoTextTheme(ThemeData.dark().textTheme),
    
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1F1F1F),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: GoogleFonts.lato(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Colors.lightBlueAccent,
      foregroundColor: Colors.white,
    ),
    
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.grey,
      backgroundColor: const Color(0xFF1F1F1F),
    ),

    cardColor: const Color(0xFF1F1F1F),
    
    iconTheme: const IconThemeData(color: Colors.white70),
  );

  
  static final ThemeData light = ThemeData.light().copyWith(
    // --- CORREÇÃO DE CONTRASTE ---
    scaffoldBackgroundColor: const Color(0xFFF5F5F5), // Fundo agora é cinza-claro
    cardColor: Colors.white, // Cards agora são brancos puros
    // --- FIM DA CORREÇÃO ---

    primaryColor: Colors.blueAccent, 
    
    textTheme: GoogleFonts.latoTextTheme(ThemeData.light().textTheme),
    
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white, // AppBar permanece branca
      elevation: 1, 
      iconTheme: const IconThemeData(color: Colors.black87), 
      titleTextStyle: GoogleFonts.lato(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold), 
    ),
    
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Colors.blueAccent,
      foregroundColor: Colors.white,
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: Colors.blueAccent,
      unselectedItemColor: Colors.grey[600],
      backgroundColor: Colors.white,
      elevation: 8,
    ),
    
    iconTheme: IconThemeData(color: Colors.grey[800]),
  );
}
