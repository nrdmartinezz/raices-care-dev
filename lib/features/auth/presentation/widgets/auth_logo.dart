import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/assets.dart';

/// The white Raíces mark, 90x122.
///
/// Figma exports it as four separate vector groups rather than one file, so
/// they are reassembled here at the offsets the design places them. The
/// numbers come from the design's percentage insets resolved against the
/// 90x122 frame; they are absolute because the artwork is, not because the
/// layout needs to be.
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  static const _width = 90.0;
  static const _height = 122.0;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        children: [
          Positioned(
            left: 25.182,
            top: 0,
            width: 39.238,
            height: 40.865,
            child: _Part(AppImages.logoWhiteCrown),
          ),
          Positioned(
            left: 17.397,
            top: 42.188,
            width: 55.565,
            height: 49.862,
            child: _Part(AppImages.logoWhiteRoots),
          ),
          Positioned(
            left: 0,
            top: 99.601,
            width: 44.8,
            height: 22.397,
            child: _Part(AppImages.logoWhiteWordLeft),
          ),
          Positioned(
            left: 46.098,
            top: 106.86,
            width: 43.903,
            height: 15.094,
            child: _Part(AppImages.logoWhiteWordRight),
          ),
        ],
      ),
    );
  }
}

class _Part extends StatelessWidget {
  const _Part(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset(asset, fit: BoxFit.fill);
}
