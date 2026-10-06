import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';
import '../../core/api/authenticated_image.dart';
import '../../features/onboarding/data/avatar_repository.dart';
import '../assets.dart';

/// The signed-in gardener's photo, or the bundled placeholder.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, this.path, this.size = 32});

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = Image.asset(
      AppImages.profile,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
    final stored = path;
    if (stored == null) {
      return ClipOval(child: placeholder);
    }

    final url = ref.watch(avatarUrlProvider(stored));
    if (url == workerAvatarPath) {
      return ClipOval(
        child: Image(
          image: AuthenticatedImage(ref.watch(apiClientProvider), '/v1/me/avatar'),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => placeholder,
        ),
      );
    }
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}
