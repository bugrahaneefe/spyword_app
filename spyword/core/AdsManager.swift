// AdsManager.swift
// SwiftUI + Google AdMob (Banner, Interstitial, Rewarded)
// Shared singleton with async/await show methods.
//
// Requirements:
// - Dependency: Google-Mobile-Ads-SDK (SPM or CocoaPods)
// - Info.plist: GADApplicationIdentifier = "ca-app-pub-3940256099942544~1458002511"

import SwiftUI
import GoogleMobileAds
import UIKit

// MARK: - Ad Unit IDs (Google Test)
enum AdUnitID {
    static let banner = "ca-app-pub-3940256099942544/2934735716"
    static let interstitial = "ca-app-pub-3940256099942544/4411468910"
    static let rewarded = "ca-app-pub-3940256099942544/1712485313"
}

// MARK: - AdsManager
@MainActor
final class AdsManager: NSObject, ObservableObject {
    static let shared = AdsManager()

    private var interstitial: InterstitialAd?
    private var rewarded: RewardedAd?

    // Async continuations to await dismissal
    private var interstitialCont: CheckedContinuation<Void, Error>?
    private var rewardedCont: CheckedContinuation<(type: String, amount: NSDecimalNumber), Error>?
    private var pendingReward: (type: String, amount: NSDecimalNumber)?

    private override init() { super.init() }

    func start() {
        MobileAds.shared.start(completionHandler: nil)
        preloadAll()
    }

    func preloadAll() {
        loadInterstitial()
        loadRewarded()
    }

    // MARK: Loaders
    func loadInterstitial() {
        InterstitialAd.load(with: AdUnitID.interstitial, request: Request()) { [weak self] ad, error in
            if let error = error {
                print("[AdsManager] Interstitial load error: \(error.localizedDescription)")
                self?.interstitial = nil
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
        }
    }

    func loadRewarded() {
        RewardedAd.load(with: AdUnitID.rewarded, request: Request()) { [weak self] ad, error in
            if let error = error {
                print("[AdsManager] Rewarded load error: \(error.localizedDescription)")
                self?.rewarded = nil
                return
            }
            self?.rewarded = ad
            self?.rewarded?.fullScreenContentDelegate = self
        }
    }

    // MARK: Awaitable show methods
    enum AdsError: Error { case missingRoot, presentInProgress, failed(String) }

    func showInterstitial(from root: UIViewController?, chance percent: Int = 75) async throws {
        guard let root else { throw AdsError.missingRoot }
        if interstitialCont != nil { throw AdsError.presentInProgress }

        // Olasılık tutmazsa direkt dön
        guard shouldShow(percent) else { return }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            interstitialCont = cont
            let present: (InterstitialAd) -> Void = { ad in
                ad.present(from: root)
            }
            if let ad = interstitial {
                present(ad)
            } else {
                InterstitialAd.load(with: AdUnitID.interstitial, request: Request()) { [weak self] ad, error in
                    guard let self else { return }
                    if let error = error { self.interstitialCont = nil; cont.resume(throwing: AdsError.failed(error.localizedDescription)); return }
                    self.interstitial = ad
                    self.interstitial?.fullScreenContentDelegate = self
                    if let ad { present(ad) } else { self.interstitialCont = nil; cont.resume(throwing: AdsError.failed("No ad")) }
                }
            }
        }
    }

    func showRewarded(from root: UIViewController?, chance percent: Int = 75) async throws -> (type: String, amount: NSDecimalNumber) {
        guard let root else { throw AdsError.missingRoot }
        if rewardedCont != nil { throw AdsError.presentInProgress }

        // Olasılık tutmazsa boş ödülle dön
        guard shouldShow(percent) else { return ("", 0) }

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(type: String, amount: NSDecimalNumber), Error>) in
            rewardedCont = cont
            pendingReward = nil

