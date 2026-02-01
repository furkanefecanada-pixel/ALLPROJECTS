import 'dart:ui';
import 'package:flutter/material.dart';
import '../app/theme.dart';

class GradientScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget child;
  final Widget? bottomNavigationBar;

  const GradientScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [DSColors.bgTop, DSColors.bgBottom],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        bottomNavigationBar: bottomNavigationBar,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -120,
                left: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DSColors.neonPink.withOpacity(0.18),
                  ),
                ),
              ),
              Positioned(
                bottom: -120,
                right: -80,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DSColors.softLilac.withOpacity(0.14),
                  ),
                ),
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: const SizedBox.expand(),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
