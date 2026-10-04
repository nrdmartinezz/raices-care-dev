import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/assets.dart';
import '../../../../app/theme.dart';

/// The dedication and version line below the auth card.
class HeritageFooter extends StatelessWidget {
  const HeritageFooter({super.key, this.topPadding = 48});

  /// Space above the dedication. Callers that overlap the card into the
  /// canopy reduce this, since the design's 48 already accounts for the pull.
  final double topPadding;

  /// Bumped by hand. There is no build-number plumbing yet.
  static const version = 'RAÍCES BOTANICAL ENGINE • VERSIÓN 1.0.4';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        topPadding,
        AppSizes.screenPadding,
        24,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _Leaf(),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Dedicated to the elders who planted before us',
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: AppColors.muted),
                ),
              ),
              const SizedBox(width: 8),
              const _Leaf(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            version,
            textAlign: TextAlign.center,
            style: AppText.eyebrow.copyWith(color: AppColors.footerFaint),
          ),
        ],
      ),
    );
  }
}

class _Leaf extends StatelessWidget {
  const _Leaf();

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset(AppIcons.footerLeaf, width: 10.5, height: 12.25);
}
