// lib/iap/iap_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IAPService extends ChangeNotifier {
  IAPService._();
  static final IAPService I = IAPService._();

  static const String kPremiumProductId = 'premiumsubcloseyourbrain';
  static const String _kPremiumPrefKey = 'is_premium_v1';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _available = false;
  bool get available => _available;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  ProductDetails? _product;
  ProductDetails? get product => _product;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  String? _lastError;
  String? get lastError => _lastError;

  Future<void> init() async {
    // load cached premium status
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_kPremiumPrefKey) ?? false;

    _available = await _iap.isAvailable();
    notifyListeners();

    if (!_available) return;

    // Listen purchase updates
    _sub?.cancel();
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (e) {
        _lastError = e.toString();
        notifyListeners();
      },
    );

    await _loadProduct();
    // Restore on init (helps get premium back automatically)
    await restore();
  }

  Future<void> _loadProduct() async {
    _isBusy = true;
    _lastError = null;
    notifyListeners();

    final response = await _iap.queryProductDetails({kPremiumProductId});
    if (response.error != null) {
      _lastError = response.error!.message;
      _product = null;
    } else {
      _product = response.productDetails.isNotEmpty ? response.productDetails.first : null;
      if (_product == null) {
        _lastError = "Product not found: $kPremiumProductId";
      }
    }

    _isBusy = false;
    notifyListeners();
  }

  Future<void> subscribe() async {
    if (!_available) return;
    if (_product == null) await _loadProduct();
    if (_product == null) return;

    _isBusy = true;
    _lastError = null;
    notifyListeners();

    final purchaseParam = PurchaseParam(productDetails: _product!);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);

    // purchaseStream will finalize & set premium
  }

  Future<void> restore() async {
    if (!_available) return;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> _setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPremiumPrefKey, value);
    notifyListeners();
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      // If pending, just wait
      if (p.status == PurchaseStatus.pending) {
        _isBusy = true;
        notifyListeners();
        continue;
      }

      if (p.status == PurchaseStatus.error) {
        _isBusy = false;
        _lastError = p.error?.message ?? 'Purchase error';
        notifyListeners();
      }

      // Purchased or Restored -> unlock premium
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        // NOTE: For best security use server-side receipt validation.
        // Here we accept as premium for MVP.
        await _setPremium(true);
      }

      // Always complete purchase if needed
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }

      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
