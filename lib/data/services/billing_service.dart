import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../repositories/prefs_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/data/services/billing_service.dart
//
// HOW IT WORKS:
//   1. Call BillingService.init() in main() after PrefsRepository.init()
//   2. Call BillingService.buyPremium() when user taps ₹199 button
//   3. BillingService saves isPremium=true to SharedPreferences automatically
//   4. Call BillingService.dispose() when app closes
//
// PRODUCT ID must match exactly what you create in Play Console:
//   Play Console → your app → Monetize → In-app products → Create
//   Product ID: remove_ads_lifetime
// ─────────────────────────────────────────────────────────────────────────────

class BillingService {
  BillingService._();

  // ── Must match Product ID in Google Play Console exactly ─────────────────
  static const String _productId = 'remove_ads_lifetime';

  // ── State ──────────────────────────────────────────────────────────────────
  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;

  static bool             _available    = false;
  static ProductDetails?  _product;     // the ₹199 product details from Play
  static bool             _loading      = false;

  // ── Notifier — UI listens to this for state changes ─────────────────────
  static final ValueNotifier<BillingState> stateNotifier =
  ValueNotifier(BillingState.idle);

  // ── Init — call once in main() ────────────────────────────────────────────
  static Future<void> init() async {
    if (!_isPlatformSupported) return;

    // Listen to purchase updates
    final stream = _iap.purchaseStream;
    _subscription = stream.listen(
      _onPurchaseUpdate,
      onError: (err) {
        debugPrint('Billing stream error: $err');
        stateNotifier.value = BillingState.error;
      },
    );

    // Check if billing is available on this device
    _available = await _iap.isAvailable();
    if (!_available) {
      debugPrint('Billing not available on this device');
      return;
    }

    // Load product details from Play Store
    await _loadProduct();

    // Restore any previous purchases (handles reinstall case)
    await _restorePurchases();
  }

  // ── Load product info from Play Store ─────────────────────────────────────
  static Future<void> _loadProduct() async {
    try {
      final response = await _iap.queryProductDetails({_productId});
      if (response.error != null) {
        debugPrint('Product query error: ${response.error}');
        return;
      }
      if (response.productDetails.isEmpty) {
        debugPrint('Product not found: $_productId — make sure it is created '
            'and ACTIVE in Play Console');
        return;
      }
      _product = response.productDetails.first;
      debugPrint('Product loaded: ${_product!.title} — ${_product!.price}');
    } catch (e) {
      debugPrint('Failed to load product: $e');
    }
  }

  // ── Restore purchases — call on app start to handle reinstalls ────────────
  static Future<void> _restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('Restore purchases failed: $e');
    }
  }

  // ── Handle all purchase state changes ─────────────────────────────────────
  static Future<void> _onPurchaseUpdate(
      List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      debugPrint('Purchase update: ${purchase.productID} '
          '— status: ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          stateNotifier.value = BillingState.pending;
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
        // ── Verify and unlock premium ──────────────────────────────────
          await _deliverPremium(purchase);
          break;

        case PurchaseStatus.error:
          stateNotifier.value = BillingState.error;
          debugPrint('Purchase error: ${purchase.error}');
          break;

        case PurchaseStatus.canceled:
          stateNotifier.value = BillingState.idle;
          break;
      }

      // Must call completePurchase for all non-pending purchases
      if (purchase.status != PurchaseStatus.pending) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  // ── Deliver premium — save to SharedPreferences ───────────────────────────
  static Future<void> _deliverPremium(PurchaseDetails purchase) async {
    if (purchase.productID == _productId) {
      await PrefsRepository.setPremium(true);
      stateNotifier.value = BillingState.purchased;
      debugPrint('Premium unlocked! ✓');
    }
  }

  // ── PUBLIC: Buy premium ───────────────────────────────────────────────────
  /// Call this when user taps the ₹199 button.
  /// Returns error message string, or null if purchase initiated successfully.
  static Future<String?> buyPremium() async {
    if (!_isPlatformSupported) {
      return 'In-app purchases not supported on this platform.';
    }
    if (PrefsRepository.isPremium()) {
      return 'You already have premium!';
    }
    if (!_available) {
      return 'Play Store billing is not available. Please check your connection.';
    }
    if (_product == null) {
      // Try loading product again
      await _loadProduct();
      if (_product == null) {
        return 'Could not load purchase details. Please try again later.\n\n'
            'Make sure the product "$_productId" is created and ACTIVE in '
            'Google Play Console.';
      }
    }
    if (_loading) return null; // already in progress

    try {
      _loading = true;
      stateNotifier.value = BillingState.loading;

      final purchaseParam = PurchaseParam(productDetails: _product!);
      // Non-consumable one-time purchase
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      return null; // success — purchase sheet will open
    } catch (e) {
      stateNotifier.value = BillingState.error;
      return 'Purchase failed: ${e.toString()}';
    } finally {
      _loading = false;
    }
  }

  // ── PUBLIC: Restore purchases (for reinstall) ─────────────────────────────
  static Future<void> restorePurchases() async {
    if (!_isPlatformSupported || !_available) return;
    stateNotifier.value = BillingState.loading;
    await _restorePurchases();
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  static bool   get isPremium     => PrefsRepository.isPremium();
  static bool   get isAvailable   => _available;
  static String get productPrice  => _product?.price ?? '₹199';
  static bool   get isPlatformOk  => _isPlatformSupported;

  static bool get _isPlatformSupported =>
      !kIsWeb &&
          (Platform.isAndroid || Platform.isIOS);

  // ── Dispose ────────────────────────────────────────────────────────────────
  static void dispose() {
    _subscription?.cancel();
    stateNotifier.dispose();
  }
}

// ── Billing state enum for UI ──────────────────────────────────────────────
enum BillingState {
  idle,       // default — nothing happening
  loading,    // connecting to Play Store
  pending,    // payment processing
  purchased,  // success!
  error,      // something went wrong
}