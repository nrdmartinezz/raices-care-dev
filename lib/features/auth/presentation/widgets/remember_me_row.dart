import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/assets.dart';
import '../../../../app/theme.dart';

/// The "Remember me" checkbox on the sign-in form.
///
/// The checkbox only does anything on web, where it chooses between local and
/// session persistence. Mobile Firebase always persists the session and offers
/// no equivalent, so there it is reassurance rather than a control.
class RememberMeRow extends StatelessWidget {
  const RememberMeRow({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Semantics(
        checked: value,
        child: GestureDetector(
          onTap: () => onChanged(!value),
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value ? AppColors.terracotta : Colors.transparent,
                  borderRadius: BorderRadius.circular(2.5),
                  border: value
                      ? null
                      : Border.all(color: AppColors.muted, width: 1.5),
                ),
                child: value
                    ? SvgPicture.asset(
                        AppIcons.checkDone,
                        width: 10,
                        height: 7.4,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Remember me',
                  style: AppText.body.copyWith(color: AppColors.body),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
