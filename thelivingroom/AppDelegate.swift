//
//  AppDelegate.swift
//  thelivingroom
//
//  Created by Omar on 02/10/2020.
//

import UIKit
import Firebase

var ref: DatabaseReference!

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        ref = Database.database().reference()
        return true
    }
}
