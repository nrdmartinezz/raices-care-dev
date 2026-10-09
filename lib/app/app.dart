import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/presentation/care_notifications.dart';
import 'router.dart';
import 'theme.dart';

class RaicesApp extends ConsumerWidget {
  const RaicesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CareNotifications(
      child: MaterialApp.router(
        title: 'Raíces',
        debugShowCheckedModeBanner: false,
        theme: buildRaicesTheme(),
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
