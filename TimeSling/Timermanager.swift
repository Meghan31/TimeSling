//
//  Timermanager.swift
//  TimeSling
//
//  Created by Meghasrivardhan Pulakhandam on 11/23/25.
//

import Foundation
import UserNotifications

struct TimerItem: Identifiable {
    let id = UUID()
    var title: String
    var endTime: Date
    var duration: TimeInterval
}

class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    @Published private(set) var activeTimers: [TimerItem] = []
    private var updateTimer: Timer?
    
    private init() {
        startUpdateTimer()
    }
    
    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkTimers()
            self?.notifyUpdate()
        }
    }
    
    func startTimer(duration: TimeInterval, title: String) {
        let timer = TimerItem(
            title: title,
            endTime: Date().addingTimeInterval(duration),
            duration: duration
        )
        
        activeTimers.append(timer)
        scheduleNotification(for: timer)
        notifyUpdate()
    }
    
    func cancelTimer(id: UUID) {
        activeTimers.removeAll { $0.id == id }
        notifyUpdate()
    }
    
    func getActiveTimers() -> [TimerItem] {
        return activeTimers.filter { $0.endTime > Date() }
    }
    
    func hasActiveTimers() -> Bool {
        return !getActiveTimers().isEmpty
    }
    
    private func checkTimers() {
        let now = Date()
        var completedTimers: [TimerItem] = []
        
        // Find completed timers
        for timer in activeTimers {
            if timer.endTime <= now {
                completedTimers.append(timer)
            }
        }
        
        // Remove completed timers
        for timer in completedTimers {
            activeTimers.removeAll { $0.id == timer.id }
        }
    }
    
    private func scheduleNotification(for timer: TimerItem) {
        let content = UNMutableNotificationContent()
        content.title = "Timer Complete"
        content.body = timer.title.isEmpty ? "Your timer has finished!" : timer.title
        content.sound = .default
        
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
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func notifyUpdate() {
        NotificationCenter.default.post(name: NSNotification.Name("TimerUpdated"), object: nil)
    }
}
