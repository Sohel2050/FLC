import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_chess_app/utils/constants.dart';

class AdMobConfig {
  final String androidBannerAdId;
  final String iosBannerAdId;
  final String androidInterstitialAdId;
  final String iosInterstitialAdId;
  final String androidRewardedAdId;
  final String iosRewardedAdId;
  final String androidNativeAdId;
  final String iosNativeAdId;
  final bool enabled;
  final DateTime lastUpdated;

  AdMobConfig({
    required this.androidBannerAdId,
    required this.iosBannerAdId,
    required this.androidInterstitialAdId,
    required this.iosInterstitialAdId,
    required this.androidRewardedAdId,
    required this.iosRewardedAdId,
    required this.androidNativeAdId,
    required this.iosNativeAdId,
    this.enabled = true,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  // Platform-specific getters for convenience
  String? get bannerAdUnitId {
    if (!enabled) return null;
    if (Platform.isAndroid) {
      return androidBannerAdId;
    } else if (Platform.isIOS) {
      return iosBannerAdId;
    }
    return null;
  }

  String? get interstitialAdUnitId {
    if (!enabled) return null;
    if (Platform.isAndroid) {
      return androidInterstitialAdId;
    } else if (Platform.isIOS) {
      return iosInterstitialAdId;
    }
    return null;
  }

  String? get rewardedAdUnitId {
    if (!enabled) return null;
    if (Platform.isAndroid) {
      return androidRewardedAdId;
    } else if (Platform.isIOS) {
      return iosRewardedAdId;
    }
    return null;
  }

  String? get nativeAdUnitId {
    if (!enabled) return null;
    if (Platform.isAndroid) {
      return androidNativeAdId;
    } else if (Platform.isIOS) {
      return iosNativeAdId;
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      Constants.androidBannerAdId: androidBannerAdId,
      Constants.iosBannerAdId: iosBannerAdId,
      Constants.androidInterstitialAdId: androidInterstitialAdId,
      Constants.iosInterstitialAdId: iosInterstitialAdId,
      Constants.androidRewardedAdId: androidRewardedAdId,
      Constants.iosRewardedAdId: iosRewardedAdId,
      Constants.androidNativeAdId: androidNativeAdId,
      Constants.iosNativeAdId: iosNativeAdId,
      Constants.enabled: enabled,
      Constants.lastUpdated: Timestamp.fromDate(lastUpdated),
    };
  }

  factory AdMobConfig.fromMap(Map<String, dynamic> map) {
    return AdMobConfig(
      androidBannerAdId: map[Constants.androidBannerAdId] ?? '',
      iosBannerAdId: map[Constants.iosBannerAdId] ?? '',
      androidInterstitialAdId: map[Constants.androidInterstitialAdId] ?? '',
      iosInterstitialAdId: map[Constants.iosInterstitialAdId] ?? '',
      androidRewardedAdId: map[Constants.androidRewardedAdId] ?? '',
      iosRewardedAdId: map[Constants.iosRewardedAdId] ?? '',
      androidNativeAdId: map[Constants.androidNativeAdId] ?? '',
      iosNativeAdId: map[Constants.iosNativeAdId] ?? '',
      enabled: map[Constants.enabled] ?? true,
      lastUpdated: _convertToDateTime(map[Constants.lastUpdated]),
    );
  }

  static DateTime _convertToDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else {
      return DateTime.now();
    }
  }

  AdMobConfig copyWith({
    String? androidBannerAdId,
    String? iosBannerAdId,
    String? androidInterstitialAdId,
    String? iosInterstitialAdId,
    String? androidRewardedAdId,
    String? iosRewardedAdId,
    String? androidNativeAdId,
    String? iosNativeAdId,
    bool? enabled,
    DateTime? lastUpdated,
  }) {
    return AdMobConfig(
      androidBannerAdId: androidBannerAdId ?? this.androidBannerAdId,
      iosBannerAdId: iosBannerAdId ?? this.iosBannerAdId,
      androidInterstitialAdId:
          androidInterstitialAdId ?? this.androidInterstitialAdId,
      iosInterstitialAdId: iosInterstitialAdId ?? this.iosInterstitialAdId,
      androidRewardedAdId: androidRewardedAdId ?? this.androidRewardedAdId,
      iosRewardedAdId: iosRewardedAdId ?? this.iosRewardedAdId,
      androidNativeAdId: androidNativeAdId ?? this.androidNativeAdId,
      iosNativeAdId: iosNativeAdId ?? this.iosNativeAdId,
      enabled: enabled ?? this.enabled,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // Default testing configuration
  factory AdMobConfig.defaultTestConfig() {
    return AdMobConfig(
      androidBannerAdId: 'ca-app-pub-3940256099942544/6300978111',
      iosBannerAdId: 'ca-app-pub-3940256099942544/2934735716',
      androidInterstitialAdId: 'ca-app-pub-3940256099942544/1033173712',
      iosInterstitialAdId: 'ca-app-pub-3940256099942544/4411468910',
      androidRewardedAdId: 'ca-app-pub-3940256099942544/5224354917',
      iosRewardedAdId: 'ca-app-pub-3940256099942544/1712485313',
      androidNativeAdId: 'ca-app-pub-3940256099942544/2247696110',
      iosNativeAdId: 'ca-app-pub-3940256099942544/3986624511',
      enabled: true,
    );
  }
}
