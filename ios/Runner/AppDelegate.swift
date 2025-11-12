import Flutter
import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase first
    FirebaseApp.configure()
    
    // Set messaging delegate early
    Messaging.messaging().delegate = self
    
    // Configure UNUserNotificationCenter delegate
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    // Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)
    
    // Request notification permissions and register for remote notifications
    // This should be done after Firebase is configured
    DispatchQueue.main.async {
      self.requestNotificationPermissions(application)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func requestNotificationPermissions(_ application: UIApplication) {
    if #available(iOS 10.0, *) {
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { [weak self] granted, error in
          print("🔔 Notification permission granted: \(granted)")
          if let error = error {
            print("🔔 Notification permission error: \(error)")
          }
          
          // Always register for remote notifications, even if permission is denied
          // This ensures APNS token is available for FCM
          DispatchQueue.main.async {
            application.registerForRemoteNotifications()
          }
        }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
      application.registerForRemoteNotifications()
    }
  }
  
  // Handle APNs token registration - This is crucial for FCM to work
  override func application(_ application: UIApplication,
                           didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("🔔 APNs token received: \(token)")
    
    // Set the APNS token for Firebase Messaging
    Messaging.messaging().apnsToken = deviceToken
    
    // Also set the token type for sandbox/production
    #if DEBUG
    Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
    print("🔔 APNS token set for SANDBOX environment")
    #else
    Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
    print("🔔 APNS token set for PRODUCTION environment")
    #endif
  }
  
  // Handle APNs registration failure
  override func application(_ application: UIApplication,
                           didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("🔔 ❌ Failed to register for remote notifications: \(error)")
    print("🔔 ❌ This will prevent FCM tokens from being generated")
    
    // Even if APNS registration fails, we should still try to get FCM token
    // This might work in some cases where APNS is not available but FCM can still function
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      Messaging.messaging().token { token, error in
        if let error = error {
          print("🔔 ❌ Error fetching FCM registration token: \(error)")
        } else if let token = token {
          print("🔔 ✅ FCM registration token (without APNS): \(token)")
        }
      }
    }
  }
  
  // Handle foreground notifications
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     willPresent notification: UNNotification,
                                     withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo
    
    // Print message ID if available
    if let messageID = userInfo["gcm.message_id"] {
      print("🔔 Message ID: \(messageID)")
    }
    
    print("🔔 Foreground notification received: \(userInfo)")
    
    // Show notification even when app is in foreground
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .badge, .sound]])
    } else {
      completionHandler([[.alert, .badge, .sound]])
    }
  }
  
  // Handle notification tap
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     didReceive response: UNNotificationResponse,
                                     withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    
    // Print message ID if available
    if let messageID = userInfo["gcm.message_id"] {
      print("🔔 Message ID: \(messageID)")
    }
    
    print("🔔 Notification tapped: \(userInfo)")
    
    completionHandler()
  }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("🔔 ✅ Firebase registration token received: \(String(describing: fcmToken))")
    
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
    
    // Also post to Flutter side if needed
    if let token = fcmToken {
      // You can send this to Flutter via method channel if needed
      print("🔔 FCM Token ready for Flutter: \(token.prefix(20))...")
    }
  }
  
  // Handle background messages
  
  override func application(_ application: UIApplication,
                   didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                   fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    
    // Print message ID if available
    if let messageID = userInfo["gcm.message_id"] {
      print("🔔 Message ID: \(messageID)")
    }
    
    print("🔔 Background notification received: \(userInfo)")
    
    completionHandler(UIBackgroundFetchResult.newData)
  }
}
