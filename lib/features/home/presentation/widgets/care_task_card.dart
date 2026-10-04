import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/assets.dart';
import '../../../../app/theme.dart';
import '../../domain/care_task.dart';

/// One row of Today's Ritual: a checkbox, the plant and time, the instruction,
/// and a category tag beside the plant's location.
class CareTaskCard extends StatelessWidget {
  const CareTaskCard({super.key, required this.task, this.onToggle});

  final CareTask task;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 26,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _Checkbox(isDone: task.isDone, onTap: onToggle),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.plantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title.copyWith(
                            color: task.isDone ? AppColors.body : AppColors.ink,
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppColors.body,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        task.time,
                        style: AppText.label.copyWith(
                          color: task.isDueNow
                              ? AppColors.amberText
                              : AppColors.body,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    task.instruction,
                    style: AppText.body.copyWith(color: AppColors.body),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _CategoryTag(category: task.category),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          task.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body.copyWith(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.isDone, this.onTap});

  final bool isDone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDone ? AppColors.green : AppColors.track,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SvgPicture.asset(
          isDone ? AppIcons.checkDone : AppIcons.checkPending,
          width: 12.225,
          height: 9.019,
        ),
      ),
    );
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.category});

  final CareCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: category.background,
        borderRadius: BorderRadius.circular(AppSizes.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            category.icon,
            width: category.iconSize.width,
            height: category.iconSize.height,
          ),
          const SizedBox(width: 4),
          Text(
            category.label,
            style: AppText.label.copyWith(color: category.foreground),
          ),
        ],
      ),
    );
  }
}
