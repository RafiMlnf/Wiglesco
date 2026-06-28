import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionPackage {
  final String id;
  final String title;
  final String description;
  final String priceString;
  final double price;
  final String period;

  const SubscriptionPackage({
    required this.id,
    required this.title,
    required this.description,
    required this.priceString,
    required this.price,
    required this.period,
  });
}

class PremiumState {
  final bool isPremium;
  final bool isLoading;
  final List<SubscriptionPackage> availablePackages;
  final String? activePackageId;
  final String? error;

  const PremiumState({
    this.isPremium = false,
    this.isLoading = false,
    this.availablePackages = const [],
    this.activePackageId,
    this.error,
  });

  PremiumState copyWith({
    bool? isPremium,
    bool? isLoading,
    List<SubscriptionPackage>? availablePackages,
    String? activePackageId,
    String? error,
    bool clearError = false,
  }) {
    return PremiumState(
      isPremium: isPremium ?? this.isPremium,
      isLoading: isLoading ?? this.isLoading,
      availablePackages: availablePackages ?? this.availablePackages,
      activePackageId: activePackageId ?? this.activePackageId,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PremiumNotifier extends StateNotifier<PremiumState> {
  PremiumNotifier() : super(const PremiumState()) {
    _initPackages();
    _loadPremiumStatus();
  }

  void _initPackages() {
    final isIndo = _isIndonesia();
    final packages = [
      SubscriptionPackage(
        id: 'wiglesco_premium_monthly',
        title: isIndo ? 'Akses Bulanan' : 'Monthly Access',
        description: isIndo 
            ? 'Akses render tanpa batas, ditagih bulanan' 
            : 'Unlimited 3D renders, billed monthly',
        priceString: isIndo ? 'Rp 15.000' : '\$0.99',
        price: isIndo ? 15000.0 : 0.99,
        period: isIndo ? 'bulan' : 'month',
      ),
      SubscriptionPackage(
        id: 'wiglesco_premium_yearly',
        title: isIndo ? 'Tiket Tahunan' : 'Yearly Pass',
        description: isIndo 
            ? 'Hemat 45%! Akses premium satu tahun penuh' 
            : 'Best Value! Save 45% on annual access',
        priceString: isIndo ? 'Rp 99.000' : '\$6.99',
        price: isIndo ? 99000.0 : 6.99,
        period: isIndo ? 'tahun' : 'year',
      ),
    ];
    state = state.copyWith(availablePackages: packages);
  }

  bool _isIndonesia() {
    try {
      final locale = Platform.localeName.toLowerCase();
      return locale.contains('id') || locale.contains('in');
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isPremium = prefs.getBool('is_premium') ?? false;
    final activePackageId = prefs.getString('active_package_id');
    state = state.copyWith(
      isPremium: isPremium,
      activePackageId: activePackageId,
    );
  }

  // Simulated purchase for development
  Future<bool> purchasePackage(String packageId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_premium', true);
      await prefs.setString('active_package_id', packageId);
      
      state = state.copyWith(
        isPremium: true,
        activePackageId: packageId,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Purchase failed: ${e.toString()}',
      );
      return false;
    }
  }

  // Developer utility to reset subscription for testing
  Future<void> debugResetSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', false);
    await prefs.remove('active_package_id');
    state = state.copyWith(
      isPremium: false,
      activePackageId: null,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final premiumProvider = StateNotifierProvider<PremiumNotifier, PremiumState>(
  (_) => PremiumNotifier(),
);
