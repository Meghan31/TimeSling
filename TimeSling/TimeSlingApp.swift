//
//  TimeSlingApp.swift
//  TimeSling
//
//  Created by Meghasrivardhan Pulakhandam on 11/23/25.
//


import SwiftUI
import Cocoa

@main
struct TimeSlingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 TimeSling launching...")
        
        // Hide dock icon FIRST
        NSApp.setActivationPolicy(.accessory)
        
        // Create menu bar controller AFTER setting activation policy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.menuBarController = MenuBarController()
            print("✅ MenuBarController created")
            
            // Force the status item to appear
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("❌ TimeSling shutting down")
    }
}
