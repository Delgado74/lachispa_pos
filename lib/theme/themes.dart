import 'package:flutter/material.dart';
import 'app_tokens.dart';

// =====================================================================
// LaChispa (Original) — cypherpunk · electric blue · sparks
// =====================================================================

const AppTokens chispaTokens = AppTokens(
  backgroundGradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F1419),
      Color(0xFF1A1D47),
      Color(0xFF2D3FE7),
    ],
    stops: [0.0, 0.5, 1.0],
  ),
  scaffoldBase: Color(0xFF0F1419),    // matches backgroundGradient first stop
  surface: Color(0x0DFFFFFF),         // white @ 0.05
  outline: Color(0x1AFFFFFF),         // white @ 0.10
  outlineStrong: Color(0x2EFFFFFF),   // white @ 0.18
  textPrimary: Colors.white,
  textSecondary: Color(0x8CFFFFFF),   // white @ 0.55
  textTertiary: Color(0x73FFFFFF),    // white @ 0.45
  textAccent: Color(0xFF6B7FFF),
  accentGradient: LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF2D3FE7), Color(0xFF4C63F7)],
  ),
  accentSolid: Color(0xFF4C63F7),
  accentBright: Color(0xFF5B73FF),
  accentForeground: Colors.white,
  statusHealthy: Color(0xFF4ADE80),
  statusUnhealthy: Color(0xFFEF4444),
  statusChecking: Color(0x40FFFFFF),  // white @ 0.25
  statusWarning: Color(0xFFFFA726),   // orange warning indicator
  statusWarningSoft: Color(0xFFFFCC80),  // Colors.orange.shade200 — muted warning for secondary content
  ctaShadow: Color(0x59000000),       // black @ 0.35
  dialogBackground: Color(0xFF1A1D47),
  inputFill: Color(0x0DFFFFFF),       // white @ 0.05
);

ThemeData chispaTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: chispaTokens.scaffoldBase,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF4C63F7),
      onPrimary: Colors.white,
      secondary: Color(0xFF6B7FFF),
      onSecondary: Colors.white,
      surface: Color(0xFF1A1D47),
      onSurface: Colors.white,
      error: Color(0xFFEF4444),
      onError: Colors.white,
    ),
    extensions: const [chispaTokens],
  );
}

// =====================================================================
// Light — quiet trust · minimal fintech · calm
// =====================================================================

const AppTokens lightTokens = AppTokens(
  // Flat background — same color repeated keeps the API surface stable while
  // visually rendering as a solid fill on screens that paint t.backgroundGradient.
  backgroundGradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF7F7F5), Color(0xFFF7F7F5)],
  ),
  scaffoldBase: Color(0xFFF7F7F5),
  surface: Color(0xFFFFFFFF),
  outline: Color(0xFFE5E5E0),
  outlineStrong: Color(0xFFD1D1CC),
  textPrimary: Color(0xFF0D0D0D),
  textSecondary: Color(0xFF6B6B6B),
  textTertiary: Color(0xFF9A9A9A),
  textAccent: Color(0xFF3B4FE0),
  // Light theme renders accents as flat solids — same color repeated so the
  // shared accentGradient API still works without showing a gradient.
  accentGradient: LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF4C63F7), Color(0xFF4C63F7)],
  ),
  accentSolid: Color(0xFF4C63F7),
  accentBright: Color(0xFF6B7FFF),
  accentForeground: Color(0xFFFFFFFF),
  statusHealthy: Color(0xFF10B981),
  statusUnhealthy: Color(0xFFDC2626),
  statusChecking: Color(0x330D0D0D),     // ink @ 0.20
  statusWarning: Color(0xFFD97706),
  statusWarningSoft: Color(0xFFFED7AA),
  ctaShadow: Color(0x140D0D0D),          // ink @ 0.08
  dialogBackground: Color(0xFFFFFFFF),
  inputFill: Color(0xFFFFFFFF),
);

ThemeData lightTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightTokens.scaffoldBase,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF4C63F7),
      onPrimary: Colors.white,
      secondary: Color(0xFF3B4FE0),
      onSecondary: Colors.white,
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF0D0D0D),
      error: Color(0xFFDC2626),
      onError: Colors.white,
    ),
    extensions: const [lightTokens],
  );
}

