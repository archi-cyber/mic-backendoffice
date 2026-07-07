import 'package:flutter/material.dart';

/// Branded MIC logo used across splash, auth, and shell headers.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    required this.size,
    this.circular = false,
  });

  final double size;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/app_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (!circular) return image;

    return ClipOval(child: image);
  }
}
