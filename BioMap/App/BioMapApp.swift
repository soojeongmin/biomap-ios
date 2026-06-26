import SwiftUI
import FirebaseCore
import FirebaseAppCheck
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UserNotifications

final class BioMapAppCheckFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(BioMapAppCheckFactory())
        #endif
        FirebaseApp.configure()

        URLCache.shared = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 120 * 1024 * 1024)

        if UserDefaults.standard.bool(forKey: "clearFirestoreOnLaunch") {
            UserDefaults.standard.set(false, forKey: "clearFirestoreOnLaunch")
            Firestore.firestore().clearPersistence()
        }
        let settings = Firestore.firestore().settings
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 60 * 1024 * 1024))
        Firestore.firestore().settings = settings

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    static func requestPushAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken, let uid = Auth.auth().currentUser?.uid else { return }
        Task { await UserRepository.saveFcmToken(uid: uid, token: token) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let route = info["route"] as? String
        let obs = info["obs"] as? String
        let peer = info["peer"] as? String
        guard let dest = NotifDestination.fromPush(route: route, obs: obs, peer: peer) else { return }
        await MainActor.run { NotifRouter.shared.destination = dest }
    }
}

@main
struct BioMapApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task(id: auth.user?.uid) {
                    guard let uid = auth.user?.uid else { return }
                    AppDelegate.requestPushAuthorization()
                    if let token = try? await Messaging.messaging().token() {
                        await UserRepository.saveFcmToken(uid: uid, token: token)
                    }
                }
        }
    }
}
