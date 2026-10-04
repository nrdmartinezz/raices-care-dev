import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/widgets/auth_primary_button.dart';
import '../../photos/presentation/photo_picker.dart';
import '../../plants/presentation/add_plant_flow.dart';
import '../../settings/data/user_settings_repository.dart';
import '../data/avatar_repository.dart';
import '../data/hardiness_zone_repository.dart';
import '../domain/hardiness_zone.dart';

/// Experience, name, ZIP, then the shared add-plant flow.
///
/// Finishing requires a confirmed zone. The plant itself can be skipped.
/// Leaving this route is the router's job, once [AppUser.onboardingCompletedAt]
/// is written.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  final _zip = TextEditingController();

  GardenerExperience? _experience;
  PickedGardenPhoto? _photo;
  HardinessZone? _zone;
  var _step = 0;
  var _saving = false;
  String? _error;

  bool get _explain => _experience != GardenerExperience.experienced;

  bool get _zoneReady {
    final zone = _zone;
    return zone != null && zone.postalCode == _zip.text.trim();
  }

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProfileProvider).value;
    _experience = user?.gardenerExperience;
    _name.text = user?.displayName ?? '';

    final savedZip = user?.homeLocation.postalCode;
    final savedZone = user?.homeLocation.hardinessZone;
    if (savedZip != null) {
      _zip.text = savedZip;
    }
    if (savedZip != null && savedZone != null) {
      _zone = HardinessZone(
        postalCode: savedZip,
        zone: savedZone,
        temperatureRange: '',
      );
      _step = 3;
    } else if (_experience != null) {
      _step = 1;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _zip.dispose();
    super.dispose();
  }

  AppUser _current() {
    final existing = ref.read(userProfileProvider).value;
    if (existing != null) {
      return existing;
    }
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) {
      throw const UnauthenticatedException();
    }
    return AppUser(id: uid);
  }

  Future<void> _saveExperience() async {
    final experience = _experience;
    if (experience == null) {
      return;
    }
    await _run(() async {
      await ref
          .read(authRepositoryProvider)
          .updateProfile(_current().copyWith(gardenerExperience: experience));
      if (mounted) {
        setState(() => _step = 1);
      }
    });
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await pickGardenPhoto(context);
      if (picked != null && mounted) {
        setState(() => _photo = picked);
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    }
  }

  Future<void> _saveName() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    if (name.length > 120) {
      setState(() => _error = 'Use a shorter name.');
      return;
    }

    await _run(() async {
      final photo = _photo;
      String? avatarPath;
      if (photo != null) {
        avatarPath = await ref
            .read(avatarRepositoryProvider)
            .uploadAvatar(bytes: photo.bytes, contentType: photo.contentType);
      }
      var user = _current().copyWith(displayName: name);
      if (avatarPath != null) {
        user = user.copyWith(avatarPath: avatarPath);
      }
      final repository = ref.read(authRepositoryProvider);
      await repository.updateProfile(user);
      await repository.updateAuthDisplayName(name);
      if (mounted) {
        setState(() => _step = 2);
      }
    });
  }

  Future<void> _lookupZip() async {
    final zip = _zip.text.trim();
    if (!RegExp(r'^\d{5}$').hasMatch(zip)) {
      setState(() => _error = 'Enter a 5-digit US ZIP.');
      return;
    }

    await _run(() async {
      final found = await ref.read(hardinessZoneRepositoryProvider).lookup(zip);
      final current = _current();
      await ref
          .read(authRepositoryProvider)
          .updateProfile(
            current.copyWith(
              homeLocation: current.homeLocation.copyWith(
                countryCode: 'US',
                postalCode: zip,
                hardinessZone: found.zone,
              ),
            ),
          );
      if (mounted) {
        setState(() => _zone = found);
      }
    });
  }

  Future<void> _finish() {
    return ref.read(authRepositoryProvider).completeOnboarding();
  }

  Future<void> _signOut() async {
    try {
      await ref.read(userSettingsRepositoryProvider).removeCurrentDeviceToken();
    } on Object {
      // A stale token is better than being unable to leave.
    }
    await ref.read(authRepositoryProvider).signOut();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) {
        setState(() => _saving = false);
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Something went wrong.';
        });
      }
    }
  }

  void _back() {
    setState(() {
      _error = null;
      _step -= 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final onPlant = _step == 3;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding,
              12,
              AppSizes.screenPadding,
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Progress(step: _step),
                const SizedBox(height: 8),
                if (_step > 0)
                  TextButton(
                    onPressed: _saving ? null : _back,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: Text(
                      'Back',
                      style: AppText.label.copyWith(
                        color: AppColors.terracotta,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 8),
                Expanded(
                  child: onPlant
                      ? AddPlantFlow(
                          explain: _explain,
                          eyebrow: 'FIRST PLANT',
                          title: 'Add your first plant',
                          onCreated: _finish,
                          onSkip: _finish,
                        )
                      : SingleChildScrollView(child: _stepBody()),
                ),
                if (!onPlant) ...[
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: AppText.body.copyWith(
                        color: AppColors.terracottaBright,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  AuthPrimaryButton(
                    label: _step == 2 && !_zoneReady
                        ? 'Look up zone'
                        : 'Continue',
                    isLoading: _saving,
                    onPressed: _saving ? null : _primaryAction(),
                  ),
                  if (_step == 0)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _saving ? null : _signOut,
                        child: Text(
                          'Sign out',
                          style: AppText.label.copyWith(color: AppColors.muted),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  VoidCallback? _primaryAction() {
    return switch (_step) {
      0 => _experience == null ? null : _saveExperience,
      1 => _saveName,
      2 => _zoneReady ? () => setState(() => _step = 3) : _lookupZip,
      _ => null,
    };
  }

  Widget _stepBody() {
    return switch (_step) {
      0 => _experienceStep(),
      1 => _nameStep(),
      _ => _zipStep(),
    };
  }

  Widget _experienceStep() {
    final experience = _experience;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeading(
          eyebrow: 'YOUR GARDEN',
          title: 'How experienced are you?',
        ),
        const SizedBox(height: 8),
        Text(
          'This only changes how much we explain.',
          style: AppText.body.copyWith(color: AppColors.body),
        ),
        const SizedBox(height: 16),
        _OptionCard(
          title: 'New to growing',
          detail: "Explain each step.",
          selected: experience == GardenerExperience.beginner,
          onTap: _saving
              ? null
              : () => setState(() {
                  _experience = GardenerExperience.beginner;
                  _error = null;
                }),
        ),
        const SizedBox(height: 8),
        _OptionCard(
          title: "I've grown plants before",
          detail: 'Keep it short.',
          selected: experience == GardenerExperience.experienced,
          onTap: _saving
              ? null
              : () => setState(() {
                  _experience = GardenerExperience.experienced;
                  _error = null;
                }),
        ),
        if (experience == GardenerExperience.beginner) ...[
          const SizedBox(height: 16),
          const _Hint(
            "We'll confirm your name, and you can add a photo if you want one.",
          ),
          const SizedBox(height: 6),
          const _Hint('A US ZIP looks up your 2023 hardiness zone.'),
          const SizedBox(height: 6),
          const _Hint(
            'Then you can add a first plant, or skip it and do that later.',
          ),
        ],
        if (experience == GardenerExperience.experienced) ...[
          const SizedBox(height: 16),
          const _Hint('Name, ZIP, then a plant if you want one.'),
        ],
      ],
    );
  }

  Widget _nameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeading(
          eyebrow: 'YOUR NAME',
          title: 'What should we call you?',
        ),
        if (_explain) ...[
          const SizedBox(height: 8),
          Text(
            'This is the name your garden greets you by. A photo is optional.',
            style: AppText.body.copyWith(color: AppColors.body),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Your name',
          style: AppText.fieldLabel.copyWith(color: AppColors.body),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _name,
          enabled: !_saving,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          style: AppText.input.copyWith(color: AppColors.ink),
          cursorColor: AppColors.terracotta,
          decoration: _decoration('Name'),
        ),
        const SizedBox(height: 16),
        Text(
          'Photo',
          style: AppText.fieldLabel.copyWith(color: AppColors.body),
        ),
        const SizedBox(height: 4),
        Text('Optional.', style: AppText.body.copyWith(color: AppColors.muted)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _saving ? null : _pickPhoto,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlush,
                  shape: BoxShape.circle,
                  image: _photo == null
                      ? null
                      : DecorationImage(
                          image: MemoryImage(_photo!.bytes),
                          fit: BoxFit.cover,
                        ),
                ),
                child: _photo == null
                    ? const Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.muted,
                      )
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                _photo == null ? 'Add a photo' : 'Change photo',
                style: AppText.label.copyWith(color: AppColors.terracotta),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _zipStep() {
    final zone = _zoneReady ? _zone : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeading(eyebrow: 'YOUR ZONE', title: 'Where do you garden?'),
        if (_explain) ...[
          const SizedBox(height: 8),
          Text(
            'A US ZIP finds your 2023 hardiness zone, the winter cold your garden can expect.',
            style: AppText.body.copyWith(color: AppColors.body),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'ZIP code',
          style: AppText.fieldLabel.copyWith(color: AppColors.body),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _zip,
          enabled: !_saving,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          onChanged: (value) {
            final confirmed = _zone;
            if (confirmed != null && confirmed.postalCode != value.trim()) {
              setState(() => _zone = null);
            }
          },
          style: AppText.input.copyWith(color: AppColors.ink),
          cursorColor: AppColors.terracotta,
          decoration: _decoration('5-digit US ZIP'),
        ),
        if (zone != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zone ${zone.zone}',
                  style: AppText.display.copyWith(color: AppColors.ink),
                ),
                if (zone.temperatureLabel case final range?) ...[
                  const SizedBox(height: 4),
                  Text(
                    range,
                    style: AppText.title.copyWith(color: AppColors.body),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '2023 USDA zone from the ZIP listing, not the official interactive map.',
                  style: AppText.body.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

InputDecoration _decoration(String hint) => InputDecoration(
  isDense: true,
  filled: true,
  fillColor: AppColors.surfaceBlush,
  hintText: hint,
  hintStyle: AppText.input.copyWith(color: AppColors.muted),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
  border: _border(),
  enabledBorder: _border(),
  disabledBorder: _border(),
  focusedBorder: _border(AppColors.terracotta),
);

InputBorder _border([Color? color]) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppSizes.imageRadius),
  borderSide: color == null
      ? BorderSide.none
      : BorderSide(color: color, width: 1.5),
);

class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < 4; index++) ...[
          if (index > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: index <= step ? AppColors.terracotta : AppColors.track,
                borderRadius: BorderRadius.circular(AppSizes.pill),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow, style: AppText.eyebrow.copyWith(color: AppColors.green)),
        const SizedBox(height: 2.5),
        Text(title, style: AppText.display.copyWith(color: AppColors.ink)),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppText.body.copyWith(color: AppColors.body));
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String detail;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surfaceWarm : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            border: Border.all(
              color: selected ? AppColors.terracotta : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.title.copyWith(color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(detail, style: AppText.body.copyWith(color: AppColors.body)),
            ],
          ),
        ),
      ),
    );
  }
}
