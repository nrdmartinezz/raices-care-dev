import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/assets.dart';
import '../../../../app/theme.dart';

/// A labelled form field in the auth card's blush style.
///
/// The leading glyph is centred in a 48px gutter rather than positioned by the
/// numbers in the design: both of the design's icons resolve to the same
/// centre point, and centring keeps that true for glyphs of other widths.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    required this.iconSize,
    this.hintText,
    this.trailingLabel,
    this.onTrailingLabelTap,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String icon;
  final Size iconSize;
  final String? hintText;

  /// The "Forgot?" affordance, drawn at the far end of the label row.
  final String? trailingLabel;
  final VoidCallback? onTrailingLabelTap;

  /// Obscures the text and adds the eye toggle from the design.
  final bool isPassword;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmitted;
  final bool enabled;

  static const height = 48.0;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _obscured = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: AppText.fieldLabel.copyWith(color: AppColors.body),
              ),
            ),
            if (widget.trailingLabel case final trailing?)
              GestureDetector(
                onTap: widget.onTrailingLabelTap,
                child: Text(
                  trailing,
                  style: AppText.label.copyWith(color: AppColors.terracotta),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            TextFormField(
              controller: widget.controller,
              enabled: widget.enabled,
              obscureText: _obscured,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              autofillHints: widget.autofillHints,
              validator: widget.validator,
              onFieldSubmitted: (_) => widget.onSubmitted?.call(),
              style: AppText.input.copyWith(color: AppColors.ink),
              cursorColor: AppColors.terracotta,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceBlush,
                hintText: widget.hintText,
                hintStyle: AppText.input.copyWith(color: AppColors.muted),
                contentPadding: EdgeInsets.only(
                  left: 44,
                  right: widget.isPassword ? 44 : 16,
                  top: 15,
                  bottom: 15,
                ),
                border: _border(),
                enabledBorder: _border(),
                disabledBorder: _border(),
                focusedBorder: _border(AppColors.terracotta),
                errorBorder: _border(AppColors.terracottaBright),
                focusedErrorBorder: _border(AppColors.terracottaBright),
                errorStyle: AppText.body.copyWith(
                  color: AppColors.terracottaBright,
                ),
              ),
            ),
            // Anchored to the top of the stack so the error line, which grows
            // beneath the field, does not drag the glyphs down with it.
            Positioned(
              left: 0,
              top: 0,
              width: AuthField.height,
              height: AuthField.height,
              child: Center(
                child: SvgPicture.asset(
                  widget.icon,
                  width: widget.iconSize.width,
                  height: widget.iconSize.height,
                ),
              ),
            ),
            if (widget.isPassword)
              Positioned(
                right: 12,
                top: 10,
                child: Semantics(
                  button: true,
                  label: _obscured ? 'Show password' : 'Hide password',
                  child: GestureDetector(
                    onTap: () => setState(() => _obscured = !_obscured),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Opacity(
                        opacity: _obscured ? 1 : 0.45,
                        child: SvgPicture.asset(
                          AppIcons.fieldEye,
                          width: 18.333,
                          height: 12.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  InputBorder _border([Color? color]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppSizes.imageRadius),
    borderSide: color == null
        ? BorderSide.none
        : BorderSide(color: color, width: 1.5),
  );
}
