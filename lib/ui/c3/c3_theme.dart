import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class C3Colors {
  static const paper = Color(0xFFFBF7EF);
  static const dot = Color(0xFFE6DAC8);
  static const kraft = Color(0xFFEADBC4);
  static const card = Color(0xFFFFFEFA);
  static const line = Color(0xFFD9C9B4);
  static const ink = Color(0xFF4B3A2F);
  static const ink2 = Color(0xFF76655A);
  static const ink3 = Color(0xFF7A6858);
  static const hint = Color(0xFF8A786A);
  static const shadow = Color.fromRGBO(98, 72, 50, .22);
  static const stamp = Color(0xFFE0676F);
  static const pinkLine = Color(0xFFF4AAB7);

  static const tapeSky = Color.fromRGBO(186, 217, 244, .88);
  static const tapeMint = Color.fromRGBO(190, 229, 207, .88);
  static const tapePink = Color.fromRGBO(248, 202, 212, .88);
  static const tapeYellow = Color.fromRGBO(247, 225, 150, .9);
}

abstract final class C3Fonts {
  static const jua = 'Jua';
  static const gowun = 'GowunDodum';
  static const gaegu = 'Gaegu';

  // Jua·Gaegu 에는 °, …, · 가 없다.
  static const fallback = [gowun];
}

// 줄 높이의 남는 공간을 CSS 처럼 위아래로 똑같이 나눠야 목업과 글자 위치가 맞는다.
abstract final class C3Text {
  static const title = TextStyle(
    fontFamily: C3Fonts.jua,
    fontFamilyFallback: C3Fonts.fallback,
    fontSize: 30,
    height: 1,
    leadingDistribution: TextLeadingDistribution.even,
    color: C3Colors.ink,
  );
  static const label = TextStyle(
    fontFamily: C3Fonts.jua,
    fontFamilyFallback: C3Fonts.fallback,
    fontSize: 16,
    height: 18 / 16,
    leadingDistribution: TextLeadingDistribution.even,
    color: C3Colors.ink,
  );
  static const body = TextStyle(
    fontFamily: C3Fonts.gowun,
    fontSize: 15,
    height: 20 / 15,
    leadingDistribution: TextLeadingDistribution.even,
    color: C3Colors.ink,
  );
  static const pet = TextStyle(
    fontFamily: C3Fonts.gaegu,
    fontFamilyFallback: C3Fonts.fallback,
    fontWeight: FontWeight.w700,
    fontSize: 20,
    height: 24 / 20,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: -1.5,
    color: C3Colors.ink,
  );
}

class GaugeColors {
  const GaugeColors(this.bg, this.fill, this.tone);

  final Color bg;
  final Color fill;
  final Color tone;

  static const mood = GaugeColors(
    Color(0xFFFDE6EB),
    Color(0xFFF7B7C6),
    Color(0xFFB23F5A),
  );
  static const fullness = GaugeColors(
    Color(0xFFFDEEDC),
    Color(0xFFF7CB98),
    Color(0xFF9A5A1E),
  );
  static const energy = GaugeColors(
    Color(0xFFE5F5E9),
    Color(0xFFA9DDB8),
    Color(0xFF2E7A4E),
  );
  static const bond = GaugeColors(
    Color(0xFFEEEAFB),
    Color(0xFFC7BCF1),
    Color(0xFF7461C6),
  );
}

/// 종이 바탕 위 상태바: 투명 + 어두운 아이콘. 화면마다 달라지지 않게 한곳에서 쓴다.
const c3SystemBars = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);

