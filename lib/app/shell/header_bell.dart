import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets.dart';

/// The header bell. There is no notifications inbox yet, so it does not open
/// a screen. [showUnread] matches the settings bar, which draws the terracotta
/// mark from the frame.
class HeaderBell extends StatelessWidget {
  const HeaderBell({super.key, this.showUnread = false});

  final bool showUnread;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Notifications',
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SvgPicture.asset(
            showUnread ? AppIcons.accountBellUnread : AppIcons.accountBell,
          ),
        ),
      ),
    );
  }
}
