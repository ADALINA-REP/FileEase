import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  static final AdsService instance = AdsService._internal();
  AdsService._internal();

  /// Master switch for AdMob ads across the entire app.
  /// Set to true for production release.
  static const bool adsEnabled = true;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Track operations to throttle interstitials safely
  int _successfulOperationsCount = 0;
  DateTime? _lastInterstitialShownAt;

  // Interstitial Ad instance
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  // Official Google AdMob Production & Test Ad Unit IDs
  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return kDebugMode
          ? 'ca-app-pub-3940256099942544/6300978111' // Android Banner Test
          : 'ca-app-pub-9046523366518719/4252910008'; // Android Banner Production
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return '';
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return kDebugMode
          ? 'ca-app-pub-3940256099942544/1033173712' // Android Interstitial Test
          : 'ca-app-pub-9046523366518719/2888304559'; // Android Interstitial Production
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
    return '';
  }

  static String get rewardedAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return kDebugMode
          ? 'ca-app-pub-3940256099942544/5224354917' // Android Rewarded Test
          : 'ca-app-pub-9046523366518719/6687501651'; // Android Rewarded Production
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    }
    return '';
  }

  // Rewarded Ad instance
  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;

  /// Initialize Mobile Ads SDK safely
  Future<void> initialize() async {
    if (!adsEnabled) return;
    if (_isInitialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      // Desktop & Web fallback - Ads disabled gracefully
      _isInitialized = true;
      return;
    }

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      _preloadInterstitial();
      _preloadRewarded();
    } catch (_) {
      // Never crash app if ads fail to initialize (offline, adblock, network error)
      _isInitialized = false;
    }
  }

  /// Preload rewarded ad in background
  void _preloadRewarded() {
    if (!isSupportedPlatform || _isRewardedLoading || _rewardedAd != null) {
      return;
    }

    _isRewardedLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isRewardedLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Show Rewarded Ad to unlock premium/batch feature
  void showRewardedAd({
    required VoidCallback onUserEarnedReward,
    VoidCallback? onAdDismissed,
  }) {
    if (!adsEnabled) {
      // If ads are hidden/disabled, grant access immediately
      onUserEarnedReward();
      return;
    }

    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          _preloadRewarded();
          onAdDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _rewardedAd = null;
          _preloadRewarded();
          // Never block user if ad fails to show
          onUserEarnedReward();
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          onUserEarnedReward();
        },
      );
    } else {
      // Not preloaded yet; preload and grant reward
      _preloadRewarded();
      onUserEarnedReward();
    }
  }

  /// Preload interstitial ad in the background
  void _preloadInterstitial() {
    if (!isSupportedPlatform ||
        _isInterstitialLoading ||
        _interstitialAd != null) {
      return;
    }

    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  ad.dispose();
                  _interstitialAd = null;
                  _preloadInterstitial(); // Preload next one
                },
                onAdFailedToShowFullScreenContent: (ad, error) {
                  ad.dispose();
                  _interstitialAd = null;
                  _preloadInterstitial();
                },
              );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Triggered after a successfully completed export/compression
  /// Shows ad only if frequency cap is met (every 3 successful operations & min 90s cooldown)
  void notifyOperationCompleted() {
    if (!adsEnabled) return;
    _successfulOperationsCount++;

    final now = DateTime.now();
    final cooldownPassed =
        _lastInterstitialShownAt == null ||
        now.difference(_lastInterstitialShownAt!).inSeconds >= 90;

    if (_successfulOperationsCount % 3 == 0 && cooldownPassed) {
      if (_interstitialAd != null) {
        _lastInterstitialShownAt = now;
        _interstitialAd!.show();
      } else {
        _preloadInterstitial();
      }
    }
  }

  bool get isSupportedPlatform {
    if (!adsEnabled) return false;
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }
}

/// Responsive and graceful Banner Ad Widget
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    if (!AdsService.adsEnabled || !AdsService.instance.isSupportedPlatform) return;

    _bannerAd = BannerAd(
      adUnitId: AdsService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _isLoaded = false;
            });
          }
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdsService.adsEnabled || !_isLoaded || _bannerAd == null) {
      // Invisible zero-height container so UI doesn't break if ad isn't available
      return const SizedBox.shrink();
    }

    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
