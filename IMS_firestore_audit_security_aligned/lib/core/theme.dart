import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// E Sekula Design System - Dark Blue Aesthetic
/// Dark: #050505 bg, #111111 surfaces
/// Light: #F8F9FA bg, #FFFFFF surfaces
/// Accent: Dark Blue #0D47A1
/// Typography: Poppins
/// Cards: 24px radius, 0 elevation, 1.5px blue border
/// Buttons: 30px radius (pill-shaped)
class AppTheme {
  // Dark Blue Accent Color
  static const Color darkBlue = Color(0xFF0D47A1);

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF050505); // Pitch black
  static const Color darkSurface = Color(0xFF111111); // Dark grey

  // Light Mode Colors
  static const Color lightBackground = Color(0xFFF8F9FA); // Pure white
  static const Color lightSurface = Color(0xFFFFFFFF); // White

  // Light Theme - E Sekula Design
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Poppins Font Family
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData.light().textTheme,
      ).apply(bodyColor: Colors.black, displayColor: Colors.black),

      colorScheme: ColorScheme.light(
        primary: darkBlue,
        secondary: darkBlue,
        surface: lightSurface,
        error: Colors.red[400]!,
        onPrimary: Colors.white, // White text on Dark Blue buttons
        onSecondary: Colors.white,
        onSurface: Colors.black,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: lightBackground,

      appBarTheme: AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),

      // Cards: 24px radius, 0 elevation, 1.5px blue border
      cardTheme: CardThemeData(
        elevation: 0,
        color: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: darkBlue, width: 1.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Buttons: 30px radius (pill-shaped)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkBlue,
          foregroundColor: Colors.white, // White text for contrast
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // Pill-shaped
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          minimumSize: const Size(0, 50), // Min height 50px for accessibility
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkBlue,
          side: const BorderSide(color: darkBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // Pill-shaped
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          minimumSize: const Size(0, 50),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkBlue,
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Inputs: 30px radius
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30), // Pill-shaped
          borderSide: const BorderSide(color: darkBlue, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.grey[400]!, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: darkBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.red[400]!, width: 1.5),
        ),
        filled: true,
        fillColor: lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
        hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkBlue,
        foregroundColor: Colors.white, // White icon for contrast
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),

      // Chips (Filter chips)
      chipTheme: ChipThemeData(
        backgroundColor: lightSurface,
        selectedColor: darkBlue,
        deleteIconColor: Colors.black,
        labelStyle: GoogleFonts.poppins(color: Colors.black),
        secondaryLabelStyle: GoogleFonts.poppins(color: Colors.white), // White text when selected
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30), // Pill-shaped
          side: const BorderSide(color: darkBlue, width: 1.5),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: darkBlue,
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // Dark Theme - E Sekula Design
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Poppins Font Family
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: Colors.white, displayColor: Colors.white),

      colorScheme: ColorScheme.dark(
        primary: darkBlue,
        secondary: darkBlue,
        surface: darkSurface,
        error: Colors.red[400]!,
        onPrimary: Colors.white, // White text on Dark Blue buttons
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: darkBackground,

      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // Cards: 24px radius, 0 elevation, 1.5px blue border
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: darkBlue, width: 1.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Buttons: 30px radius (pill-shaped)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkBlue,
          foregroundColor: Colors.white, // White text for contrast
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // Pill-shaped
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          minimumSize: const Size(0, 50), // Min height 50px for accessibility
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkBlue,
          side: const BorderSide(color: darkBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // Pill-shaped
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          minimumSize: const Size(0, 50),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkBlue,
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Inputs: 30px radius
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30), // Pill-shaped
          borderSide: const BorderSide(color: darkBlue, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.grey[700]!, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: darkBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.red[400]!, width: 1.5),
        ),
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        labelStyle: GoogleFonts.poppins(color: Colors.grey[400]),
        hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkBlue,
        foregroundColor: Colors.white, // White icon for contrast
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),

      // Chips (Filter chips)
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        selectedColor: darkBlue,
        deleteIconColor: Colors.black,
        labelStyle: GoogleFonts.poppins(color: Colors.white),
        secondaryLabelStyle: GoogleFonts.poppins(color: Colors.white), // White text when selected
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30), // Pill-shaped
          side: const BorderSide(color: darkBlue, width: 1.5),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: darkBlue,
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}