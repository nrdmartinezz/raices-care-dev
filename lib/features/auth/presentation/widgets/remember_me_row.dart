import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// The "Remember me" checkbox and the secure-session reassurance beside it.
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Both halves give way at large text scales rather than overflow;
          // the checkbox and the dot keep their stated size.
          Flexible(
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
                      decoration: BoxDecoration(
                        color: value ? AppColors.terracotta : AppColors.track,
                        borderRadius: BorderRadius.circular(2.5),
                        border: value
                            ? null
                            : Border.all(color: AppColors.surfaceClay),
                      ),
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
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Secure session',
                    style: AppText.labelMedium.copyWith(color: AppColors.green),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
