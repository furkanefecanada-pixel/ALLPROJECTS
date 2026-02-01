// lib/screens/paywall_screen.dart
import 'package:flutter/material.dart';
import '../iap/iap_service.dart';

const Color kDark = Color(0xFF01161E);
const Color kDeepBlue = Color(0xFF124559);
const Color kBlueGrey = Color(0xFF598392);
const Color kSoftGreen = Color(0xFFAEC3B0);
const Color kLight = Color(0xFFEFF6E0);

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final iap = IAPService.I;

    return AnimatedBuilder(
      animation: iap,
      builder: (context, _) {
        final priceText = iap.product?.price ?? "\$2.99";
        final subtitle = iap.available
            ? "Unlock the full 10-minute meditation + frequency audios."
            : "Store is not available on this device right now.";

        return Scaffold(
          backgroundColor: kDark,
          appBar: AppBar(
            backgroundColor: kDark,
            foregroundColor: kLight,
            elevation: 0,
            title: const Text("Premium"),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Close Brain Pages Premium",
                        style: TextStyle(
                          color: kLight,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: kSoftGreen.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _benefit("Full guided meditation (10 min)"),
                      _benefit("Frequency sessions (2-3 min)"),
                      _benefit("Calmer routine, deeper focus"),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (iap.lastError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      iap.lastError!,
                      style: const TextStyle(color: kLight, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

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
                        onPressed: iap.available && !iap.isBusy ? iap.restore : null,
                        child: const Text("Restore"),
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
                        onPressed: iap.available && !iap.isBusy ? iap.subscribe : null,
                        child: Text(
                          iap.isBusy ? "Loading..." : "Subscribe • $priceText / month",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "Subscription auto-renews unless canceled at least 24 hours before the end of the period. Manage in Apple ID settings.",
                  style: TextStyle(
                    color: kLight.withOpacity(0.6),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _benefit(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: kSoftGreen, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t,
              style: const TextStyle(color: kLight, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
