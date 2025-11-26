//
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
    var customName: String  // User-editable name
    var description: String  // User-editable description
    var endTime: Date
    var duration: TimeInterval
}

class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    private var _activeTimers: [TimerItem] = []
    private let lock = NSLock()
    private var checkTimer: Timer?
    
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
            customName: "",  // Empty by default
            description: "",  // Empty by default
            endTime: Date().addingTimeInterval(duration),
            duration: duration
        )
        
        lock.lock()
        _activeTimers.append(timer)
        lock.unlock()
        
        if notificationsEnabled {
            scheduleNotification(for: timer)
        }
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .timerStarted,
                object: nil,
                userInfo: ["timer": timer]
            )
        }
    }
    
    func updateTimer(id: UUID, customName: String, description: String) {
        lock.lock()
        if let index = _activeTimers.firstIndex(where: { $0.id == id }) {
            _activeTimers[index].customName = customName
            _activeTimers[index].description = description
            
            // Reschedule notification with updated info
            if notificationsEnabled {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
                scheduleNotification(for: _activeTimers[index])
            }
        }
        lock.unlock()
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .timerStarted,
                object: nil,
                userInfo: ["timerId": id]
            )
        }
    }
    
    func cancelTimer(id: UUID) {
        if notificationsEnabled {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        }
        
        lock.lock()
        _activeTimers.removeAll { $0.id == id }
        lock.unlock()
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .timerCancelled,
                object: nil,
                userInfo: ["timerId": id]
            )
        }
    }
    
    func cancelAllTimers() {
        lock.lock()
        let allTimerIds = _activeTimers.map { $0.id }
        lock.unlock()
        
        for timerId in allTimerIds {
            cancelTimer(id: timerId)
        }
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .timerCancelled,
                object: nil,
                userInfo: ["cancelAll": true]
            )
        }
    }
    
    func getActiveTimers() -> [TimerItem] {
        lock.lock()
        defer { lock.unlock() }
        return _activeTimers.filter { $0.endTime > Date() }
    }
    
    func getTimer(id: UUID) -> TimerItem? {
        lock.lock()
        defer { lock.unlock() }
        return _activeTimers.first { $0.id == id }
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
        }
    }
    
    private func timerCompleted(_ timer: TimerItem) {
        let displayName = timer.customName.isEmpty ? timer.title : timer.customName
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .timerCompleted,
                object: nil,
                userInfo: ["timerTitle": displayName, "timerId": timer.id, "description": timer.description]
            )
        }
        
        DispatchQueue.main.async {
            let notification = CompletionNotificationWindow(
                timerTitle: displayName,
                timerDescription: timer.description
            )
            notification.show()
        }
        
        if notificationsEnabled {
            showEnhancedSystemNotification(for: timer)
        }
        
        if soundEnabled {
            playCompletionSound()
        }
    }
    
    private func scheduleNotification(for timer: TimerItem) {
        let content = UNMutableNotificationContent()
        content.title = "⏰ Timer Complete!"
        
        let displayName = timer.customName.isEmpty ? timer.title : timer.customName
        var bodyText = displayName.isEmpty ? "Your timer has finished!" : "\(displayName) is done!"
        
        if !timer.description.isEmpty {
            bodyText += "\n\(timer.description)"
        }
        
        content.body = bodyText
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
            if error != nil {
                // Notification scheduling failed silently
            }
        }
    }
    
    private func showEnhancedSystemNotification(for timer: TimerItem) {
        let content = UNMutableNotificationContent()
        content.title = "⏰ Timer Complete!"
        
        let displayName = timer.customName.isEmpty ? timer.title : timer.customName
        var bodyText = displayName.isEmpty ? "Your timer has finished!" : "\(displayName) is done!"
        
        if !timer.description.isEmpty {
            bodyText += "\n\(timer.description)"
        }
        
        content.body = bodyText
        content.sound = UNNotificationSound.defaultCritical
        content.interruptionLevel = .critical
        content.relevanceScore = 1.0
        
        let request = UNNotificationRequest(
            identifier: "critical-\(timer.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
                // Fallback to custom notification window on error
                DispatchQueue.main.async {
                    let notification = CompletionNotificationWindow(
                        timerTitle: displayName,
                        timerDescription: timer.description
                    )
                    notification.show()
                }
            }
        }
    }
    
    private func playCompletionSound() {
        DispatchQueue.main.async {
            NSSound(named: "Glass")?.play()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSSound(named: "Glass")?.play()
            }
        }
    }
    
    func toggleNotifications() {
        notificationsEnabled.toggle()
        saveSettings()
    }
    
    func toggleSound() {
        soundEnabled.toggle()
        saveSettings()
    }
}

// MARK: - Custom Completion Notification Window (FIXED for Fullscreen Apps)
class CompletionNotificationWindow: NSPanel {
    private let message: String
    private let descriptionText: String
    
    init(timerTitle: String, timerDescription: String = "") {
        let title = timerTitle.isEmpty ? "Timer" : timerTitle
        self.message = "\(title) is done! ✅"
        self.descriptionText = timerDescription
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: descriptionText.isEmpty ? 100 : 130),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.title = "TimeSling"
        self.level = .screenSaver
        self.hasShadow = true
        self.isMovable = false
        self.isFloatingPanel = true
        self.worksWhenModal = true
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        self.hidesOnDeactivate = false
        self.alphaValue = 0.0
        
        setupUI()
        positionWindow()
    }
    
    private func setupUI() {
        let height = descriptionText.isEmpty ? 100 : 130
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: CGFloat(height)))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        contentView.layer?.cornerRadius = 12
        contentView.layer?.borderWidth = 1
        contentView.layer?.borderColor = NSColor.separatorColor.cgColor
        
        var yOffset = CGFloat(height - 20)
        
        let titleLabel = NSTextField(labelWithString: "⏰ Timer Complete!")
        titleLabel.frame = NSRect(x: 20, y: yOffset - 20, width: 260, height: 20)
        titleLabel.font = .systemFont(ofSize: 14, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.textColor = .labelColor
        contentView.addSubview(titleLabel)
        yOffset -= 25
        
        let messageLabel = NSTextField(labelWithString: message)
        messageLabel.frame = NSRect(x: 20, y: yOffset - 20, width: 260, height: 20)
        messageLabel.font = .systemFont(ofSize: 13, weight: .medium)
        messageLabel.alignment = .center
        messageLabel.textColor = .secondaryLabelColor
        contentView.addSubview(messageLabel)
        yOffset -= 25
        
        if !descriptionText.isEmpty {
            let descLabel = NSTextField(wrappingLabelWithString: descriptionText)
            descLabel.frame = NSRect(x: 20, y: yOffset - 25, width: 260, height: 30)
            descLabel.font = .systemFont(ofSize: 11)
            descLabel.alignment = .center
            descLabel.textColor = .tertiaryLabelColor
            descLabel.maximumNumberOfLines = 2
            contentView.addSubview(descLabel)
            yOffset -= 35
        }
        
        let closeButton = NSButton(title: "OK", target: self, action: #selector(closeWindow))
        closeButton.frame = NSRect(x: 120, y: 10, width: 60, height: 25)
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"
        contentView.addSubview(closeButton)
        
        self.contentView = contentView
    }
    
    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let x = screenRect.maxX - self.frame.width - 20
        let y = screenRect.maxY - self.frame.height - 80
        
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    func show() {
        self.level = .screenSaver
        self.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
        
        self.makeKey()
        
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
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}
