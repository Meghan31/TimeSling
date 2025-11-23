//  TimerManager.swift
//  TimeSling
//
//  Created by Meghasrivardhan Pulakhandam on 11/23/25.

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
    
    private init() {
        startCheckTimer()
    }
    
    deinit {
        checkTimer?.invalidate()
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
        
        scheduleNotification(for: timer)
        
        print("✅ Timer started: \(Int(duration))s, ends at \(timer.endTime)")
    }
    
    func cancelTimer(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        
        lock.lock()
        _activeTimers.removeAll { $0.id == id }
        lock.unlock()
        
        print("❌ Timer cancelled")
    }
    
    func getActiveTimers() -> [TimerItem] {
        lock.lock()
        defer { lock.unlock() }
        return _activeTimers.filter { $0.endTime > Date() }
    }
    
    func hasActiveTimers() -> Bool {
        return !getActiveTimers().isEmpty
    }
    
    // Add this method to TimerManager class
    func cancelAllTimers() {
        lock.lock()
        let allTimerIds = _activeTimers.map { $0.id }
        lock.unlock()
        
        for timerId in allTimerIds {
            cancelTimer(id: timerId)
        }
        print("🗑 All timers cancelled")
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
            
            playCompletionSound()
            print("🔔 Timer completed at \(now)!")
        }
    }
    
    private func scheduleNotification(for timer: TimerItem) {
        let content = UNMutableNotificationContent()
        content.title = "⏱ Timer Complete!"
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
    
    private func playCompletionSound() {
        DispatchQueue.main.async {
            NSSound.beep()
            NSSound.beep()
            NSSound.beep()
        }
    }
}
