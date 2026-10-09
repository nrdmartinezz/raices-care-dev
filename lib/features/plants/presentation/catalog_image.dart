import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/assets.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/authenticated_image.dart';

/// A species photo that arrives with a search result.
///
/// Catalog hosts such as Trefle do not send CORS headers, so on the web the
/// picture is drawn in an HTML element instead of fetched as bytes. Worker
/// catalog photos are private and go out with the signed-in token.
class CatalogImage extends ConsumerWidget {
  const CatalogImage({super.key, required this.url, this.fit = BoxFit.cover});

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = url;
    if (address == null || address.isEmpty) {
      return const _CatalogImagePlaceholder();
    }

    final ImageProvider image = address.startsWith('/v1/')
        ? AuthenticatedImage(ref.watch(apiClientProvider), address)
        : NetworkImage(
            address,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          );

    return Image(
      image: image,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return const _CatalogImageLoading();
      },
      errorBuilder: (context, error, stackTrace) =>
          const _CatalogImagePlaceholder(),
    );
  }
}

/// Shown while a search-result photo is still coming in.
class _CatalogImageLoading extends StatelessWidget {
  const _CatalogImageLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceBlush,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.green,
          ),
        ),
      ),
    );
  }
}

/// Trefle often has no photo, and a failed load has to stand alone.
class _CatalogImagePlaceholder extends StatelessWidget {
  const _CatalogImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceBlush,
      child: Center(
        child: Opacity(
          opacity: 0.7,
          child: _Sprout(),
        ),
      ),
    );
  }
}

class _Sprout extends StatelessWidget {
  const _Sprout();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(AppIcons.growingSprout, width: 24, height: 24);
  }
}
