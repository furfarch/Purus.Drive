import SwiftUI
import LocalAuthentication
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// Optional Face ID (or the device passcode) on every open, like Purus Health. Off by default; Settings > Face ID lock.
/// The lock screen is its own window above everything (also above open sheets and alerts),
/// so nothing of a record is visible or tappable before unlock.
@MainActor
final class AppLock: ObservableObject {
    static let shared = AppLock()

    static let enabledKey = "faceIDLock"
    static var appName: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Purus Drive" }
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    @Published private(set) var locked = AppLock.isEnabled
    @Published var message: String?

    /// ask Face ID by itself the next time the app is in front (start, back from background)
    private var autoPrompt = true
    private var busy = false
    #if canImport(UIKit)
    private var coverWindows: [UIWindow] = []
    #endif

    #if canImport(UIKit)
    /// called when the window scene connects: the lock screen is up before the first frame
    func attach(_ scene: UIWindowScene) {
        if locked { showCover() }
    }
    #endif

    /// back to the lock screen (app went to the background)
    func lock() {
        guard Self.isEnabled else { return }
        locked = true
        autoPrompt = true
        message = nil
        showCover()
    }

    /// app is in front: ask once by itself
    func appBecameActive() {
        guard locked, autoPrompt else { return }
        #if canImport(UIKit)
        guard UIApplication.shared.applicationState == .active else { return }
        #endif
        autoPrompt = false
        Task { await unlock() }
    }

    func unlock() async {
        guard locked, !busy else { return }
        let ctx = LAContext()
        var err: NSError?
        // no Face ID and no passcode set on this device: there is nothing to check against
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            open()
            return
        }
        busy = true
        defer { busy = false }
        do {
            if try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock \(AppLock.appName)") {
                open()
            }
        } catch {
            message = "Not unlocked"
        }
    }

    private func open() {
        locked = false
        message = nil
        hideCover()
    }

    private func showCover() {
        #if canImport(UIKit)
        // one cover per window scene: on iPad every open window must be covered
        guard coverWindows.isEmpty else { return }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            let w = UIWindow(windowScene: scene)
            w.windowLevel = .alert + 1
            let host = UIHostingController(rootView: LockedView().environmentObject(self))
            host.view.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
            w.rootViewController = host
            w.isHidden = false
            coverWindows.append(w)
        }
        #endif
    }

    private func hideCover() {
        #if canImport(UIKit)
        coverWindows.forEach { $0.isHidden = true }
        coverWindows = []
        #endif
    }
}

/// Lock screen: dark like the app icon, icon and name in the middle, Unlock button at the bottom.
struct LockedView: View {
    @EnvironmentObject var lock: AppLock

    private static let bg = Color(red: 0.11, green: 0.11, blue: 0.12)

    /// Face ID / Touch ID / passcode symbol, whatever this device uses
    private var unlockSymbol: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock.fill"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image("LockIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityHidden(true)
            Text(AppLock.appName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.top, 18)
            Text("Locked")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 4)
            Spacer()
            if let m = lock.message {
                Text(m)
                    .font(.footnote)
                    .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.55))
                    .padding(.bottom, 12)
            }
            Button {
                Task { await lock.unlock() }
            } label: {
                Label("Unlock", systemImage: unlockSymbol)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(Self.bg)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 420)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Self.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task { lock.appBecameActive() }
    }
}
