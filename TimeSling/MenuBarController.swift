//
//  MenuBarController.swift
//  TimeSling
//
//  Created by Meghasrivardhan Pulakhandam on 11/23/25.
//


import Cocoa
import SwiftUI
import UserNotifications

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var updateTimer: Timer?
    private let timerManager = TimerManager.shared
    private var lastDisplayedTitle: String = ""
    @objc private func cancelAllTimers() {
        timerManager.cancelAllTimers()
    }
    
    override init() {
        super.init()
        setupMenuBar()
        setupNotifications()
        startUpdateTimer()
    }
    
    deinit {
        updateTimer?.invalidate()
    }
        
    private func setupMenuBar() {
        print("🔄 Setting up menu bar...")
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            print("✅ Status item button created")
            button.title = "⏱"  // Changed to stopwatch emoji
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            
            // Force redraw
            button.needsDisplay = true
//            // TEMPORARY: Test drag window immediately
//            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                self.testDragWindow()
//            }

        } else {
            print("❌ Failed to create status item button!")
        }
        
        print("🎯 Menu bar setup complete")
    }
//    // Temporary debug method
//    private func testDragWindow() {
//        if let screen = NSScreen.main {
//            let center = NSPoint(x: screen.frame.midX, y: screen.frame.midY)
//            let testWindow = DragWindow()
//            testWindow.show(at: center)
//            
//            // Auto-hide after 3 seconds for testing
//            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
//                testWindow.hide()
//            }
//        }
//    }
    
    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print(granted ? "✓ Notifications enabled" : "✗ Notifications disabled")
        }
    }
    
    private func startUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateMenuBarTitle()
            }
        }
        RunLoop.main.add(updateTimer!, forMode: .common)
    }
    
    private func updateMenuBarTitle() {
        guard let button = statusItem.button else { return }
        
        let activeTimers = timerManager.getActiveTimers()
        var newTitle: String
        
        if activeTimers.isEmpty {
            newTitle = "⏱"  // Default icon when no timers
        } else if activeTimers.count == 1 {
            let timer = activeTimers[0]
            let timeRemaining = max(0, timer.endTime.timeIntervalSinceNow)
            let minutes = Int(timeRemaining) / 60
            let seconds = Int(timeRemaining) % 60
            
            // For single timer, show time remaining
            newTitle = String(format: "%d:%02d", minutes, seconds)
        } else {
            // For multiple timers, just show the count to save space
            newTitle = "\(activeTimers.count)-⏱'s"
        }
        
        // Only update if changed to prevent flickering
        if newTitle != lastDisplayedTitle {
            button.title = newTitle
            lastDisplayedTitle = newTitle
            print("📝 Menu bar updated: '\(newTitle)' - \(activeTimers.count) active timers")
        }
    }
    
    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseDown {
            showMenu()
        } else {
            if timerManager.hasActiveTimers() {
                showMenu()
            } else {
                showQuickPresetsMenu()
            }
        }
    }
    
    private func showQuickPresetsMenu() {
        let menu = NSMenu()
        
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
        
        let dragItem = NSMenuItem(title: "Drag down for custom timer", action: nil, keyEquivalent: "")
        dragItem.isEnabled = false
        menu.addItem(dragItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit TimeSling", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    @objc private func quickTimerSelected(_ sender: NSMenuItem) {
        timerManager.startTimer(duration: TimeInterval(sender.tag), title: sender.title)
    }
    
    private func showMenu() {
        let menu = NSMenu()
        
        let activeTimers = timerManager.getActiveTimers()
        if !activeTimers.isEmpty {
            // Add header for active timers
            let headerItem = NSMenuItem(title: "Active Timers (\(activeTimers.count))", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)
            menu.addItem(NSMenuItem.separator())
            
            for timer in activeTimers {
                let timeRemaining = max(0, timer.endTime.timeIntervalSinceNow)
                let minutes = Int(timeRemaining) / 60
                let seconds = Int(timeRemaining) % 60
                
                let title = timer.title.isEmpty ? "Timer" : timer.title
                let item = NSMenuItem(
                    title: "⏱ \(title) - \(minutes):\(String(format: "%02d", seconds))",
                    action: #selector(cancelTimer(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = timer.id
                item.target = self
                menu.addItem(item)
            }
            menu.addItem(NSMenuItem.separator())
        }
        
        // Quick Timers section
        let quickTimersHeader = NSMenuItem(title: "Quick Timers", action: nil, keyEquivalent: "")
        quickTimersHeader.isEnabled = false
        menu.addItem(quickTimersHeader)
        
        let presets: [(String, Int)] = [
            ("5 minutes", 5 * 60),
            ("10 minutes", 10 * 60),
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
        
        // Drag instruction
        let dragItem = NSMenuItem(title: "Drag icon down for custom timer", action: nil, keyEquivalent: "")
        dragItem.isEnabled = false
        menu.addItem(dragItem)
        
        menu.addItem(NSMenuItem.separator())
//        menu.addItem(NSMenuItem(title: "Quit TimeSling", action: #selector(quit), keyEquivalent: "q"))
        // Add cancel all option if there are multiple timers
        
        if activeTimers.count > 1 {
            let cancelAllItem = NSMenuItem(title: "Cancel All Timers", action: #selector(cancelAllTimers), keyEquivalent: "")
            cancelAllItem.target = self
            menu.addItem(cancelAllItem)
            menu.addItem(NSMenuItem.separator())
        }
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    @objc private func cancelTimer(_ sender: NSMenuItem) {
        if let timerId = sender.representedObject as? UUID {
            timerManager.cancelTimer(id: timerId)
        }
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

extension MenuBarController: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

// Drag Window
class DragWindow: NSPanel {
    private let label = NSTextField(labelWithString: "")
    private var currentDuration: TimeInterval = 0
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 70), // Slightly larger for better visibility
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = true
        self.backgroundColor = .clear
        self.level = .screenSaver // Highest possible level - will show above everything
        self.hasShadow = true
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        
        setupUI()
    }
    
    private func setupUI() {
        let bgView = NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 70))
        bgView.wantsLayer = true
        bgView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.95).cgColor
        bgView.layer?.cornerRadius = 12
        bgView.layer?.borderWidth = 2
        bgView.layer?.borderColor = NSColor.white.cgColor
        
        label.frame = NSRect(x: 0, y: 0, width: 160, height: 70)
        label.font = .systemFont(ofSize: 22, weight: .heavy) // Larger font
        label.textColor = .white
        label.alignment = .center
        label.backgroundColor = .clear
        label.isBordered = false
        label.isEditable = false
        label.isSelectable = false
        
        bgView.addSubview(label)
        self.contentView = bgView
    }
    
    func show(at point: NSPoint) {
        // Convert to screen coordinates properly
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            var windowPoint = NSPoint(x: point.x - 80, y: point.y - 100)
            
            // Ensure the window stays on screen
            windowPoint.x = max(screenRect.minX + 10, min(windowPoint.x, screenRect.maxX - 170))
            windowPoint.y = max(screenRect.minY + 10, min(windowPoint.y, screenRect.maxY - 80))
            
            self.setFrameOrigin(windowPoint)
        } else {
            self.setFrameOrigin(NSPoint(x: point.x - 80, y: point.y - 100))
        }
        
        self.alphaValue = 0.0
        self.orderFront(nil)
        
        // Animate in for better visibility
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            self.animator().alphaValue = 1.0
        }
        
        label.stringValue = "DRAG DOWN"
        print("🎯 Drag window shown at \(point)")
    }
    
    func update(at point: NSPoint, dragDistance: CGFloat) {
        // Update position to follow cursor
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            var windowPoint = NSPoint(x: point.x - 80, y: point.y - 100)
            
            // Ensure the window stays on screen
            windowPoint.x = max(screenRect.minX + 10, min(windowPoint.x, screenRect.maxX - 170))
            windowPoint.y = max(screenRect.minY + 10, min(windowPoint.y, screenRect.maxY - 80))
            
            self.setFrameOrigin(windowPoint)
        }
        
        // Calculate duration: 100 pixels = 30 minutes
        let minutes = Int(dragDistance / 100.0 * 30.0)
        currentDuration = TimeInterval(min(minutes * 60, 240 * 60)) // Max 4 hours
        
        let hours = Int(currentDuration) / 3600
        let mins = (Int(currentDuration) % 3600) / 60
        
        if currentDuration < 60 {
            label.stringValue = "DRAG DOWN"
        } else if hours > 0 {
            label.stringValue = "\(hours)h \(mins)m"
        } else {
            label.stringValue = "\(mins)m"
        }
        
        // Keep window on top
        self.orderFront(nil)
    }
    
    func getDuration() -> TimeInterval {
        return currentDuration
    }
    
    func hide() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            self.animator().alphaValue = 0.0
        } completionHandler: {
            self.orderOut(nil)
        }
        print("🎯 Drag window hidden")
    }
}