            let present: (RewardedAd) -> Void = { ad in
                ad.present(from: root) { [weak self] in
                    guard let self else { return }
                    let r = ad.adReward
                    self.pendingReward = (r.type, r.amount)
                }
            }
            if let ad = rewarded {
                present(ad)
            } else {
                RewardedAd.load(with: AdUnitID.rewarded, request: Request()) { [weak self] ad, error in
                    guard let self else { return }
                    if let error = error { self.rewardedCont = nil; cont.resume(throwing: AdsError.failed(error.localizedDescription)); return }
                    self.rewarded = ad
                    self.rewarded?.fullScreenContentDelegate = self
                    if let ad { present(ad) } else { self.rewardedCont = nil; cont.resume(throwing: AdsError.failed("No ad")) }
                }
            }
        }
    }
    
    private func shouldShow(_ percent: Int) -> Bool {
        let p = max(0, min(100, percent))
        return Int.random(in: 0..<100) < p
    }
}

// MARK: - GADFullScreenContentDelegate
extension AdsManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if ad === interstitial {
            interstitial = nil; loadInterstitial()
            if let cont = interstitialCont { interstitialCont = nil; cont.resume(returning: ()) }
        }
        if ad === rewarded {
            let reward = pendingReward ?? ("", 0)
            rewarded = nil; loadRewarded()
            if let cont = rewardedCont { rewardedCont = nil; cont.resume(returning: (type: reward.0, amount: reward.1)) }
            pendingReward = nil
        }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        if ad === interstitial {
            let err = AdsError.failed(error.localizedDescription)
            if let cont = interstitialCont { interstitialCont = nil; cont.resume(throwing: err) }
            interstitial = nil; loadInterstitial()
        }
        if ad === rewarded {
            let err = AdsError.failed(error.localizedDescription)
            if let cont = rewardedCont { rewardedCont = nil; cont.resume(throwing: err) }
            rewarded = nil; pendingReward = nil; loadRewarded()
        }
    }
}

/// SwiftUI-friendly adaptive banner that DOES NOT break layout.
/// - Auto-sizes height using adaptive size for the current width
/// - Uses a container + Auto Layout so it won’t stretch your stacks
struct BannerAdView: View {
    var adUnitID: String = AdUnitID.banner

    var body: some View {
        GeometryReader { geo in
            BannerUIView(adUnitID: adUnitID, width: geo.size.width)
                .frame(
                    width: geo.size.width,
                    height: BannerAdView.bannerHeight(for: geo.size.width),
                    alignment: .center
                )
                .clipped()
        }
        // Provide a stable initial height to avoid layout jumps before GeometryReader runs
        .frame(height: BannerAdView.bannerHeight(for: UIScreen.main.bounds.width))
    }

    // Compute the adaptive banner height for a given width
    private static func bannerHeight(for width: CGFloat) -> CGFloat {
        portraitAnchoredAdaptiveBanner(width: max(1, width)).size.height
    }
}

private struct BannerUIView: UIViewRepresentable {
    let adUnitID: String
    var width: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.clipsToBounds = true

        // Create banner with adaptive size
        let size = portraitAnchoredAdaptiveBanner(width: max(1, width))
        let banner = BannerView(adSize: size)
        banner.adUnitID = adUnitID
        banner.rootViewController = context.coordinator.rootVC
        banner.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(banner)
        // Center and pin with Auto Layout so it won’t stretch parent stacks
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            banner.topAnchor.constraint(equalTo: container.topAnchor),
            banner.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // Load request
        banner.load(Request())
        context.coordinator.banner = banner
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let banner = context.coordinator.banner else { return }
        let newSize = portraitAnchoredAdaptiveBanner(width: max(1, width))
        if !isAdSizeEqualToSize(size1: banner.adSize, size2: newSize) {
            banner.adSize = newSize
        }
        // No need to change constraints; height adjusts with adSize
    }

    final class Coordinator: NSObject {
        let rootVC = UIViewController()
        weak var banner: BannerView?
    }
}


// MARK: - Top VC helper
extension UIApplication {
    func topMostViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController { return topMostViewController(base: nav.visibleViewController) }
        if let tab = base as? UITabBarController { return topMostViewController(base: tab.selectedViewController) }
        if let presented = base?.presentedViewController { return topMostViewController(base: presented) }
        return base
    }
}
