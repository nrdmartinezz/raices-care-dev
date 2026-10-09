import 'package:flutter/widgets.dart';

/// Widths where the main screens use the desktop frame.
///
/// Laptop and desktop share one layout: a fixed sidebar and a content column.
/// Phones keep the floating header and bottom navigation.
abstract final class AppLayout {
  static const wideWidth = 1024.0;

  /// The content column in the 1440 desktop frame, beside the 280 sidebar.
  static const contentMaxWidth = 1160.0;

  static const sidebarWidth = 280.0;

  static const contentPadding = 32.0;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideWidth;
}
