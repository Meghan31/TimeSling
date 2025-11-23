//  TimerManager.swift
//  TimeSling
//
//  Created by Meghasrivardhan Pulakhandam on 11/23/25.
//

import Foundation
import UserNotifications
import AppKit

struct TimerItem: Identifiable {
    let id = UUID()
    var title: String
    var endTime: Date
    var duration: TimeInterval
}

class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    private var _activeTimers: [TimerItem] = []
    private let lock = NSLock()
    private var checkTimer: Timer?
    
    // User settings
    var notificationsEnabled: Bool = true
    var soundEnabled: Bool = true
    
    private init() {
        loadSettings()
        startCheckTimer()
    }
    
    deinit {
        checkTimer?.invalidate()
    }
    
    private func loadSettings() {
        // Load saved settings or use defaults
        notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
    }
    
    private func startCheckTimer() {
        checkTimer?.invalidate()
        
        checkTimer = Timer(fire: Date(), interval: 1.0, repeats: true) { [weak self] _ in
            self?.checkTimers()
        }
        RunLoop.main.add(checkTimer!, forMode: .common)
    }
    
    func startTimer(duration: TimeInterval, title: String) {
        let timer = TimerItem(
            title: title,
            endTime: Date().addingTimeInterval(duration),
            duration: duration
        )
        
        lock.lock()
        _activeTimers.append(timer)
        lock.unlock()
        
        if notificationsEnabled {
            scheduleNotification(for: timer)
        }
        
        print("✅ Timer started: \(Int(duration))s, ends at \(timer.endTime)")
    }
    
    func cancelTimer(id: UUID) {
        if notificationsEnabled {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        }
        
        lock.lock()
        _activeTimers.removeAll { $0.id == id }
        lock.unlock()
        
        print("❌ Timer cancelled")
    }
    
    func cancelAllTimers() {
        lock.lock()
        let allTimerIds = _activeTimers.map { $0.id }
        lock.unlock()
        
        for timerId in allTimerIds {
            cancelTimer(id: timerId)
        }
        print("🗑 All timers cancelled")
    }
    
    func getActiveTimers() -> [TimerItem] {
        lock.lock()
        defer { lock.unlock() }
        return _activeTimers.filter { $0.endTime > Date() }
    }
    
    func hasActiveTimers() -> Bool {
        return !getActiveTimers().isEmpty
    }
    
    private func checkTimers() {
        let now = Date()
        
        lock.lock()
        let expired = _activeTimers.filter { $0.endTime <= now }
        lock.unlock()
        
        for timer in expired {
            lock.lock()
            _activeTimers.removeAll { $0.id == timer.id }
            lock.unlock()
            
            timerCompleted(timer)
            print("🔔 Timer completed at \(now)!")
        }
    }
    
    private func timerCompleted(_ timer: TimerItem) {
        // Show notification
        if notificationsEnabled {
            showCompletionNotification(for: timer)
        }
        
        // Play sound
        if soundEnabled {
            playCompletionSound()
        }
    }
    
    private func scheduleNotification(for timer: TimerItem) {
        let content = UNMutableNotificationContent()
        content.title = "⏰ Timer Complete!"
        content.body = timer.title.isEmpty ? "Your timer has finished!" : "\(timer.title) is done!"
        content.sound = UNNotificationSound.defaultCritical
        content.interruptionLevel = .timeSensitive
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timer.duration,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: timer.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification error: \(error)")
            } else {
                print("✅ Notification scheduled for \(Int(timer.duration))s")
            }
        }
    }
    
    private func showCompletionNotification(for timer: TimerItem) {
        // Create a small custom notification window
        DispatchQueue.main.async {
            let notification = CompletionNotificationWindow(timerTitle: timer.title)
            notification.show()
        }
    }
    
    private func playCompletionSound() {
        DispatchQueue.main.async {
            // Use system sound instead of beep for better user experience
            NSSound(named: "Glass")?.play()
            
            // Play multiple times for emphasis (but fewer than before)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSSound(named: "Glass")?.play()
            }
        }
    }
    
    // Settings methods
    func toggleNotifications() {
        notificationsEnabled.toggle()
        saveSettings()
        print("🔔 Notifications \(notificationsEnabled ? "enabled" : "disabled")")
    }
    
    func toggleSound() {
        soundEnabled.toggle()
        saveSettings()
        print("🔊 Sound \(soundEnabled ? "enabled" : "disabled")")
    }
}

// Custom Completion Notification Window

class CompletionNotificationWindow: NSPanel {
    private let message: String
    
    init(timerTitle: String) {
        let title = timerTitle.isEmpty ? "Timer" : timerTitle
        self.message = "\(title) is done! ✅"
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.title = "TimeSling"
        self.level = .screenSaver // Highest possible level - shows over fullscreen apps
        self.hasShadow = true
        self.isMovable = false
        self.isFloatingPanel = true
        self.worksWhenModal = true
        self.collectionBehavior = [
            .canJoinAllSpaces,       // Show across all spaces
            .fullScreenAuxiliary,    // Show over fullscreen apps
            .stationary,             // Don't move with active app
            .ignoresCycle            // Don't participate in window cycling
        ]
        self.hidesOnDeactivate = false
        self.alphaValue = 0.0 // Start transparent for fade-in
        
        setupUI()
        positionWindow()
    }
    
    private func setupUI() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        contentView.layer?.cornerRadius = 12
        contentView.layer?.borderWidth = 1
        contentView.layer?.borderColor = NSColor.separatorColor.cgColor
        
        // Title label
        let titleLabel = NSTextField(labelWithString: "⏰ Timer Complete!")
        titleLabel.frame = NSRect(x: 20, y: 60, width: 260, height: 20)
        titleLabel.font = .systemFont(ofSize: 14, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.textColor = .labelColor
        contentView.addSubview(titleLabel)
        
        // Message label
        let messageLabel = NSTextField(labelWithString: message)
        messageLabel.frame = NSRect(x: 20, y: 35, width: 260, height: 20)
        messageLabel.font = .systemFont(ofSize: 13, weight: .medium)
        messageLabel.alignment = .center
        messageLabel.textColor = .secondaryLabelColor
        contentView.addSubview(messageLabel)
        
        // Close button
        let closeButton = NSButton(title: "OK", target: self, action: #selector(closeWindow))
        closeButton.frame = NSRect(x: 120, y: 10, width: 60, height: 25)
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r" // Enter key to close
        contentView.addSubview(closeButton)
        
        self.contentView = contentView
    }
    
    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let x = screenRect.maxX - self.frame.width - 20
        let y = screenRect.maxY - self.frame.height - 80 // Position a bit lower to avoid menu bar
        
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    func show() {
        print("🔔 Showing notification over fullscreen apps")
        
        // Make sure we're on top of everything
        self.level = .screenSaver
        self.orderFrontRegardless() // Force to front regardless of app state
        
        // Animate in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
        
        // Make window key to receive keyboard events (like Enter key)
        self.makeKey()
        
        // Auto close after 8 seconds (longer for fullscreen apps)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            self.closeWindow()
        }
    }
    
    @objc private func closeWindow() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        } completionHandler: {
            self.close()
            self.orderOut(nil)
        }
    }
    
    // Make sure the window can become key to receive Enter key
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}
