import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/assets.dart';
import '../../../app/theme.dart';

/// Newsreader 28/34. The profile and settings page titles.
TextStyle get accountPageTitle => GoogleFonts.newsreader(
  fontSize: 28,
  height: 34 / 28,
  fontWeight: FontWeight.w600,
  color: AppColors.ink,
);

BoxDecoration accountCardDecoration({bool bordered = false}) => BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(16),
  border: bordered ? Border.all(color: AppColors.border) : null,
  boxShadow: [
    BoxShadow(
      color: const Color(0xFF2C221E).withValues(alpha: 0.05),
      offset: const Offset(0, 2),
      blurRadius: 8,
    ),
  ],
);

/// A blush tile behind a small account glyph.
class AccountIconTile extends StatelessWidget {
  const AccountIconTile({super.key, required this.icon, this.size = 36});

  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceBlush,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SvgPicture.asset(icon),
    );
  }
}

/// A labelled field in the settings cards: uppercase label, 54px input.
class AccountField extends StatefulWidget {
  const AccountField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.enabled = true,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  State<AccountField> createState() => _AccountFieldState();
}

class _AccountFieldState extends State<AccountField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppText.eyebrow.copyWith(color: AppColors.body),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: widget.obscure && _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          validator: widget.validator,
          style: AppText.fieldLabel.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w400,
          ),
          cursorColor: AppColors.terracotta,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hint,
            hintStyle: AppText.fieldLabel.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w400,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            filled: true,
            fillColor: AppColors.surface,
            suffixIcon: widget.obscure ? _visibilityToggle() : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 18,
            ),
            border: _outline(),
            enabledBorder: _outline(),
            disabledBorder: _outline(),
            focusedBorder: _outline(AppColors.terracotta),
            errorBorder: _outline(AppColors.terracottaBright),
            focusedErrorBorder: _outline(AppColors.terracottaBright),
            errorStyle: AppText.body.copyWith(color: AppColors.terracotta),
          ),
        ),
      ],
    );
  }

  Widget _visibilityToggle() {
    return Semantics(
      button: true,
      label: _hidden ? 'Show password' : 'Hide password',
      child: GestureDetector(
        onTap: widget.enabled ? () => setState(() => _hidden = !_hidden) : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(right: 14),
          child: SvgPicture.asset(AppIcons.accountEyeOff),
        ),
      ),
    );
  }

  InputBorder _outline([Color color = AppColors.border]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );
}

class AccountUpdateButton extends StatelessWidget {
  const AccountUpdateButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.terracotta,
          disabledBackgroundColor: AppColors.terracotta.withValues(alpha: 0.6),
          foregroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.surface,
                ),
              )
            : Text(
                label,
                style: AppText.subtitleBold.copyWith(color: AppColors.surface),
              ),
      ),
    );
  }
}

class AccountMessage extends StatelessWidget {
  const AccountMessage({
    super.key,
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: AppText.body.copyWith(
        color: isError ? AppColors.terracotta : AppColors.green,
      ),
    );
  }
}
