import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/assets.dart';
import '../../../app/shell/app_shell.dart';
import '../../../app/theme.dart';
import 'account_widgets.dart';
import 'support_links.dart';

/// Bug reports and optional Patreon support, opened from the profile.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String? _failedUrl;

  Future<void> _open(String url) async {
    setState(() => _failedUrl = null);
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        setState(() => _failedUrl = url);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _failedUrl = url);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvas,
      child: ShellScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Support', style: accountPageTitle),
            const SizedBox(height: 6),
            Text(
              'A little help goes a long way. Let’s keep Raíces growing together.',
              style: AppText.bodyLarge.copyWith(color: AppColors.body),
            ),
            const SizedBox(height: AppSizes.sectionGap),
            _SupportCard(
              icon: AppIcons.supportBug,
              title: 'Report a bug',
              body: 'Something not working as expected? Tell us what happened so we can make it better.',
              actionLabel: 'Report a bug',
              footnote:
                  'Include the steps you took and a screenshot, if you can.',
              failed: _failedUrl == SupportLinks.githubIssues,
              onPressed: () => _open(SupportLinks.githubIssues),
            ),
            const SizedBox(height: AppSizes.sectionGap),
            _SupportCard(
              icon: AppIcons.supportHeart,
              title: 'Support on Patreon',
              body: 'Help nurture Raíces. Your support helps us care for the app and bring new features to life.',
              actionLabel: 'Support on Patreon',
              actionIcon: AppIcons.supportExternal,
              footnote:
                  'Opens Patreon in your browser. Support is always optional.',
              failed: _failedUrl == SupportLinks.patreon,
              onPressed: () => _open(SupportLinks.patreon),
            ),
            const SizedBox(height: AppSizes.sectionGap),
            const _Appreciation(),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.footnote,
    required this.failed,
    required this.onPressed,
    this.actionIcon,
  });

  final String icon;
  final String title;
  final String body;
  final String actionLabel;
  final String? actionIcon;
  final String footnote;
  final bool failed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: accountCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AccountIconTile(icon: icon, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppText.title.copyWith(color: AppColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: AppText.bodyLarge.copyWith(
              fontSize: 13,
              height: 1.45,
              color: AppColors.body,
            ),
          ),
          const SizedBox(height: 16),
          _SupportButton(
            label: actionLabel,
            icon: actionIcon,
            onPressed: onPressed,
          ),
          const SizedBox(height: 16),
          Text(
            footnote,
            style: AppText.caption.copyWith(
              color: AppColors.body,
              height: 1.45,
            ),
          ),
          if (failed) ...[
            const SizedBox(height: 8),
            const AccountMessage(
              message: 'That page could not be opened.',
              isError: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _SupportButton extends StatelessWidget {
  const _SupportButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.terracotta,
          foregroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.subtitleBold.copyWith(color: AppColors.surface),
            ),
            if (icon != null) ...[
              const SizedBox(width: 8),
              SvgPicture.asset(icon!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Appreciation extends StatelessWidget {
  const _Appreciation();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AppIcons.supportSprout),
            const SizedBox(width: 8),
            Text(
              'Thank you for helping Raíces grow.',
              style: AppText.caption.copyWith(color: AppColors.body),
            ),
          ],
        ),
      ),
    );
  }
}
