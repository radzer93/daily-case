import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.tag,
    required this.tagInk,
    required this.stamp,
    required this.ok,
    required this.bad,
    required this.onSemantic,
  });

  final Color bg;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;
  final Color tag;
  final Color tagInk;
  final Color stamp;
  final Color ok;
  final Color bad;
  final Color onSemantic;

  static const light = AppColors(
    bg: Color(0xFFE4E8EA),
    surface: Color(0xFFF6F7F7),
    ink: Color(0xFF13171A),
    muted: Color(0xFF58636A),
    line: Color(0xFFC3CBD0),
    tag: Color(0xFFF2C230),
    tagInk: Color(0xFF1B1606),
    stamp: Color(0xFFB3261E),
    ok: Color(0xFF2B7A4B),
    bad: Color(0xFFB3261E),
    onSemantic: Color(0xFFFFFFFF),
  );

  static const dark = AppColors(
    bg: Color(0xFF0E1113),
    surface: Color(0xFF171C20),
    ink: Color(0xFFE3E6E8),
    muted: Color(0xFF95A0A7),
    line: Color(0xFF2A3338),
    tag: Color(0xFFE6B92C),
    tagInk: Color(0xFF1B1606),
    stamp: Color(0xFFE5574A),
    ok: Color(0xFF3F9E68),
    bad: Color(0xFFD9483B),
    onSemantic: Color(0xFFFFFFFF),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? ink,
    Color? muted,
    Color? line,
    Color? tag,
    Color? tagInk,
    Color? stamp,
    Color? ok,
    Color? bad,
    Color? onSemantic,
  }) =>
      AppColors(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        line: line ?? this.line,
        tag: tag ?? this.tag,
        tagInk: tagInk ?? this.tagInk,
        stamp: stamp ?? this.stamp,
        ok: ok ?? this.ok,
        bad: bad ?? this.bad,
        onSemantic: onSemantic ?? this.onSemantic,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      line: l(line, other.line),
      tag: l(tag, other.tag),
      tagInk: l(tagInk, other.tagInk),
      stamp: l(stamp, other.stamp),
      ok: l(ok, other.ok),
      bad: l(bad, other.bad),
      onSemantic: l(onSemantic, other.onSemantic),
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

TextStyle _font(String family, TextStyle style, String fallback) {
  try {
    return GoogleFonts.getFont(family, textStyle: style);
  } catch (_) {
    return style.copyWith(fontFamily: fallback);
  }
}

TextStyle displayStyle({
  double size = 28,
  FontWeight weight = FontWeight.w900,
  Color? color,
  double height = 0.95,
  double letterSpacing = 0.2,
  TextDecoration? decoration,
}) =>
    _font(
      'Big Shoulders Display',
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        decoration: decoration,
        decorationThickness: 2.5,
      ),
      'sans-serif-condensed',
    );

TextStyle bodyStyle({
  double size = 16,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double height = 1.55,
  FontStyle? fontStyle,
}) =>
    _font(
      'Literata',
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        fontStyle: fontStyle,
      ),
      'serif',
    );

TextStyle monoStyle({
  double size = 12,
  FontWeight weight = FontWeight.w700,
  Color? color,
  double letterSpacing = 1.2,
  double height = 1.3,
}) =>
    _font(
      'JetBrains Mono',
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      ),
      'monospace',
    );

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final base = ThemeData(useMaterial3: true, brightness: brightness);

  TextTheme text;
  try {
    text = GoogleFonts.getTextTheme('Literata', base.textTheme);
  } catch (_) {
    text = base.textTheme;
  }
  text = text.apply(bodyColor: c.ink, displayColor: c.ink);

  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: c.tag, brightness: brightness)
        .copyWith(
      primary: c.ink,
      onPrimary: c.bg,
      surface: c.surface,
      onSurface: c.ink,
      error: c.bad,
    ),
    textTheme: text,
    dividerColor: c.line,
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: monoStyle(color: c.bg, size: 13, letterSpacing: 0.3),
      behavior: SnackBarBehavior.floating,
    ),
    extensions: <ThemeExtension<dynamic>>[c],
  );
}
