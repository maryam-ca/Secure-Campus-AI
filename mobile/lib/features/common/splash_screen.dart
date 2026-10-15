import 'package:flutter/material.dart';

import '../../core/widgets/animated_shield_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnimatedShieldLogo(size: 84),
            const SizedBox(height: 20),
            Text('SecureCampus', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
            const SizedBox(height: 24),
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ],
        ),
      ),
    );
  }
}
