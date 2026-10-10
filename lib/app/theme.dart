import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colour tokens taken from the Raíces Figma library.
abstract final class AppColors {
  static const canvas = Color(0xFFFFF8F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceWarm = Color(0xFFFFF1EC);
  static const surfaceBlush = Color(0xFFFDEAE3);
  static const surfaceClay = Color(0xFFF1DFD8);
  static const track = Color(0xFFF7E4DE);

  /// The hairline around cards and unselected choices.
  static const border = Color(0xFFEAD8D1);

  static const mint = Color(0xFFBCEDDA);

  /// The selected item in the desktop sidebar. A touch deeper than [mint].
  static const navActive = Color(0xFFBAE8D6);

  /// The pale mint behind a plant tag. Lighter than [mint], which is for
  /// filled indicators.
  static const mintSoft = Color(0xFFE4F7EF);
  static const green = Color(0xFF3A6758);
  static const greenSoft = Color(0xFF406D5E);

  static const ink = Color(0xFF231916);
  static const body = Color(0xFF57423B);
  static const muted = Color(0xFF8A726A);

  static const terracotta = Color(0xFF9F3C16);
  static const terracottaBright = Color(0xFFC85A32);

  static const amber = Color(0xFFFFDEAD);
  static const amberText = Color(0xFF7B5500);
  static const amberInk = Color(0xFF281900);

  /// The auth canopy gradient, top to bottom.
  static const canopyDeep = Color(0xFF214F41);
  static const canopySage = Color(0xFF6C9A8A);

  /// The selected language in the canopy pill. Legible on the deep green,
  /// where [terracotta] would not be.
  static const accentAmber = Color(0xFFFABC4D);

}

/// Text styles from the design. Colour is applied at the call site so a single
/// style can serve the several tints the design uses for the same ramp step.
abstract final class AppText {
  /// 11/14 bold, wide tracking. Uppercase eyebrow labels.
  static TextStyle get eyebrow => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.55,
  );

  /// 11/14 bold. Pills, tags, timestamps, nav labels.
  static TextStyle get label => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.44,
  );

  static TextStyle get labelSemiBold => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.44,
  );

  static TextStyle get labelMedium => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.44,
  );

  /// 11/15 regular. The quiet second line under a choice or a hint.
  static TextStyle get caption => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    height: 15 / 11,
  );

  /// 12/18 regular. Task instructions and supporting copy.
  static TextStyle get body =>
      GoogleFonts.plusJakartaSans(fontSize: 12, height: 18 / 12);

  /// 14/20 regular. The sentence under a section heading.
  static TextStyle get bodyLarge =>
      GoogleFonts.plusJakartaSans(fontSize: 14, height: 20 / 14);

  /// 14/18 bold. Choice titles and card headings below [title].
  static TextStyle get subtitleBold => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    height: 18 / 14,
    fontWeight: FontWeight.w700,
  );

  /// 14/18 semibold. Unselected items in the desktop sidebar.
  static TextStyle get subtitleSemiBold => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    height: 18 / 14,
    fontWeight: FontWeight.w600,
  );

  /// 14/20 medium. The season line under a desktop page title.
  static TextStyle get bodyMedium => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );

  /// 12/18 italic. Botanical names.
  static TextStyle get bodyItalic => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    height: 18 / 12,
    fontStyle: FontStyle.italic,
  );

  /// 16/22 bold. Section headings, task titles, button labels.
  static TextStyle get title => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.08,
  );

  /// Newsreader 26/34. The greeting.
  static TextStyle get display => GoogleFonts.newsreader(
    fontSize: 26,
    height: 34 / 26,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.26,
  );

  /// Newsreader 32/40. Desktop page titles such as Living Catalog.
  static TextStyle get displayLarge => GoogleFonts.newsreader(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  /// Newsreader 22/30. Names on the desktop plant catalog.
  static TextStyle get catalogName => GoogleFonts.newsreader(
    fontSize: 22,
    height: 30.25 / 22,
    fontWeight: FontWeight.w600,
  );

  /// Newsreader 22/28. The temperature readout.
  static TextStyle get metric => GoogleFonts.newsreader(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
  );

  /// Newsreader 20/22. Plant names on search results and summaries.
  static TextStyle get plantTitle => GoogleFonts.newsreader(
    fontSize: 20,
    height: 22 / 20,
    fontWeight: FontWeight.w600,
  );

  /// Newsreader 18/22.5. Plant card names.
  static TextStyle get plantName => GoogleFonts.newsreader(
    fontSize: 18,
    height: 22.5 / 18,
    fontWeight: FontWeight.w500,
  );

  /// Newsreader 18/24.75 italic. The elder's quote.
  static TextStyle get quote => GoogleFonts.newsreader(
    fontSize: 18,
    height: 24.75 / 18,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.italic,
  );

  /// Newsreader 18/24. Sheet card headings. Looser than [plantName], which is
  /// the same size set tighter for a two-line stack.
  static TextStyle get cardTitle => GoogleFonts.newsreader(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w500,
  );

  /// 13/16 semibold. Form field labels.
  static TextStyle get fieldLabel => GoogleFonts.plusJakartaSans(
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.26,
  );

  /// 14 regular. Text typed into a field. Line height is left to the field so
  /// the cursor sits where the platform expects.
  static TextStyle get input => GoogleFonts.plusJakartaSans(fontSize: 14);

  /// 11/14 bold, very wide. The rule-flanked "OR CONTINUE WITH".
  static TextStyle get dividerLabel => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
  );

  /// 16/22 semibold. Inline links sized to sit beside [title].
  static TextStyle get titleSemiBold => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.08,
  );
}

abstract final class AppShadows {
  /// The 1px lift shared by every card and pill.
  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      offset: const Offset(0, 1),
      blurRadius: 1,
    ),
  ];

  /// The deeper lift on the wisdom panel.
  static List<BoxShadow> get raised => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      offset: const Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      offset: const Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -2,
    ),
  ];

  static List<BoxShadow> get header => [
    BoxShadow(
      color: const Color(0xFF2C221E).withValues(alpha: 0.05),
      offset: const Offset(0, 4),
      blurRadius: 20,
      spreadRadius: -2,
    ),
  ];

  static List<BoxShadow> get nav => [
    BoxShadow(
      color: const Color(0xFF2C221E).withValues(alpha: 0.08),
      offset: const Offset(0, -4),
      blurRadius: 24,
      spreadRadius: -4,
    ),
  ];

  /// The auth card floating over the canopy.
  static List<BoxShadow> get sheet => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      offset: const Offset(0, 20),
      blurRadius: 12.5,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      offset: const Offset(0, 8),
      blurRadius: 5,
    ),
  ];

  /// The lift under a primary call to action.
  static List<BoxShadow> get cta => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      offset: const Offset(0, 10),
      blurRadius: 15,
      spreadRadius: -3,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      offset: const Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -4,
    ),
  ];
}

/// Measurements that repeat across the screen.
abstract final class AppSizes {
  static const screenPadding = 20.0;
  static const headerHeight = 80.0;

  /// Space between the floating header and the first line of a tab.
  static const headerContentGap = 20.0;
  static const navHeight = 80.0;
  static const sectionGap = 24.0;
  static const cardPadding = 14.0;
  static const cardRadius = 12.0;
  static const imageRadius = 8.0;
  static const pill = 9999.0;
  static const blur = 12.0;
}

ThemeData buildRaicesTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.green,
      secondary: AppColors.terracotta,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.body,
      displayColor: AppColors.ink,
    ),
  );
}
