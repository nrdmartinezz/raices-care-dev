import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import 'auth_logo.dart';

/// The deep forest band behind the auth card.
///
/// The card overlaps its lower edge, so the canopy pads itself generously at
/// the bottom and the caller pulls the card up over it.
class AuthCanopy extends StatelessWidget {
  const AuthCanopy({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.canopyDeep, AppColors.canopySage],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(top: 16, bottom: 36),
                child: AuthLogo(),
              ),
              SizedBox(height: 34),
            ],
          ),
        ),
      ),
    );
  }
}
