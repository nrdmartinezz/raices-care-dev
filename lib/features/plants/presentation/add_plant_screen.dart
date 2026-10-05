import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/shell/flow_header.dart';
import '../../../app/theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import 'add_plant_flow.dart';

/// The central add button's destination.
///
/// Routed above the shell rather than as a tab, so the bottom nav is hidden
/// and the flow reads as a task you finish or abandon. The same flow is the
/// last page of onboarding.
class AddPlantScreen extends ConsumerStatefulWidget {
  const AddPlantScreen({super.key});

  @override
  ConsumerState<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends ConsumerState<AddPlantScreen> {
  final _flow = GlobalKey<AddPlantFlowState>();
  var _step = 1;

  /// Step 2 goes back to the search rather than off the screen.
  void _back() {
    if (_flow.currentState?.goBack() ?? false) {
      return;
    }
    _leave();
  }

  void _leave() {
    if (!mounted) {
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(HomeRoute.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final experience = ref.watch(userProfileProvider).value?.gardenerExperience;
    final explain = experience != GardenerExperience.experienced;
    final insets = MediaQuery.viewPaddingOf(context);

    return PopScope(
      canPop: _step == 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _flow.currentState?.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  AppSizes.headerHeight + insets.top,
                  AppSizes.screenPadding,
                  insets.bottom,
                ),
                child: AddPlantFlow(
                  key: _flow,
                  explain: explain,
                  onCreated: _openPlant,
                  onStepChanged: (step) => setState(() => _step = step),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: FlowHeader(
                eyebrow: 'STEP $_step OF 3',
                title: _step == 1 ? 'Choose a plant' : 'Plant setup',
                onBack: _back,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The third step is the plant itself: its profile, with the care rhythm the
  /// create trigger just seeded.
  Future<void> _openPlant(String plantId) async {
    if (!mounted) {
      return;
    }
    // `go` rather than `push`: the profile lives in the My Plants branch, and
    // leaving it should land on that list, not back in the finished flow.
    context.goNamed(
      PlantDetailRoute.name,
      pathParameters: {'plantId': plantId},
      queryParameters: {'new': '1'},
    );
  }
}
