// lib/screens/third_eye_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../iap/iap_service.dart';
import 'paywall_screen.dart';
import 'premium_meditation_screen.dart';

const Color kDark = Color(0xFF01161E);
const Color kDeepBlue = Color(0xFF124559);
const Color kBlueGrey = Color(0xFF598392);
const Color kSoftGreen = Color(0xFFAEC3B0);
const Color kLight = Color(0xFFEFF6E0);

class ThirdEyeScreen extends StatefulWidget {
  const ThirdEyeScreen({super.key});

  @override
  State<ThirdEyeScreen> createState() => _ThirdEyeScreenState();
}

enum _Phase { inhale, hold, exhale }

class _ThirdEyeScreenState extends State<ThirdEyeScreen> with SingleTickerProviderStateMixin {
  // breathing config
  final int inhaleSec = 4;
  final int holdSec = 4;
  final int exhaleSec = 6;

  _Phase _phase = _Phase.inhale;
  int _secLeft = 4;
  int _cycle = 1;
  int _cyclesTotal = 6;

  Timer? _timer;
  bool _running = false;

  late final AnimationController _anim;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _secLeft = inhaleSec;

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scale = Tween<double>(begin: 0.85, end: 1.08).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
    );

    _anim.repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _running = true;
      _phase = _Phase.inhale;
      _secLeft = inhaleSec;
      _cycle = 1;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (_secLeft > 1) {
        setState(() => _secLeft -= 1);
        return;
      }

      // switch phase
      if (_phase == _Phase.inhale) {
        setState(() {
          _phase = _Phase.hold;
          _secLeft = holdSec;
        });
      } else if (_phase == _Phase.hold) {
        setState(() {
          _phase = _Phase.exhale;
          _secLeft = exhaleSec;
        });
      } else {
        // completed one cycle
        if (_cycle >= _cyclesTotal) {
          _stop();
        } else {
          setState(() {
            _cycle += 1;
            _phase = _Phase.inhale;
            _secLeft = inhaleSec;
          });
        }
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  String get _phaseTitle {
    switch (_phase) {
      case _Phase.inhale:
        return "Inhale";
      case _Phase.hold:
        return "Hold";
      case _Phase.exhale:
        return "Exhale";
    }
  }

  String get _guideText {
    // Senin istediğin vibe (free mode guidance)
    switch (_phase) {
      case _Phase.inhale:
        return "Close your eyes.\nBreathe in slowly.\nFeel the air, not the thoughts.";
      case _Phase.hold:
        return "Stay still.\nYou are part of everything.\nNo rush.";
      case _Phase.exhale:
        return "Let it go.\nDon’t look.\nJust feel.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final iap = IAPService.I;

    return Scaffold(
      backgroundColor: kDark,
      appBar: AppBar(
        backgroundColor: kDark,
        foregroundColor: kLight,
        elevation: 0,
        title: const Text("Open Your Third Eye"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kDeepBlue.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Breath Exercise",
                    style: TextStyle(
                      color: kLight,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Free mode: simple breathing, guided seconds.",
                    style: TextStyle(color: kSoftGreen.withOpacity(0.9), fontSize: 13),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _chip("Cycles", "$_cycle/$_cyclesTotal"),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _chip("Phase", _phaseTitle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _chip("Seconds", _secLeft.toString()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kBlueGrey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _anim,
                      builder: (context, child) {
                        final scale = _running ? _scale.value : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kDeepBlue.withOpacity(0.65),
                          border: Border.all(color: kSoftGreen.withOpacity(0.35), width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _phaseTitle.toUpperCase(),
                              style: const TextStyle(
                                color: kLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _secLeft.toString(),
                              style: const TextStyle(
                                color: kSoftGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 46,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _guideText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kLight, fontSize: 13, height: 1.35),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kSoftGreen,
                              side: BorderSide(color: kSoftGreen.withOpacity(0.6)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _running ? _stop : null,
                            child: const Text("Stop"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kSoftGreen,
                              foregroundColor: kDark,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: !_running ? _start : null,
                            child: const Text(
                              "Start",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Meditation section (premium gated)
            AnimatedBuilder(
              animation: iap,
              builder: (context, _) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kDeepBlue.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility, color: kSoftGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Meditation & Frequencies",
                              style: TextStyle(color: kLight, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              iap.isPremium
                                  ? "Premium unlocked. Tap to open."
                                  : "Premium required for deep meditation audios.",
                              style: TextStyle(color: kLight.withOpacity(0.75), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => iap.isPremium
                                  ? const PremiumMeditationScreen()
                                  : const PaywallScreen(),
                            ),
                          );
                        },
                        child: Text(
                          iap.isPremium ? "Open" : "Unlock",
                          style: const TextStyle(color: kSoftGreen),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: kDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: kSoftGreen.withOpacity(0.8), fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: kLight, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