// =====================================================================
// Pizza Day — Laszlo's 10 000 BTC · pepperoni red · golden cheese
// =====================================================================

const AppTokens pizzaDayTokens = AppTokens(
  backgroundGradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF0A0), Color(0xFFFFF0A0)],
  ),
  scaffoldBase: Color(0xFFFFF0A0),         // queso amarillo fuerte
  surface: Color(0xFFFFF1D7),              // crema — palette 2
  outline: Color(0xFFF7AD45),              // queso dorado — palette 2
  outlineStrong: Color(0xFFBB3E00),        // tomate quemado — palette 2
  textPrimary: Color(0xFF2A1500),          // marrón oscuro cálido
  textSecondary: Color(0xFF7A3500),        // tomate oscuro
  textTertiary: Color(0xFFAA5500),         // muted naranja
  textAccent: Color(0xFFBB3E00),           // tomate quemado
  accentGradient: LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFBB3E00), Color(0xFFF7AD45)],
  ),
  accentSolid: Color(0xFFBB3E00),          // tomate quemado — CTA principal
  accentBright: Color(0xFF5F8D37),         // brócoli/albahaca — palette 2
  accentForeground: Color(0xFFFFF1D7),     // crema sobre rojo
  statusHealthy: Color(0xFF5F8D37),        // verde brócoli — palette 2
  statusUnhealthy: Color(0xFF8B0000),      // rojo oscuro
  statusChecking: Color(0x33F7AD45),       // queso @ 20%
  statusWarning: Color(0xFFF7AD45),        // queso dorado
  statusWarningSoft: Color(0xFFFFDDA0),    // queso suave
  ctaShadow: Color(0x33000000),
  dialogBackground: Color(0xFFFFF1D7),     // crema
  inputFill: Color(0xFFFFF1D7),
);

ThemeData pizzaDayTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    brightness: Brightness.light,
    scaffoldBackgroundColor: pizzaDayTokens.scaffoldBase,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFBB3E00),
      onPrimary: Color(0xFFFFF1D7),
      secondary: Color(0xFFF7AD45),
      onSecondary: Color(0xFF2A1500),
      surface: Color(0xFFFFF1D7),
      onSurface: Color(0xFF2A1500),
      error: Color(0xFF8B0000),
      onError: Colors.white,
    ),
    extensions: const [pizzaDayTokens],
  );
}

// =====================================================================
// Dark — sovereign tool · terminal-elegant · flat layers
// =====================================================================

const AppTokens darkTokens = AppTokens(
  backgroundGradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B0B0C), Color(0xFF0B0B0C)],
  ),
  scaffoldBase: Color(0xFF0B0B0C),
  surface: Color(0xFF141416),
  outline: Color(0xFF2A2A2E),
  outlineStrong: Color(0xFF3A3A3E),
  textPrimary: Color(0xFFF5F5F5),
  textSecondary: Color(0xFF9A9A9A),
  textTertiary: Color(0xFF6B6B6E),
  textAccent: Color(0xFF7E92FF),
  accentGradient: LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF2D3FE7), Color(0xFF5B73FF)],
  ),
  accentSolid: Color(0xFF4C63F7),
  accentBright: Color(0xFF7E92FF),
  accentForeground: Color(0xFFFFFFFF),
  statusHealthy: Color(0xFF3BD671),
  statusUnhealthy: Color(0xFFFF5C5C),
  statusChecking: Color(0x33FFFFFF),     // white @ 0.20
  statusWarning: Color(0xFFFFB454),
  statusWarningSoft: Color(0xFF7A5A2E),
  ctaShadow: Color(0x99000000),          // black @ 0.60
  dialogBackground: Color(0xFF1C1C1F),
  inputFill: Color(0xFF1C1C1F),
);

ThemeData darkTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkTokens.scaffoldBase,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF4C63F7),
      onPrimary: Colors.white,
      secondary: Color(0xFF7E92FF),
      onSecondary: Colors.white,
      surface: Color(0xFF141416),
      onSurface: Color(0xFFF5F5F5),
      error: Color(0xFFFF5C5C),
      onError: Colors.white,
    ),
    extensions: const [darkTokens],
  );
}
