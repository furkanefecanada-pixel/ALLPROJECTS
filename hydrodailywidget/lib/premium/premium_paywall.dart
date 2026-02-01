import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'premium_service.dart';

class PremiumPaywall extends StatefulWidget {
  const PremiumPaywall({super.key});

  @override
  State<PremiumPaywall> createState() => _PremiumPaywallState();
}

class _PremiumPaywallState extends State<PremiumPaywall> {
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    // Paywall açılır açılmaz ürün çek
    Future.microtask(() => PremiumService.I.refreshProducts(force: true));
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not open: $url")),
      );
    }
  }

  Future<void> _onUpgradePressed() async {
    final s = PremiumService.I;

    if (_buying) return;
    setState(() => _buying = true);

    try {
      if (!s.isAvailable) {
        throw Exception(s.lastIapError ?? "Store not available");
      }

      // Ürün yoksa önce zorla çek
      if (s.monthly == null) {
        await s.refreshProducts(force: true);
      }

      await s.buyMonthly();

      // satın alma sonucu purchaseStream ile geleceği için burada ekstra iş yok
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Purchase failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = PremiumService.I;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              _TopBar(onClose: () => Navigator.pop(context)),
              const SizedBox(height: 10),
              Text(
                'PREMIUM',
                style: TextStyle(
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: _purple,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Unlock Unlimited Friends',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Remove the friend limit and add as many friends as you want.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.35,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                height: 150,
                width: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Icon(Icons.favorite_rounded, size: 64, color: _purple),
                ),
              ),
              const SizedBox(height: 18),
              const _FeatureRow(
                icon: Icons.group_add_rounded,
                title: 'Unlimited Friends',
                desc: 'Add more friends without restrictions.',
              ),
              const SizedBox(height: 10),
              const _FeatureRow(
                icon: Icons.lock_open_rounded,
                title: 'Premium Access',
                desc: 'Get full access to friend features.',
              ),
              const SizedBox(height: 10),
              const _FeatureRow(
                icon: Icons.restore_rounded,
                title: 'Restore Anytime',
                desc: 'Already subscribed? Restore your purchase in one tap.',
              ),
              const Spacer(),

              // ✅ Ürün stream: artık subscription olur olmaz mevcut value da gelir (service fix)
              StreamBuilder<ProductDetails?>(
                stream: s.productStream,
                builder: (context, snap) {
                  final product = snap.data ?? s.monthly;

                  final priceText = (product == null)
                      ? 'Continue'
                      : '${product.price} / month';

                  // ✅ Buton: store available ise her zaman basılabilir
                  final canTap = !_buying && s.isAvailable;

                  return SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: canTap ? _onUpgradePressed : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: _buying
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              product == null
                                  ? 'Upgrade'
                                  : 'Upgrade • $priceText',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),

              // ✅ Debug / info (store product gelmiyorsa sebebi burada görünür)
              StreamBuilder<String?>(
                stream: s.iapErrorStream,
                builder: (context, snap) {
                  final err = snap.data;
                  if (err == null || err.trim().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      err,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => PremiumService.I.restore(),
                    child: const Text('Restore Purchase'),
                  ),
                  const SizedBox(width: 6),
                  const Text('•', style: TextStyle(color: Color(0xFF9CA3AF))),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => _openUrl("https://tunahanoguz.netlify.app/terms"),
                    child: const Text('Terms'),
                  ),
                  const SizedBox(width: 6),
                  const Text('•', style: TextStyle(color: Color(0xFF9CA3AF))),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => _openUrl("https://tunahanoguz.netlify.app/privacy"),
                    child: const Text('Privacy'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _purple = Color(0xFF6D4CFF);

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
          color: const Color(0xFF111827),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF2EDFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _purple, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
