import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import 'add_plant_flow.dart';

/// The central add button's destination.
///
/// Routed above the shell rather than as a tab, so the bottom nav is hidden
/// and the flow reads as a task you finish or abandon. The same flow is the
/// last page of onboarding.
class AddPlantScreen extends ConsumerWidget {
  const AddPlantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experience = ref.watch(userProfileProvider).value?.gardenerExperience;
    final explain = experience != GardenerExperience.experienced;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            12,
            AppSizes.screenPadding,
            12,
          ),
          child: AddPlantFlow(
            explain: explain,
            onClose: () => _leave(context),
            onCreated: () async => _leave(context),
          ),
        ),
      ),
    );
  }

  void _leave(BuildContext context) {
    if (!context.mounted) {
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(HomeRoute.name);
    }
  }
}
