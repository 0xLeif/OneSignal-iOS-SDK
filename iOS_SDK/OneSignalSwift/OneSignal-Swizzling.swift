//
//  OneSignal-Swizzling.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/23/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

extension OneSignal : UIApplicationDelegate{
    
    
    static func didRegisterForRemoteNotifications(app : UIApplication, deviceToken inDeviceToken : NSData) {
        
        let trimmedDeviceToken = inDeviceToken.description.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "<>"))
        let parsedDeviceToken = (trimmedDeviceToken.componentsSeparatedByString(" ") as NSArray).componentsJoinedByString("")
        
        OneSignal.onesignal_Log(.INFO, message: "Device Registered With Apple: \(parsedDeviceToken)")
        
        self.registerDeviceToken(parsedDeviceToken, onSuccess: { (results) in
            OneSignal.onesignal_Log(.INFO, message: "Device Registered With OneSignal: \(self.userId!)")
            }) { (error) in
                OneSignal.onesignal_Log(.INFO, message: "Error in OneSignal registration: \(error)")
        }
    }
    
    
    /* Pre iOS 10.0 Use UIUserNotificationAction & UILocalNotification */
    static func prepareUILocalNotification(data : [String : AnyObject], userInfo : NSDictionary) -> UILocalNotification {
        
        let notification = createUILocalNotification(data)
        
        if let m = data["m"] as? [String : String] {
            if #available(iOS 8.2, *) {notification.alertTitle = m["title"] }
            notification.alertBody = m["body"]
        }
        else if let m = data["m"] as? String {
            notification.alertBody = m
        }
        notification.userInfo = userInfo as [NSObject : AnyObject]
        notification.soundName = data["s"] as? String
        if notification.soundName == nil {
            notification.soundName = UILocalNotificationDefaultSoundName
        }
        
        if let badge = data["b"] as? NSNumber {
            notification.applicationIconBadgeNumber = badge.integerValue
        }
        
        return notification
    }
    
    @available(iOS 8.0, *)
    static func createUILocalNotification(data : [String : AnyObject]) -> UILocalNotification {
        let notification = UILocalNotification()
        let category = UIMutableUserNotificationCategory()
        category.identifier = "dynamic"
        var actionArray : [UIUserNotificationAction] = []
        if let buttons = data["o"] as? [[String : String]] {
            for button in buttons {
                let action = UIMutableUserNotificationAction()
                action.title = button["n"]
                action.identifier = (button["i"] != nil) ? button["i"]! : action.title!
                action.activationMode = .Foreground
                action.destructive = false
                action.authenticationRequired = false
                actionArray.append(action)
            }
        }
        
        //iOS 8 shows notification buttons in reverse in all cases but alerts. This flips it so the frist button is on the left.
        if actionArray.count == 2 {
            category.setActions([actionArray[1], actionArray[0]], forContext: .Minimal)
        }
        else {
            category.setActions(actionArray, forContext: .Default)
        }
        
        let notificationTypes = NotificationType.All
        let set = Set<UIUserNotificationCategory>(arrayLiteral: category)
        let notificationType = UIUserNotificationType(rawValue: UInt(notificationTypes.rawValue))
        let notificationSettings = UIUserNotificationSettings(forTypes: notificationType, categories: set)
        UIApplication.sharedApplication().registerUserNotificationSettings(notificationSettings)
        notification.category = category.identifier
        return notification
    }
    
    static func remoteSilentNotification(application : UIApplication, userInfo : NSDictionary) {
        
        var data : [String : AnyObject]? = nil

        if let buttons = userInfo["os_data"]?["buttons"] as? [String : AnyObject] { data = buttons }
        else if let _ = userInfo["m"] as? [String : AnyObject] { data = userInfo as? [String : AnyObject] }
        
        if data != nil {
            
            if #available(iOS 10.0, *) {
                let oneSignalClass : AnyClass! = NSClassFromString("OneSignal")!
                if (oneSignalClass as? NSObjectProtocol)?.respondsToSelector(NSSelectorFromString("addnotficationRequest")) == true {
                    (oneSignalClass as? NSObjectProtocol)?.performSelector(NSSelectorFromString("addnotficationRequest"), withObject: data!, withObject: userInfo)
                }
            }
            else {
                let notification = prepareUILocalNotification(data!, userInfo : userInfo)
                UIApplication.sharedApplication().scheduleLocalNotification(notification)
            }
        }
            
        else if application.applicationState != .Background {
            self.notificationOpened(userInfo, isActive: application.applicationState == .Active)
        }
        
    }
    
    static func processLocalActionBasedNotification(notification : UILocalNotification, identifier: NSString) {
        
        if notification.userInfo == nil {return}
        
        let userInfo = NSMutableDictionary()
        let customDict = NSMutableDictionary()
        let additionalData = NSMutableDictionary()
        let optionsDict = NSMutableArray()
        
        if let os_data = notification.userInfo!["os_data"],
        buttonsDict = os_data["buttons"] as? NSMutableDictionary {
            userInfo.addEntriesFromDictionary(notification.userInfo!)
            if let o = buttonsDict["o"] as? [[NSObject : AnyObject]] { optionsDict.addObjectsFromArray(o) }
        }
        else if let custom = notification.userInfo!["custom"] as? [NSObject : AnyObject] {
            userInfo.addEntriesFromDictionary(notification.userInfo!)
            customDict.addEntriesFromDictionary(custom)
            if let a = customDict["a"] as? [NSObject : AnyObject] {
                additionalData.addEntriesFromDictionary(a)
            }
            if let o = userInfo["o"] as? [[String : String]] {
                optionsDict.addObjectsFromArray(o)
            }
        }
            
        else {return}

        let buttonArray = NSMutableArray()
        for button in optionsDict {
            
            let buttonToAppend : [NSObject : AnyObject] = [
                                        "text" : button["n"] != nil ? button["n"]!! : "",
                                            "id" : button["i"] != nil ? button["i"]!! : button["n"]!!
                                ]
            
            buttonArray.addObject(buttonToAppend)
        }
        
        additionalData["actionSelected"] = identifier
        additionalData["actionButtons"] = buttonArray
        
        if let os_data = notification.userInfo!["os_data"] as? [String : AnyObject] {
            for (key, val) in os_data { userInfo.setObject(val, forKey: key) }
            if let os_d = userInfo["os_data"],
            buttons = os_d["buttons"] as? NSMutableDictionary,
                m = buttons["m"] {
                let alert = m
                userInfo["aps"] = ["alert" : alert]
            }
        }
        else {
            customDict["a"] = additionalData
            userInfo["custom"] = customDict
            userInfo["aps"] = ["alert":userInfo["m"]!]
        }
        
        OneSignal.notificationOpened(userInfo, isActive: UIApplication.sharedApplication().applicationState == .Active)
    }

    static func getClassWithProtocolInHierarchy(searchClass : AnyClass, protocolToFind : Protocol) -> AnyClass? {
        
        if !class_conformsToProtocol(searchClass, protocolToFind) {
            if searchClass.superclass() == nil { return nil}
            let foundClass : AnyClass? = getClassWithProtocolInHierarchy(searchClass.superclass()!, protocolToFind: protocolToFind)
            if foundClass != nil { return foundClass}
            return searchClass
        }
        return searchClass
    }
    
    static func injectSelector(newClass : AnyClass, newSel : Selector, addToClass : AnyClass, makeLikeSel : Selector) {
        var newMeth = class_getInstanceMethod(newClass, newSel)
        let imp = method_getImplementation(newMeth)
        let methodTypeEncoding = method_getTypeEncoding(newMeth)
        let successful = class_addMethod(addToClass, makeLikeSel, imp, methodTypeEncoding)
        if !successful {
            class_addMethod(addToClass, newSel, imp, methodTypeEncoding)
            newMeth = class_getInstanceMethod(addToClass, newSel)
            let orgMeth = class_getInstanceMethod(addToClass, makeLikeSel)
            method_exchangeImplementations(orgMeth, newMeth)
        }
    }
    
}

