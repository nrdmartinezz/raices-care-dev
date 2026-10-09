import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/assets.dart';
import '../../../app/theme.dart';
import '../domain/search_filters.dart';

/// The funnel beside a catalog search field.
class SearchFilterButton extends StatelessWidget {
  const SearchFilterButton({
    super.key,
    required this.onPressed,
    this.count = 0,
  });

  final VoidCallback? onPressed;

  /// Checked options currently applied. Hidden when none are on.
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count > 0 ? 'Filters, $count selected' : 'Filters',
      child: Material(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          child: Ink(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.card,
            ),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                children: [
                  Center(
                    child: SvgPicture.asset(
                      AppIcons.searchFilter,
                      width: 35,
                      height: 36,
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        height: 16,
                        constraints: const BoxConstraints(minWidth: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.terracotta,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        child: Text(
                          '$count',
                          style: AppText.body.copyWith(
                            color: AppColors.surface,
                            fontSize: 10,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rank, family, and use filters for a catalog search.
///
/// Edits stay here until [onApply]. [onBack] drops them; the add-plant header
/// does that by leaving this view without calling [onApply].
class SearchFiltersView extends StatefulWidget {
  const SearchFiltersView({
    super.key,
    required this.filters,
    required this.onApply,
    this.onBack,
    this.padding = const EdgeInsets.only(top: 16),
  });

  final SearchFilters filters;
  final ValueChanged<SearchFilters> onApply;
  final VoidCallback? onBack;
  final EdgeInsets padding;

  @override
  State<SearchFiltersView> createState() => _SearchFiltersViewState();
}

class _SearchFiltersViewState extends State<SearchFiltersView> {
  late SearchFilters _draft = widget.filters;

  @override
  Widget build(BuildContext context) {
    final count = _draft.count;
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.onBack != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: _BackButton(onPressed: widget.onBack!),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filters',
                    style: AppText.display.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    "Narrow your search by botanical rank, family, or how you'll use it.",
                    style: AppText.bodyLarge.copyWith(color: AppColors.body),
                  ),
                  const SizedBox(height: 20),
                  _Group(
                    title: 'Rank',
                    aside: _draft.ranks.isEmpty
                        ? null
                        : '${_draft.ranks.length} selected',
                    asideColor: AppColors.terracotta,
                    rows: _pairs(SearchRank.values),
                    option: (rank) => _Option(
                      label: rank.label,
                      selected: _draft.ranks.contains(rank),
                      onTap: () =>
                          setState(() => _draft = _draft.toggleRank(rank)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Group(
                    title: 'Family',
                    aside: _draft.families.isEmpty
                        ? 'Any family'
                        : '${_draft.families.length} selected',
                    asideColor: _draft.families.isEmpty
                        ? AppColors.body
                        : AppColors.terracotta,
                    rows: _pairs(SearchFilters.familyChoices),
                    option: (family) => _Option(
                      label: family,
                      selected: _draft.families.contains(family),
                      onTap: () => setState(
                        () => _draft = _draft.toggleFamily(family),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Group(
                    title: 'Only',
                    aside: 'Optional',
                    asideColor: AppColors.body,
                    rows: const [
                      ['Edible', 'Vegetable'],
                    ],
                    option: (label) => _Option(
                      label: label,
                      selected: label == 'Edible'
                          ? _draft.edible
                          : _draft.vegetable,
                      onTap: () => setState(() {
                        _draft = label == 'Edible'
                            ? _draft.toggleEdible()
                            : _draft.toggleVegetable();
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          count == 1
                              ? '1 filter selected'
                              : '$count filters selected',
                          style: AppText.body.copyWith(
                            color: AppColors.body,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: count == 0
                            ? null
                            : () => setState(() => _draft = const SearchFilters()),
                        child: Text(
                          'Clear all',
                          style: AppText.label.copyWith(
                            color: AppColors.terracotta,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ApplyButton(
                    count: count,
                    onPressed: () => widget.onApply(_draft),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group<T> extends StatelessWidget {
  const _Group({
    required this.title,
    required this.aside,
    required this.asideColor,
    required this.rows,
    required this.option,
  });

  final String title;
  final String? aside;
  final Color asideColor;
  final List<List<T>> rows;
  final Widget Function(T value) option;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppText.title.copyWith(color: AppColors.ink),
              ),
            ),
            if (aside != null)
              Text(
                aside!,
                style: AppText.labelMedium.copyWith(color: asideColor),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final row in rows) ...[
          Row(
            children: [
              for (var index = 0; index < row.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(child: option(row[index])),
              ],
              if (row.length == 1) ...[
                const SizedBox(width: 8),
                const Expanded(child: SizedBox(height: 40)),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.terracotta : AppColors.body;
    return Material(
      color: selected ? AppColors.surfaceWarm : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            border: Border.all(
              color: selected ? AppColors.terracotta : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              _Check(selected: selected),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.fieldLabel.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? AppColors.terracotta : AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: selected ? AppColors.terracotta : AppColors.border,
        ),
      ),
      child: SizedBox(
        width: 18,
        height: 18,
        child: selected
            ? Center(
                child: SvgPicture.asset(
                  AppIcons.resultSelectedCheck,
                  width: 12,
                  height: 12,
                ),
              )
            : null,
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.terracotta,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Apply filters',
                style: AppText.title.copyWith(color: AppColors.surface),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: AppText.body.copyWith(
                      color: AppColors.surface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back to search',
      child: Material(
        color: AppColors.surfaceBlush,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: SvgPicture.asset(AppIcons.flowBack, width: 18, height: 18),
            ),
          ),
        ),
      ),
    );
  }
}

List<List<T>> _pairs<T>(List<T> items) {
  final rows = <List<T>>[];
  for (var index = 0; index < items.length; index += 2) {
    final end = index + 2 > items.length ? items.length : index + 2;
    rows.add(items.sublist(index, end));
  }
  return rows;
}