// Status Bar Button Drag Extension
extension NSStatusBarButton {
    open override func mouseDown(with event: NSEvent) {
        print("🖱 Mouse down detected")
        
        let initialLocation = event.locationInWindow
        let dragThreshold: CGFloat = 3.0 // Lower threshold
        
        var isDragging = false
        var dragWindow: DragWindow?
        var eventMonitor: Any?
        
        // Store initial time to distinguish click from drag
        let initialTime = event.timestamp
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] trackEvent in
            guard let self = self, let window = self.window else { return trackEvent }
            
            if trackEvent.type == .leftMouseDragged {
                let currentLocation = trackEvent.locationInWindow
                let deltaY = initialLocation.y - currentLocation.y
                let distance = hypot(currentLocation.x - initialLocation.x, deltaY)
                
                if !isDragging && (distance > dragThreshold || trackEvent.timestamp - initialTime > 0.1) {
                    isDragging = true
                    print("🎯 Drag started! Distance: \(distance)")
                    
                    // Get the mouse position in screen coordinates
                    let screenPoint = window.convertPoint(toScreen: currentLocation)
                    dragWindow = DragWindow()
                    dragWindow?.show(at: screenPoint)
                }
                
                if isDragging, let dragWin = dragWindow {
                    let screenPoint = window.convertPoint(toScreen: currentLocation)
                    dragWin.update(at: screenPoint, dragDistance: deltaY)
                }
                
                return nil // Consume the event
                
            } else if trackEvent.type == .leftMouseUp {
                if let monitor = eventMonitor {
                    NSEvent.removeMonitor(monitor)
                }
                
                if isDragging {
                    print("🎯 Drag ended")
                    let duration = dragWindow?.getDuration() ?? 0
                    dragWindow?.hide()
                    
                    if duration >= 60 {
                        let minutes = Int(duration) / 60
                        print("⏱ Starting timer: \(minutes) minutes (\(Int(duration))s)")
                        TimerManager.shared.startTimer(duration: duration, title: "\(minutes) min timer")
                    } else {
                        print("⚠️ Duration too short: \(Int(duration))s")
                    }
                } else {
                    print("👆 Simple click detected")
                    // Only trigger the menu on simple clicks (not drags)
                    self.sendAction(self.action, to: self.target)
                }
                
                return nil
            }
            
            return trackEvent
        }
        
        // Also track global events to catch edge cases
        var globalMonitor: Any?
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { globalEvent in
            if globalEvent.type == .leftMouseUp {
                if let monitor = globalMonitor {
                    NSEvent.removeMonitor(monitor)
                }
                if let monitor = eventMonitor {
                    NSEvent.removeMonitor(monitor)
                }
            }
        }
    }
}
