import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme.dart';

/// An icon, a title, and a right-aligned counter or link.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.icon,
    required this.iconSize,
    required this.title,
    required this.trailing,
  });

  final String icon;
  final Size iconSize;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(
          icon,
          width: iconSize.width,
          height: iconSize.height,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: AppText.title.copyWith(color: AppColors.ink),
          ),
        ),
        trailing,
      ],
    );
  }
}
