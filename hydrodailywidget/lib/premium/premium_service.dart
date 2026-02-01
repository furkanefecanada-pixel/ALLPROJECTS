import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PremiumService {
  PremiumService._();
  static final PremiumService I = PremiumService._();

  static const String _kIsPremium = 'is_premium_local';

  /// App Store Connect product id (Auto-Renewable Subscription)
  static const String kMonthlyId = 'premiumwritenotes';

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _fireSub;

  final StreamController<bool> _premiumController =
      StreamController<bool>.broadcast();

  final StreamController<ProductDetails?> _productController =
      StreamController<ProductDetails?>.broadcast();

  final StreamController<String?> _iapErrorController =
      StreamController<String?>.broadcast();

  Future<void>? _initFuture;

  bool _isAvailable = false;
  bool _isPremium = false;

  ProductDetails? _monthly;
  String? _uid;

  String? _lastIapError;

  bool get isAvailable => _isAvailable;
  bool get isPremium => _isPremium;
  ProductDetails? get monthly => _monthly;
  String? get lastIapError => _lastIapError;

  /// ✅ CRITICAL FIX: StreamBuilder abone olur olmaz mevcut değeri de alsın
  Stream<bool> get premiumStream async* {
    yield _isPremium;
    yield* _premiumController.stream;
  }

  Stream<ProductDetails?> get productStream async* {
    yield _monthly;
    yield* _productController.stream;
  }

  Stream<String?> get iapErrorStream async* {
    yield _lastIapError;
    yield* _iapErrorController.stream;
  }

  Future<void> init() {
    _initFuture ??= _init();
    return _initFuture!;
  }

  void _setError(String? msg) {
    _lastIapError = msg;
    _iapErrorController.add(msg);
  }

  void _emitProduct() {
    _productController.add(_monthly);
  }

  void _emitPremium() {
    _premiumController.add(_isPremium);
  }

  Future<void> _init() async {
    // 1) Local premium
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_kIsPremium) ?? false;
    _emitPremium();

    // 2) Store available mı?
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      _monthly = null;
      _emitProduct();
      _setError("Store not available (simulator / no App Store account / region).");
      return;
    }

    // 3) Purchase updates (erken bağlan, pending işleri kaçırma)
    await _purchaseSub?.cancel();
    _purchaseSub = _iap.purchaseStream.listen(
      (purchases) async {
        for (final p in purchases) {
          await _handlePurchase(p);
        }
      },
      onError: (e) => _setError("purchaseStream error: $e"),
    );

    // 4) Products
    await _loadProducts();

    // 5) Auth user varsa bind
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      await bindUser(u.uid);
    }
  }

  /// Paywall açılınca çağır
  Future<void> refreshProducts({
    Duration timeout = const Duration(seconds: 8),
    bool force = false,
  }) async {
    await init();
    if (!_isAvailable) return;

    if (!force && _monthly != null) {
      // yine de UI kaçırdıysa diye emit et
      _emitProduct();
      return;
    }

    try {
      await _loadProducts().timeout(timeout);
    } catch (e) {
      _setError("Product load timeout: $e");
      // emit etmeyi unutma
      _emitProduct();
    }
  }

  Future<void> _loadProducts() async {
  try {
    final response = await _iap.queryProductDetails({kMonthlyId});

    if (response.error != null) {
      _iapErrorController.add("IAP error: ${response.error}");
      _monthly = null;
      _productController.add(null);
      return;
    }

    // Listeyi ProductDetails tipine "normalize" et (StoreKit2 tip bug'larını bypass)
    final products = List<ProductDetails>.from(response.productDetails);

    if (products.isEmpty) {
      _iapErrorController.add(
        "Product not found. Check App Store Connect product id: $kMonthlyId\n"
        "notFoundIDs: ${response.notFoundIDs}",
      );
      _monthly = null;
      _productController.add(null);
      return;
    }

    ProductDetails? found;
    for (final p in products) {
      if (p.id == kMonthlyId) {
        found = p;
        break;
      }
    }

    _monthly = found ?? products.first;

    _iapErrorController.add(null);
    _productController.add(_monthly);
  } catch (e) {
    _iapErrorController.add("queryProductDetails exception: $e");
    _monthly = null;
    _productController.add(null);
  }
}


  Future<void> bindUser(String uid) async {
    _uid = uid;

    await _fireSub?.cancel();
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);

    // İlk sync
    try {
      final snap = await ref.get();
      final remote = (snap.data()?['is_premium'] as bool?) ?? false;

      if (remote && !_isPremium) {
        await _setPremium(true, writeFirestore: false);
      } else if (!remote && _isPremium) {
        await ref.set({'is_premium': true}, SetOptions(merge: true));
      }
    } catch (_) {}

    // Canlı sync
    _fireSub = ref.snapshots().listen((doc) async {
      final remote = (doc.data()?['is_premium'] as bool?) ?? false;
      if (remote && remote != _isPremium) {
        await _setPremium(true, writeFirestore: false);
      }
    });
  }

  /// ✅ Subscription da buyNonConsumable ile gider (plugin mantığı bu)
  Future<void> buyMonthly() async {
    await init();

    if (!_isAvailable) {
      throw Exception("Store not available");
    }

    // Ürün yoksa önce force refresh dene
    if (_monthly == null) {
      await refreshProducts(force: true);
    }

    final product = _monthly;
    if (product == null) {
      throw Exception(_lastIapError ?? "Product not loaded");
    }

    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() async {
    await init();
    if (!_isAvailable) return;
    await _iap.restorePurchases();
  }

  Future<void> _handlePurchase(PurchaseDetails p) async {
    if (p.status == PurchaseStatus.purchased ||
        p.status == PurchaseStatus.restored) {
      await _setPremium(true, writeFirestore: true);

      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
      return;
    }

    if (p.status == PurchaseStatus.error ||
        p.status == PurchaseStatus.canceled) {
      if (p.status == PurchaseStatus.error) {
        _setError("Purchase error: ${p.error}");
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }

    if (p.status == PurchaseStatus.pending) {
      // İstersen burada UI'ya “pending” state gönderebilirsin
    }
  }

  Future<void> _setPremium(bool value, {required bool writeFirestore}) async {
    _isPremium = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsPremium, value);

    _emitPremium();

    if (writeFirestore && value == true) {
      final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'is_premium': true}, SetOptions(merge: true));
      }
    }
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
    await _fireSub?.cancel();
    await _premiumController.close();
    await _productController.close();
    await _iapErrorController.close();
  }
}
