// lib/screens/premium_meditation_screen.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

const Color kDark = Color(0xFF01161E);
const Color kDeepBlue = Color(0xFF124559);
const Color kBlueGrey = Color(0xFF598392);
const Color kSoftGreen = Color(0xFFAEC3B0);
const Color kLight = Color(0xFFEFF6E0);

class PremiumMeditationScreen extends StatefulWidget {
  const PremiumMeditationScreen({super.key});

  @override
  State<PremiumMeditationScreen> createState() => _PremiumMeditationScreenState();
}

class _PremiumMeditationScreenState extends State<PremiumMeditationScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _nowPlaying;
  bool _playing = false;

  final List<_Track> _tracks = const [
    _Track("10-min Deep Meditation", "assets/sounds/meditation_10min.mp3"),
    _Track("Frequency 1 (2-3 min)", "assets/sounds/frequency_1.mp3"),
    _Track("Frequency 2 (2-3 min)", "assets/sounds/frequency_2.mp3"),
    _Track("Frequency 3 (2-3 min)", "assets/sounds/frequency_3.mp3"),
  ];

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      setState(() => _playing = s == PlayerState.playing);
    });
  }

  Future<void> _play(String title, String assetPath) async {
    await _player.stop();
    setState(() => _nowPlaying = title);
    await _player.play(AssetSource(assetPath.replaceFirst("assets/", "")));
  }

  Future<void> _pauseOrResume() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _stop() async {
    await _player.stop();
    setState(() => _nowPlaying = null);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDark,
      appBar: AppBar(
        backgroundColor: kDark,
        foregroundColor: kLight,
        elevation: 0,
        title: const Text("Premium Meditation"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kDeepBlue.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Open Your Third Eye",
                    style: TextStyle(
                      color: kLight,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Close your eyes.\nBreathe slowly.\nFeel, don’t look.\nYou are part of everything.",
                    style: TextStyle(
                      color: kSoftGreen,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              "Audio sessions",
              style: TextStyle(
                color: kLight.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: ListView.separated(
                itemCount: _tracks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final t = _tracks[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _play(t.title, t.assetPath),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kBlueGrey.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.graphic_eq, color: kSoftGreen),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              t.title,
                              style: const TextStyle(color: kLight, fontSize: 14),
                            ),
                          ),
                          Icon(
                            (_nowPlaying == t.title && _playing)
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: kSoftGreen,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_nowPlaying != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kDeepBlue.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _nowPlaying!,
                        style: const TextStyle(
                          color: kLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _pauseOrResume,
                      icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                      color: kSoftGreen,
                    ),
                    IconButton(
                      onPressed: _stop,
                      icon: const Icon(Icons.stop),
                      color: kSoftGreen,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Track {
  final String title;
  final String assetPath;
  const _Track(this.title, this.assetPath);
}
