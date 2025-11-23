//
//  MainBarController.swift
//  TimeSling
//
//  Created by Meghasrivardhan Pulakhandam on 11/23/25.
//

import Cocoa
import SwiftUI
import UserNotifications

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var dragWindow: DragWindow?
    private let timerManager = TimerManager.shared
    private var displayLink: CVDisplayLink?
    
    override init() {
        super.init()
        setupMenuBar()
        setupNotifications()
        startDisplayLink()
        
        // Observe timer updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBarTitle),
            name: NSNotification.Name("TimerUpdated"),
            object: nil
        )
    }
    
    deinit {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "⏱"
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    private func startDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        if let displayLink = displayLink {
            CVDisplayLinkStart(displayLink)
        }
    }
    
    @objc private func statusItemClicked(sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseDown {
            showMenu()
        } else {
            handleLeftClick(sender: sender)
        }
    }
    
    private func handleLeftClick(sender: NSStatusBarButton) {
        // Check if there are active timers - if so, show the menu with timer list
        if timerManager.hasActiveTimers() {
            showMenu()
        } else {
            // Show quick presets menu
            showQuickPresetsMenu()
        }
    }
    
    private func showQuickPresetsMenu() {
        let menu = NSMenu()
        
        // Quick preset timers
        let presets: [(String, Int)] = [
            ("5 minutes", 5 * 60),
            ("15 minutes", 15 * 60),
            ("30 minutes", 30 * 60),
            ("1 hour", 60 * 60),
            ("2 hours", 2 * 60 * 60)
        ]
        
        for (title, seconds) in presets {
            let item = NSMenuItem(title: title, action: #selector(quickTimerSelected(_:)), keyEquivalent: "")
            item.tag = seconds
            item.target = self
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Drag to set custom timer
        let dragItem = NSMenuItem(title: "Drag icon to set custom timer...", action: nil, keyEquivalent: "")
        dragItem.isEnabled = false
        menu.addItem(dragItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit TimeSling", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    @objc private func quickTimerSelected(_ sender: NSMenuItem) {
        let seconds = sender.tag
        timerManager.startTimer(duration: TimeInterval(seconds), title: sender.title)
    }
    
    private func showMenu() {
        let menu = NSMenu()
        
        // Show active timers
        let activeTimers = timerManager.getActiveTimers()
        if !activeTimers.isEmpty {
            for timer in activeTimers {
                let timeRemaining = timer.endTime.timeIntervalSinceNow
                let minutes = Int(timeRemaining) / 60
                let seconds = Int(timeRemaining) % 60
                
                let title = timer.title.isEmpty ? "Timer" : timer.title
                let item = NSMenuItem(
                    title: "\(title) - \(minutes):\(String(format: "%02d", seconds))",
                    action: #selector(cancelTimer(_:)),
                    keyEquivalent: ""
                )
                item.tag = timer.id.hashValue
                item.target = self
                menu.addItem(item)
            }
            menu.addItem(NSMenuItem.separator())
        }
        
        // Quick presets
        menu.addItem(NSMenuItem(title: "Quick Timers", action: nil, keyEquivalent: ""))
        
        let presets: [(String, Int)] = [
            ("5 minutes", 5 * 60),
            ("15 minutes", 15 * 60),
            ("30 minutes", 30 * 60),
            ("1 hour", 60 * 60),
            ("2 hours", 2 * 60 * 60)
        ]
        
        for (title, seconds) in presets {
            let item = NSMenuItem(title: "  \(title)", action: #selector(quickTimerSelected(_:)), keyEquivalent: "")
            item.tag = seconds
            item.target = self
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit TimeSling", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    @objc private func cancelTimer(_ sender: NSMenuItem) {
        // Find and cancel the timer
        let activeTimers = timerManager.getActiveTimers()
        if let timer = activeTimers.first(where: { $0.id.hashValue == sender.tag }) {
            timerManager.cancelTimer(id: timer.id)
        }
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func updateMenuBarTitle() {
        guard let button = statusItem.button else { return }
        
        let activeTimers = timerManager.getActiveTimers()
        
        if activeTimers.isEmpty {
            button.title = "⏱"
        } else if activeTimers.count == 1 {
            let timer = activeTimers[0]
            let timeRemaining = timer.endTime.timeIntervalSinceNow
            
            if timeRemaining > 0 {
                let minutes = Int(timeRemaining) / 60
                let seconds = Int(timeRemaining) % 60
                button.title = "⏱ \(minutes):\(String(format: "%02d", seconds))"
            } else {
                button.title = "⏱"
            }
        } else {
            // Multiple timers - show the count
            button.title = "⏱ \(activeTimers.count)"
        }
    }
}

// MARK: - Drag Window
class DragWindow: NSWindow {
    private var initialLocation: NSPoint?
    private var dragStartTime: Date?
    private let feedbackView: DragFeedbackView
    
    init() {
        feedbackView = DragFeedbackView()
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.contentView = feedbackView
        self.ignoresMouseEvents = false
    }
    
    func startDrag(at location: NSPoint) {
        initialLocation = location
        dragStartTime = Date()
        
        let screenFrame = NSScreen.main?.frame ?? .zero
        let windowX = location.x - 100
        let windowY = location.y + 50
        
        self.setFrameOrigin(NSPoint(x: windowX, y: windowY))
        self.orderFront(nil)
        
        feedbackView.updateDuration(0)
    }
    
    func updateDrag(at location: NSPoint) {
        guard let initialLocation = initialLocation else { return }
        
        let distance = location.y - initialLocation.y
        let clampedDistance = max(0, -distance)
        
        // Calculate duration based on distance
        // 100 pixels = 1 minute, max 4 hours
        let minutes = min(Int(clampedDistance / 100.0 * 60.0), 240)
        let duration = TimeInterval(minutes * 60)
        
        feedbackView.updateDuration(duration)
        
        // Update window position
        let windowX = location.x - 100
        let windowY = location.y + 50
        self.setFrameOrigin(NSPoint(x: windowX, y: windowY))
    }
    
    func endDrag() -> TimeInterval? {
        guard let _ = initialLocation else { return nil }
        
        let duration = feedbackView.currentDuration
        
        self.orderOut(nil)
        initialLocation = nil
        dragStartTime = nil
        
        return duration > 0 ? duration : nil
    }
}

// MARK: - Drag Feedback View
class DragFeedbackView: NSView {
    private let label = NSTextField(labelWithString: "")
    var currentDuration: TimeInterval = 0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.95).cgColor
        layer?.cornerRadius = 12
        
        label.font = .systemFont(ofSize: 24, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
        label.autoresizingMask = [.width, .height]
        addSubview(label)
    }
    
    func updateDuration(_ duration: TimeInterval) {
        currentDuration = duration
        
        if duration == 0 {
            label.stringValue = "Drag down to set timer"
            return
        }
        
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            label.stringValue = String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            label.stringValue = String(format: "%dm %ds", minutes, seconds)
        } else {
            label.stringValue = String(format: "%ds", seconds)
        }
    }
}

// MARK: - Status Bar Button Extension for Drag
extension NSStatusBarButton {
    open override func mouseDown(with event: NSEvent) {
        // Check if this is a drag gesture
        let dragThreshold: CGFloat = 10.0
        let initialLocation = event.locationInWindow
        
        var isDragging = false
        var dragWindow: DragWindow?
        
        // Track mouse movement
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { trackEvent in
            if trackEvent.type == .leftMouseDragged {
                let currentLocation = trackEvent.locationInWindow
                let distance = hypot(
                    currentLocation.x - initialLocation.x,
                    currentLocation.y - initialLocation.y
                )
                
                if distance > dragThreshold {
                    if !isDragging {
                        isDragging = true
                        dragWindow = DragWindow()
                        
                        // Convert to screen coordinates
                        if let window = self.window {
                            let screenPoint = window.convertPoint(toScreen: currentLocation)
                            dragWindow?.startDrag(at: screenPoint)
                        }
                    } else {
                        // Update drag
                        if let window = self.window {
                            let screenPoint = window.convertPoint(toScreen: currentLocation)
                            dragWindow?.updateDrag(at: screenPoint)
                        }
                    }
                }
            } else if trackEvent.type == .leftMouseUp {
                if isDragging, let duration = dragWindow?.endDrag(), duration > 0 {
                    // Start timer with the dragged duration
                    TimerManager.shared.startTimer(duration: duration, title: "Timer")
                } else {
                    // It was a click, not a drag
                    self.sendAction(self.action, to: self.target)
                }
                
                // Remove the event monitor
                return nil
            }
            
            return trackEvent
        }
        
        // Don't call super if we're handling the drag
        if !isDragging {
            super.mouseDown(with: event)
        }
    }
}
