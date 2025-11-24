//
//  MenuBarController.swift
//  TimeSling
//
//  Created by Meghasrivardhan Pulakhandam on 11/23/25.
//

import Cocoa
import SwiftUI
import UserNotifications
import QuartzCore

// Notification names for timer events
extension Notification.Name {
    static let timerCompleted = Notification.Name("timerCompleted")
    static let timerStarted = Notification.Name("timerStarted")
    static let timerCancelled = Notification.Name("timerCancelled")
}

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var updateTimer: Timer?
    private var menuUpdateTimer: Timer?
    private let timerManager = TimerManager.shared
    private var lastDisplayedTitle: String = ""
    
    override init() {
        super.init()
        setupMenuBar()
        setupNotifications()
        startUpdateTimer()
        setupNotificationObservers()
    }
    
    deinit {
        updateTimer?.invalidate()
        menuUpdateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
        
    private func setupMenuBar() {
        print("🔄 Setting up menu bar...")
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            print("✅ Status item button created")
            button.title = "⏱"
//            button.image = NSImage(named: "MenuIcon")
//            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            
            button.needsDisplay = true
        } else {
            print("❌ Failed to create status item button!")
        }
        
        print("🎯 Menu bar setup complete")
    }
    
    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print(granted ? "✓ Notifications enabled" : "✗ Notifications disabled")
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTimerCompleted(_:)),
            name: .timerCompleted,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTimerStarted(_:)),
            name: .timerStarted,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTimerCancelled(_:)),
            name: .timerCancelled,
            object: nil
        )
    }
    
    @objc private func handleTimerCompleted(_ notification: Notification) {
        DispatchQueue.main.async {
            print("🔄 Timer completed - refreshing menu if open")
            self.refreshMenuIfOpen()
            self.updateMenuBarTitle()
        }
    }
    
    @objc private func handleTimerStarted(_ notification: Notification) {
        DispatchQueue.main.async {
            print("🔄 Timer started - refreshing menu if open")
            self.refreshMenuIfOpen()
            self.updateMenuBarTitle()
        }
    }
    
    @objc private func handleTimerCancelled(_ notification: Notification) {
        DispatchQueue.main.async {
            print("🔄 Timer cancelled - refreshing menu if open")
            self.refreshMenuIfOpen()
            self.updateMenuBarTitle()
        }
    }
    
    private func startUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateMenuBarTitle()
                
                if self?.statusItem.menu != nil {
                    self?.refreshMenuIfOpen()
                }
            }
        }
        RunLoop.main.add(updateTimer!, forMode: .common)
    }
    
    private func startMenuUpdateTimer() {
        menuUpdateTimer?.invalidate()
        
        menuUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                if self?.statusItem.menu != nil {
                    self?.refreshMenuIfOpen()
                } else {
                    self?.menuUpdateTimer?.invalidate()
                    self?.menuUpdateTimer = nil
                }
            }
        }
        RunLoop.main.add(menuUpdateTimer!, forMode: .common)
    }
    
    private func updateMenuBarTitle() {
        guard let button = statusItem.button else { return }
        
        let activeTimers = timerManager.getActiveTimers()
        var newTitle: String
        
        if activeTimers.isEmpty {
            newTitle = "⏱"
        } else if activeTimers.count == 1 {
            let timer = activeTimers[0]
            let timeRemaining = max(0, timer.endTime.timeIntervalSinceNow)
            let minutes = Int(timeRemaining) / 60
            let seconds = Int(timeRemaining) % 60
            newTitle = String(format: "%d:%02d", minutes, seconds)
//            newTitle = formatHM(timeRemaining)
        } else {
            newTitle = "\(activeTimers.count)-⏱'s"
        }
        
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
        let menu = createMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        
        startMenuUpdateTimer()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.detectMenuClose()
        }
    }
    
    private func formatHM(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let hrs = mins / 60
        let m = mins % 60
        
        if hrs == 0 { return "\(m)m" }
        return "\(hrs)h \(m)m"
    }
    private func formatMMSS(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }


    
    private func detectMenuClose() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            if self?.statusItem.menu == nil {
                timer.invalidate()
                self?.menuUpdateTimer?.invalidate()
                self?.menuUpdateTimer = nil
            }
        }
    }
    
    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        let activeTimers = timerManager.getActiveTimers()
        if !activeTimers.isEmpty {
            let headerItem = NSMenuItem(title: "Active Timers (\(activeTimers.count))", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)
            menu.addItem(NSMenuItem.separator())
            
            for timer in activeTimers {
                let timeRemaining = max(0, timer.endTime.timeIntervalSinceNow)
//                let minutes = Int(timeRemaining) / 60
//                let seconds = Int(timeRemaining) % 60
//                
//                let title = timer.title.isEmpty ? "Timer" : timer.title
                let item = NSMenuItem(
//                    title: "\(title) - \(minutes):\(String(format: "%02d", seconds))",
                    title: "\(formatHM(timer.duration)) timer - \(formatMMSS(timeRemaining))",
                    action: #selector(cancelTimer(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = timer.id
                item.target = self
                menu.addItem(item)
            }
            menu.addItem(NSMenuItem.separator())
            
            if activeTimers.count > 1 {
                let cancelAllItem = NSMenuItem(title: "Cancel All Timers", action: #selector(cancelAllTimers), keyEquivalent: "")
                cancelAllItem.target = self
                menu.addItem(cancelAllItem)
                menu.addItem(NSMenuItem.separator())
            }
        }
        
        let quickTimersHeader = NSMenuItem(title: "Quick Timers", action: nil, keyEquivalent: "")
        quickTimersHeader.isEnabled = false
        menu.addItem(quickTimersHeader)
        
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
        
        let settingsHeader = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsHeader.isEnabled = false
        menu.addItem(settingsHeader)
        
        let notificationsItem = NSMenuItem(
            title: "Enable Notifications",
            action: #selector(toggleNotifications(_:)),
            keyEquivalent: ""
        )
        notificationsItem.state = timerManager.notificationsEnabled ? .on : .off
        notificationsItem.target = self
        menu.addItem(notificationsItem)
        
        let soundItem = NSMenuItem(
            title: "Enable Sound",
            action: #selector(toggleSound(_:)),
            keyEquivalent: ""
        )
        soundItem.state = timerManager.soundEnabled ? .on : .off
        soundItem.target = self
        menu.addItem(soundItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let dragItem = NSMenuItem(title: "Drag icon down for custom timer", action: nil, keyEquivalent: "")
        dragItem.isEnabled = false
        menu.addItem(dragItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit TimeSling", action: #selector(quit), keyEquivalent: "q"))
        
        return menu
    }
    
    private func refreshMenuIfOpen() {
        guard let menu = statusItem.menu else { return }
        
        let activeTimers = timerManager.getActiveTimers()
        
        var indexesToRemove: [Int] = []
        var timerIndex = 0
        
        for (index, menuItem) in menu.items.enumerated() {
            // FIXED: Remove unused timerId variable
            if menuItem.representedObject as? UUID != nil {
                if timerIndex < activeTimers.count {
                    let timer = activeTimers[timerIndex]
                    let timeRemaining = max(0, timer.endTime.timeIntervalSinceNow)
//                    let minutes = Int(timeRemaining) / 60
//                    let seconds = Int(timeRemaining) % 60
//                    
//                    let title = timer.title.isEmpty ? "Timer" : timer.title
//                    let newTitle = "\(title) - \(minutes):\(String(format: "%02d", seconds))"
                    let newTitle = "\(formatHM(timer.duration)) timer - \(formatMMSS(timeRemaining))"

                    
                    if menuItem.title != newTitle {
                        menuItem.title = newTitle
                    }
                    
                    timerIndex += 1
                } else {
                    indexesToRemove.append(index)
                }
            }
        }
        
        for index in indexesToRemove.reversed() {
            menu.removeItem(at: index)
        }
        
        if !indexesToRemove.isEmpty, let firstItem = menu.items.first {
            let currentCount = timerManager.getActiveTimers().count
            firstItem.title = "Active Timers (\(currentCount))"
            
            if currentCount <= 1 {
                removeCancelAllOption(from: menu)
            }
        }
    }
    
    private func removeCancelAllOption(from menu: NSMenu) {
        for (index, item) in menu.items.enumerated() {
            if item.title == "Cancel All Timers" {
                menu.removeItem(at: index)
                if index < menu.items.count && menu.items[index].isSeparatorItem {
                    menu.removeItem(at: index)
                }
                break
            }
        }
    }
    
    @objc private func cancelTimer(_ sender: NSMenuItem) {
        if let timerId = sender.representedObject as? UUID {
            timerManager.cancelTimer(id: timerId)
        }
    }
    
    @objc private func cancelAllTimers() {
        timerManager.cancelAllTimers()
    }
    
    @objc private func toggleNotifications(_ sender: NSMenuItem) {
        timerManager.toggleNotifications()
        sender.state = timerManager.notificationsEnabled ? .on : .off
    }

    @objc private func toggleSound(_ sender: NSMenuItem) {
        timerManager.toggleSound()
        sender.state = timerManager.soundEnabled ? .on : .off
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


// MARK: - DragWindow Styling - Circular Style
//class DragWindow: NSPanel {
//    private var textLayer = CATextLayer()
//    private var currentDuration: TimeInterval = 0
//    private var progressLayer: CAShapeLayer?
//    private var backgroundRing: CAShapeLayer?
//    
//    init() {
//        super.init(
//            contentRect: NSRect(x: 0, y: 0, width: 90, height: 90),
//            styleMask: [.borderless, .nonactivatingPanel],
//            backing: .buffered,
//            defer: false
//        )
//        
//        self.isOpaque = false
//        self.backgroundColor = .clear
//        self.level = .screenSaver
//        self.hasShadow = true
//        self.ignoresMouseEvents = true
//        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
//        
//        setupUI()
//    }
//    
//    private func setupUI() {
//        let view = NSView(frame: NSRect(x: 0, y: 0, width: 90, height: 90))
//        view.wantsLayer = true
//        view.layer = CALayer()
//        view.layer?.backgroundColor = NSColor.clear.cgColor
//        view.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
//        
//        // ---- Background circle ----
//        let circle = CALayer()
//        circle.frame = NSRect(x: 5, y: 5, width: 80, height: 80)
//        circle.cornerRadius = 40
//        circle.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
//        circle.borderWidth = 1
//        circle.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
//        view.layer?.addSublayer(circle)
//        
//        // ---- Rings ----
//        let center = CGPoint(x: 45, y: 45)
//        let radius: CGFloat = 35
//        let lineWidth: CGFloat = 6
//        
//        let path = NSBezierPath()
//        path.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: true)
//        
//        backgroundRing = CAShapeLayer()
//        backgroundRing?.path = path.cgPath
//        backgroundRing?.strokeColor = NSColor.white.withAlphaComponent(0.15).cgColor
//        backgroundRing?.fillColor = .none
//        backgroundRing?.lineWidth = lineWidth
//        view.layer?.addSublayer(backgroundRing!)
//        
//        progressLayer = CAShapeLayer()
//        progressLayer?.path = path.cgPath
//        progressLayer?.strokeColor = NSColor.systemBlue.cgColor
//        progressLayer?.fillColor = .none
//        progressLayer?.lineWidth = lineWidth
//        progressLayer?.strokeEnd = 0
//        view.layer?.addSublayer(progressLayer!)
//        
//        // ---- CATextLayer label ----
//        textLayer.frame = CGRect(x: 10, y: 28, width: 70, height: 30)
//        textLayer.fontSize = 15
//        textLayer.font = NSFont.boldSystemFont(ofSize: 15)
//        textLayer.alignmentMode = .center
//        textLayer.foregroundColor = NSColor.white.cgColor
//        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
//        textLayer.isWrapped = false
//        textLayer.string = ""
//        view.layer?.addSublayer(textLayer)
//        
//        self.contentView = view
//    }
//    
//    
//    func show(at point: NSPoint) {
//        self.setFrameOrigin(NSPoint(x: point.x - 45, y: point.y - 100))
//        
//        self.alphaValue = 0
//        self.orderFront(nil)
//        
//        NSAnimationContext.runAnimationGroup { ctx in
//            ctx.duration = 0.25
//            self.animator().alphaValue = 1
//        }
//    }
//    
//    func update(at point: NSPoint, dragDistance: CGFloat) {
//        self.setFrameOrigin(NSPoint(x: point.x - 45, y: point.y - 100))
//        
//        // Hide when too small
//        if dragDistance < 5 {
//            textLayer.string = ""
//            progressLayer?.strokeEnd = 0
//            return
//        }
//        
//        // --- Duration calculation ---
//        let adjusted = max(0, dragDistance - 20)
//        
//        // 100px = 30 minutes (same as your original mapping)
//        let minutes = Int(adjusted / 100 * 90)
//        
//        // Clamp to max 4h 59m (299 min)
//        let clampedMinutes = min(minutes, 4 * 60 + 59)
//        currentDuration = TimeInterval(clampedMinutes * 60)
//        
//        // --- Convert to hours/minutes ---
//        let hours = clampedMinutes / 60
//        let mins = clampedMinutes % 60
//        
//        // --- Display logic exactly how you requested ---
//        if clampedMinutes == 0 {
//            textLayer.string = "⏱"
//            
//        } else if hours == 0 {
//            // 1m - 59m
//            textLayer.string = "\(mins)m"
//            
//        } else {
//            // 1h 0m - 4h 59m
//            textLayer.string = "\(hours)h \(mins)m"
//        }
//        
//        // --- Ring Progress ---
//        let maxDuration: CGFloat = 4 * 3600 // 4 hours
//        let progress = min(CGFloat(currentDuration) / maxDuration, 1)
//        progressLayer?.strokeEnd = progress
//        
//        // Color change (optional)
//        if progress < 0.33 {
//            progressLayer?.strokeColor = NSColor.systemGreen.cgColor
//        } else if progress < 0.66 {
//            progressLayer?.strokeColor = NSColor.systemBlue.cgColor
//        } else {
//            progressLayer?.strokeColor = NSColor.systemOrange.cgColor
//        }
//    }
//
//    
//    func hide() {
//        NSAnimationContext.runAnimationGroup { ctx in
//            ctx.duration = 0.2
//            self.animator().alphaValue = 0
//        } completionHandler: {
//            self.orderOut(nil)
//        }
//    }
//    
//    func getDuration() -> TimeInterval { currentDuration }
//}
//


// MARK: - DragWindow - Character Version
class DragWindow: NSPanel {
    private let characterImageView = NSImageView()
    private let textLayer = CATextLayer()
    private var currentDuration: TimeInterval = 0
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .screenSaver
        self.hasShadow = true
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        
        setupUI()
    }
    
    private func setupUI() {
        let frame = NSRect(x: 0, y: 0, width: 120, height: 140)
        let bgView = NSView(frame: frame)
        bgView.wantsLayer = true
        bgView.layer = CALayer()
        bgView.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        // Rounded background
        let backgroundLayer = CALayer()
        backgroundLayer.frame = NSRect(x: 10, y: 10, width: 100, height: 80)
        backgroundLayer.cornerRadius = 20
        backgroundLayer.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        backgroundLayer.borderWidth = 2
        backgroundLayer.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        bgView.layer?.addSublayer(backgroundLayer)
        
        // Character image
        characterImageView.frame = NSRect(x: 20, y: 50, width: 80, height: 80)
        characterImageView.imageScaling = .scaleProportionallyUpOrDown
        characterImageView.alphaValue = 0.0
        bgView.addSubview(characterImageView)
        
        // Timer text layer
        textLayer.frame = CGRect(x: 10, y: 20, width: 100, height: 30)
        textLayer.alignmentMode = .center
        textLayer.font = NSFont.boldSystemFont(ofSize: 18)
        textLayer.fontSize = 18
        textLayer.foregroundColor = NSColor.white.cgColor
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        textLayer.isWrapped = false
        textLayer.string = ""
        bgView.layer?.addSublayer(textLayer)
        
        self.contentView = bgView
    }
    
    func show(at point: NSPoint) {
        let offset = NSPoint(x: point.x - 60, y: point.y - 140)
        self.setFrameOrigin(offset)
        
        characterImageView.alphaValue = 0.0
        textLayer.string = ""
        currentDuration = 0
        
        self.alphaValue = 0
        self.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            self.animator().alphaValue = 1
        }
    }
    
    func update(at point: NSPoint, dragDistance: CGFloat) {
        self.setFrameOrigin(NSPoint(x: point.x - 60, y: point.y - 140))
        
        if dragDistance < 5 {
            textLayer.string = ""
            characterImageView.alphaValue = 0.0
            currentDuration = 0
            return
        }
        
        // Calculate duration
        let adjusted = max(0, dragDistance - 20)
        let minutes = Int(adjusted / 100 * 90)

        // Clamp to max 4h 59m
        let clampedMinutes = min(minutes, 4 * 60 + 59)
        currentDuration = TimeInterval(clampedMinutes * 60)
        
        let hours = clampedMinutes / 60
        let mins = clampedMinutes % 60
        
        // Character logic
        characterImageView.alphaValue = 1
        
        if currentDuration < 60 {
            characterImageView.image = NSImage(named: "DragIconWorried")
            textLayer.string = "⏱"
            
        } else if clampedMinutes < 30 {
            characterImageView.image = NSImage(named: "DragIconHappy")
            textLayer.string = "\(mins)m"
            
        } else if hours >= 0 {
            characterImageView.image = NSImage(named: "DragIconTeeth")
            textLayer.string = "\(hours)h \(mins)m"
            
        } else {
            characterImageView.image = NSImage(named: "DragIconHappy")
            textLayer.string = "\(mins)m"
        }
    }
    
    func getDuration() -> TimeInterval {
        return currentDuration
    }
    
    func hide() {
        characterImageView.alphaValue = 0.0
        textLayer.string = ""
        currentDuration = 0
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            self.animator().alphaValue = 0
        } completionHandler: {
            self.orderOut(nil)
        }
    }
}







// Extension for NSBezierPath to CGPath conversion
extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        
        for i in 0..<self.elementCount {
            let type = self.element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            @unknown default:
                break
            }
        }
        return path
    }
}

// Status Bar Button Drag Extension
extension NSStatusBarButton {
    open override func mouseDown(with event: NSEvent) {
        print("🖱 Mouse down detected")
        
        let initialLocation = event.locationInWindow
        let dragThreshold: CGFloat = 3.0
        
        var isDragging = false
        var dragWindow: DragWindow?
        var eventMonitor: Any?
        
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
                    
                    let screenPoint = window.convertPoint(toScreen: currentLocation)
                    dragWindow = DragWindow()
                    dragWindow?.show(at: screenPoint)
                }
                
                if isDragging, let dragWin = dragWindow {
                    let screenPoint = window.convertPoint(toScreen: currentLocation)
                    dragWin.update(at: screenPoint, dragDistance: deltaY)
                }
                
                return nil
                
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
                    self.sendAction(self.action, to: self.target)
                }
                
                return nil
            }
            
            return trackEvent
        }
        
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

