//
//  VisilabsInAppNotificationInstance.swift
//  VisilabsIOS
//
//  Created by Egemen on 10.05.2020.
//

import Foundation

/*
struct VisilabsInAppNotificationResponse {
    var inAppNotifications: [VisilabsInAppNotification]

    init() {
        inAppNotifications = []
    }
}
 */


class VisilabsInAppNotificationInstance {
    let lock: VisilabsReadWriteLock
    var decideFetched = false
    var notificationsInstance: VisilabsInAppNotifications
    
    var inAppDelegate: VisilabsInAppNotificationsDelegate? {
        set {
            notificationsInstance.delegate = newValue
        }
        get {
            return notificationsInstance.delegate
        }
    }
    
    //TODO: lock kullanılmıyor. VisilabsInAppNotificationInstance da property olarak durmasına gerek var mı?
    required init(lock: VisilabsReadWriteLock) {
        self.lock = lock
        self.notificationsInstance = VisilabsInAppNotifications(lock: self.lock)
    }
    
    
    func checkInAppNotification(properties: [String:String], visilabsUser: VisilabsUser, timeoutInterval: TimeInterval, completion: @escaping ((_ response: VisilabsInAppNotification?) -> Void)){
        let semaphore = DispatchSemaphore(value: 0)
        let headers = prepareHeaders(visilabsUser)
        var notifications = [VisilabsInAppNotification]()
        
        VisilabsRequest.sendInAppNotificationRequest(properties: properties, headers: headers, timeoutInterval: timeoutInterval, completion: { visilabsInAppNotificationResult in
            guard let result = visilabsInAppNotificationResult else  {
                semaphore.signal()
                completion(nil)
                return
            }

            for rawNotif in result{
                if let actionData = rawNotif["actiondata"] as? [String : Any] {
                    if let typeString = actionData["msg_type"] as? String, let _ = VisilabsInAppNotificationType(rawValue: typeString), let notification = VisilabsInAppNotification(JSONObject: rawNotif) {
                        notifications.append(notification)
                    }
                }
            }
            semaphore.signal()
        })
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        VisilabsLogger.info("in app notification check: \(notifications.count) found. actid's: \(notifications.map({String($0.actId)}).joined(separator: ","))")
        
        self.notificationsInstance.inAppNotification = notifications.first
        completion(notifications.first)
    }
    
    private func prepareHeaders(_ visilabsUser: VisilabsUser) -> [String:String] {
        var headers = [String:String]()
        headers["User-Agent"] = visilabsUser.userAgent
        return headers
    }
    
}
