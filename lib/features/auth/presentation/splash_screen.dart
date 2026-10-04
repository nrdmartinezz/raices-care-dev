import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'widgets/auth_logo.dart';

/// Shown while the session is still being restored.
///
/// The canopy without its card, so a returning user sees the same surface the
/// auth screen opens on rather than a flash of a different background.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.canopyDeep, AppColors.canopySage],
          ),
        ),
        child: Center(child: AuthLogo()),
      ),
    );
  }
}