ThemeData buildC3Theme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: C3Colors.stamp,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFFBE0E5),
    onPrimaryContainer: C3Colors.ink,
    secondary: C3Colors.ink2,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFF8DDE3),
    onSecondaryContainer: C3Colors.ink,
    tertiary: Color(0xFF5E9E78),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFE5F5E9),
    onTertiaryContainer: C3Colors.ink,
    error: Color(0xFFC4474F),
    onError: Colors.white,
    errorContainer: Color(0xFFFBE0E5),
    onErrorContainer: Color(0xFF7A2A31),
    surface: C3Colors.paper,
    onSurface: C3Colors.ink,
    onSurfaceVariant: C3Colors.ink2,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: C3Colors.card,
    surfaceContainer: Color(0xFFF6EFE3),
    surfaceContainerHigh: C3Colors.card,
    surfaceContainerHighest: Color(0xFFEFE6D8),
    outline: Color(0xFFC9B6A0),
    outlineVariant: C3Colors.dot,
    shadow: Color(0xFF624832),
    scrim: Color(0xFF2E221A),
    inverseSurface: C3Colors.ink,
    onInverseSurface: C3Colors.paper,
    inversePrimary: Color(0xFFF8CAD4),
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: C3Fonts.gowun,
    fontFamilyFallback: C3Fonts.fallback,
  );
  final text = base.textTheme.apply(
    bodyColor: C3Colors.ink,
    displayColor: C3Colors.ink,
  );
  TextStyle? jua(TextStyle? s) => s?.copyWith(fontFamily: C3Fonts.jua);

  const juaButton = TextStyle(
    fontFamily: C3Fonts.jua,
    fontFamilyFallback: C3Fonts.fallback,
    fontSize: 16,
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  const buttonSize = Size(64, 46);
  const line = BorderSide(color: C3Colors.line, width: 1.5);
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: line,
  );

  return base.copyWith(
    scaffoldBackgroundColor: C3Colors.paper,
    canvasColor: C3Colors.paper,
    splashFactory: InkRipple.splashFactory,
    textTheme: text.copyWith(
      headlineLarge: jua(text.headlineLarge),
      headlineMedium: jua(text.headlineMedium),
      headlineSmall: jua(text.headlineSmall),
      titleLarge: jua(text.titleLarge),
      titleMedium: jua(text.titleMedium),
      titleSmall: jua(text.titleSmall),
      labelLarge: jua(text.labelLarge),
      labelMedium: jua(text.labelMedium),
      labelSmall: jua(text.labelSmall),
    ),
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: c3SystemBars,
      backgroundColor: C3Colors.paper,
      foregroundColor: C3Colors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: C3Fonts.jua,
        fontFamilyFallback: C3Fonts.fallback,
        fontSize: 22,
        color: C3Colors.ink,
      ),
      iconTheme: IconThemeData(color: C3Colors.ink),
    ),
    iconTheme: const IconThemeData(color: C3Colors.ink2),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C3Colors.stamp,
        foregroundColor: Colors.white,
        disabledBackgroundColor: C3Colors.kraft,
        disabledForegroundColor: C3Colors.ink3,
        textStyle: juaButton,
        minimumSize: buttonSize,
        shape: buttonShape,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C3Colors.ink,
        backgroundColor: C3Colors.card,
        disabledForegroundColor: C3Colors.ink3,
        textStyle: juaButton,
        minimumSize: buttonSize,
        shape: buttonShape,
        side: line,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFB8505A),
        disabledForegroundColor: C3Colors.ink3,
        textStyle: juaButton,
        shape: buttonShape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: C3Colors.ink2),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: C3Colors.card,
        foregroundColor: C3Colors.ink2,
        selectedBackgroundColor: const Color(0xFFF8DDE3),
        selectedForegroundColor: C3Colors.ink,
        side: line,
        textStyle: const TextStyle(
          fontFamily: C3Fonts.jua,
          fontFamilyFallback: C3Fonts.fallback,
          fontSize: 15,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C3Colors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: C3Colors.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      titleTextStyle: const TextStyle(
        fontFamily: C3Fonts.jua,
        fontFamilyFallback: C3Fonts.fallback,
        fontSize: 22,
        color: C3Colors.ink,
      ),
      contentTextStyle: C3Text.body,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C3Colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C3Colors.ink,
      contentTextStyle: C3Text.body.copyWith(color: C3Colors.paper),
      actionTextColor: const Color(0xFFF8CAD4),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C3Colors.card,
      hintStyle: const TextStyle(color: C3Colors.hint),
      labelStyle: const TextStyle(color: C3Colors.ink2),
      floatingLabelStyle: const TextStyle(color: C3Colors.ink),
      helperStyle: const TextStyle(color: C3Colors.ink3),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: C3Colors.stamp, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: C3Colors.stamp,
      selectionColor: Color(0x66F8CAD4),
      selectionHandleColor: C3Colors.stamp,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : C3Colors.ink3,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? C3Colors.stamp : C3Colors.kraft,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? C3Colors.stamp
            : const Color(0xFFC9B6A0),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: C3Colors.ink2,
      textColor: C3Colors.ink,
      titleTextStyle: C3Text.body,
      subtitleTextStyle: TextStyle(
        fontFamily: C3Fonts.gowun,
        fontSize: 13,
        color: C3Colors.ink2,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: C3Colors.card,
      selectedColor: const Color(0xFFF8DDE3),
      checkmarkColor: C3Colors.ink,
      side: line,
      labelStyle: const TextStyle(
        fontFamily: C3Fonts.gowun,
        fontSize: 14,
        color: C3Colors.ink,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    cardTheme: CardThemeData(
      color: C3Colors.card,
      surfaceTintColor: Colors.transparent,
      shadowColor: C3Colors.shadow,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C3Colors.kraft,
      surfaceTintColor: Colors.transparent,
      indicatorColor: C3Colors.paper,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: C3Fonts.jua,
          fontFamilyFallback: C3Fonts.fallback,
          fontSize: 14,
          color: C3Colors.ink,
        ),
      ),
      iconTheme: const WidgetStatePropertyAll(
        IconThemeData(color: C3Colors.ink),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: C3Colors.stamp,
      linearTrackColor: Color(0xFFEFE6D8),
      circularTrackColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(color: C3Colors.dot, thickness: 1),
  );
}
