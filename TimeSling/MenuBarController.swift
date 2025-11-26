//
//
//  MenuBarController.swift
//  TimeSling
//  FIXED: No borders, no focus ring, better spacing
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
    private var numberRollerWindow: NumberRollerWindow?
    private var editWindow: TimerEditWindow?
    private var descriptionWindow: TimerDescriptionWindow?
    
    override init() {
        super.init()
        setupMenuBar()
        setupNotifications()
        startUpdateTimer()
        setupNotificationObservers()
        
        setupMenuRefreshObserver()

    }
    
    deinit {
        updateTimer?.invalidate()
        menuUpdateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
//    func refreshMenu() {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//            self.showMenu()
//        }
//    }
    func refreshMenu() {
        // Simple refresh - just close and let user reopen
        self.statusItem.menu?.cancelTracking()
    }
    
    private func setupMenuRefreshObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMenuRefreshRequest),
            name: Notification.Name("RefreshMenu"),
            object: nil
        )
    }

    @objc private func handleMenuRefreshRequest() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.showMenu()
        }
    }
        
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            var icon: NSImage?
            icon = NSImage(named: "MenuIcon")
            
            if icon == nil {
                if let bundlePath = Bundle.main.path(forResource: "MenuIcon", ofType: "png") {
                    icon = NSImage(contentsOfFile: bundlePath)
                }
            }
            
            if icon == nil {
                icon = NSImage(systemSymbolName: "hourglass", accessibilityDescription: "Timer")
            }
            
            if let loadedIcon = icon {
                loadedIcon.size = NSSize(width: 18, height: 18)
                loadedIcon.isTemplate = true
                button.image = loadedIcon
//                button.imagePosition = .imageOnly
                button.title = ""
            } else {
                button.title = "⏱"
                button.image = nil
            }
            
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            button.needsDisplay = true
        }
    }
    
    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
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
            self.refreshMenuIfOpen()
            self.updateMenuBarTitle()
        }
    }
    
    @objc private func handleTimerStarted(_ notification: Notification) {
        DispatchQueue.main.async {
            self.refreshMenuIfOpen()
            self.updateMenuBarTitle()
        }
    }
    
    @objc private func handleTimerCancelled(_ notification: Notification) {
        DispatchQueue.main.async {
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
            if button.image == nil {
                if let icon = NSImage(named: "MenuIcon") {
                    icon.isTemplate = true
                    button.image = icon
                }
            }
            button.title = ""
            newTitle = "icon"
        } else if activeTimers.count == 1 {
            button.image = nil
            let timer = activeTimers[0]
            let timeRemaining = max(0, timer.endTime.timeIntervalSinceNow)
            let minutes = Int(timeRemaining) / 60
            let seconds = Int(timeRemaining) % 60
            newTitle = String(format: "%d:%02d", minutes, seconds)
            button.title = newTitle
        } else {
            button.image = nil
            newTitle = "\(activeTimers.count) timers"
            button.title = newTitle
        }
        
        if newTitle != lastDisplayedTitle {
            lastDisplayedTitle = newTitle
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
            ("10 minutes", 10 * 60),
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
        
        let customTimerItem = NSMenuItem(title: "Custom Timer...", action: #selector(showNumberRoller), keyEquivalent: "")
        customTimerItem.target = self
        menu.addItem(customTimerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let dragItem = NSMenuItem(title: "Drag down for custom timer", action: nil, keyEquivalent: "")
        dragItem.isEnabled = false
        menu.addItem(dragItem)
        
        menu.addItem(NSMenuItem.separator())
//        menu.addItem(NSMenuItem(title: "Quit TimeSling", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    @objc private func quickTimerSelected(_ sender: NSMenuItem) {
        timerManager.startTimer(duration: TimeInterval(sender.tag), title: sender.title)
    }
    
    @objc private func showNumberRoller() {
        numberRollerWindow?.close()
        
        numberRollerWindow = NumberRollerWindow(
            onSetTimer: { [weak self] duration in
                let hours = Int(duration) / 3600
                let minutes = (Int(duration) % 3600) / 60
                
                var title = ""
                if hours > 0 && minutes > 0 {
                    title = "\(hours)h \(minutes)m timer"
                } else if hours > 0 {
                    title = "\(hours)h timer"
                } else {
                    title = "\(minutes)m timer"
                }
                
                self?.timerManager.startTimer(duration: duration, title: title)
            },
            onClose: { [weak self] in
                self?.numberRollerWindow?.close()
                self?.numberRollerWindow = nil
            }
        )
        
        numberRollerWindow?.showWindow()
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
                
                let timerView = TimerMenuItemView(
                    timer: timer,
                    timeRemaining: timeRemaining,
                    onDescription: { [weak self] in
                        self?.showDescriptionWindow(for: timer.id)
                    },
                    onEdit: { [weak self] in
                        self?.showEditWindow(for: timer.id)
                    },
                    onDelete: { [weak self] in
                        self?.timerManager.cancelTimer(id: timer.id)
                    }
                )
                
                let item = NSMenuItem()
                item.view = timerView
                item.representedObject = timer.id
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
        
        let customTimerItem = NSMenuItem(title: "Custom Timer...", action: #selector(showNumberRoller), keyEquivalent: "")
        customTimerItem.target = self
        menu.addItem(customTimerItem)
        
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
        
        for menuItem in menu.items {
            if let timerId = menuItem.representedObject as? UUID,
               let timerView = menuItem.view as? TimerMenuItemView,
               let timer = activeTimers.first(where: { $0.id == timerId }) {
                let timeRemaining = max(0, timer.endTime.timeIntervalSinceNow)
                timerView.updateTime(timeRemaining)
            }
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
    
    private func showDescriptionWindow(for timerId: UUID) {
        guard let timer = timerManager.getTimer(id: timerId) else { return }
        
        descriptionWindow?.close()
        descriptionWindow = TimerDescriptionWindow(timer: timer)
        descriptionWindow?.showWindow()
    }
    
    private func showEditWindow(for timerId: UUID) {
        guard let timer = timerManager.getTimer(id: timerId) else { return }
        
        editWindow?.close()
        editWindow = TimerEditWindow(
            timer: timer,
            onSave: { [weak self] name, description in
                self?.timerManager.updateTimer(id: timerId, customName: name, description: description)
                self?.editWindow?.close()
                self?.editWindow = nil
            },
            onCancel: { [weak self] in
                self?.editWindow?.close()
                self?.editWindow = nil
            }
        )
        editWindow?.showWindow()
    }
}

extension MenuBarController: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}


// MARK: - Timer Menu Item View - FIXED
class TimerMenuItemView: NSView {
    private let containerView = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let buttonStackView = NSStackView()
    private let descriptionButton = NSButton()
    private let editButton = NSButton()
    private let deleteButton = NSButton()
    
    private var onDescription: (() -> Void)?
    private var onEdit: (() -> Void)?
    private var onDelete: (() -> Void)?
    private let timer: TimerItem
    
    init(timer: TimerItem, timeRemaining: TimeInterval, onDescription: @escaping () -> Void, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.timer = timer
        self.onDescription = onDescription
        self.onEdit = onEdit
        self.onDelete = onDelete
        
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        setupView(timeRemaining: timeRemaining)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView(timeRemaining: TimeInterval) {
        containerView.frame = self.bounds
        addSubview(containerView)
        
        // Timer label - proper spacing
        titleLabel.frame = NSRect(x: 12, y: 4, width: 180, height: 16)
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.stringValue = formatTimerText(timeRemaining)
        titleLabel.textColor = .labelColor
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        containerView.addSubview(titleLabel)
        
        // Button stack - fixed positioning
        buttonStackView.frame = NSRect(x: 200, y: 2, width: 72, height: 20)
        buttonStackView.orientation = .horizontal
        buttonStackView.spacing = 8
        buttonStackView.distribution = .fillEqually
        containerView.addSubview(buttonStackView)
        
        // Configure buttons
        configureButton(descriptionButton, iconName: "InfoIcon", tooltip: "View details")
        configureButton(editButton, iconName: "EditIcon", tooltip: "Edit timer")
        configureButton(deleteButton, iconName: "DeleteIcon", tooltip: "Delete timer")
        
        // Add buttons to stack
        buttonStackView.addArrangedSubview(descriptionButton)
        buttonStackView.addArrangedSubview(editButton)
        buttonStackView.addArrangedSubview(deleteButton)
        
        // Set actions
        descriptionButton.target = self
        descriptionButton.action = #selector(descriptionClicked)
        
        editButton.target = self
        editButton.action = #selector(editClicked)
        
        deleteButton.target = self
        deleteButton.action = #selector(deleteClicked)
    }
    
    private func configureButton(_ button: NSButton, iconName: String, tooltip: String) {
        button.wantsLayer = true
        button.isBordered = false
        button.bezelStyle = .shadowlessSquare
        button.imagePosition = .imageOnly
        button.toolTip = tooltip
        button.focusRingType = .none
        
        // Make icons larger and pure white
        let iconSize: CGFloat = 16
        
        if let customIcon = NSImage(named: iconName) {
            customIcon.size = NSSize(width: iconSize, height: iconSize)
            customIcon.isTemplate = false
            
            button.image = customIcon
            button.contentTintColor = nil
            
        } else if let fallback = NSImage(
            systemSymbolName: iconName == "InfoIcon" ? "info.circle" :
                iconName == "EditIcon" ? "pencil" :
                iconName == "DeleteIcon" ? "xmark.circle" :
                "questionmark.circle",
            accessibilityDescription: tooltip
        ) {
            fallback.size = NSSize(width: iconSize, height: iconSize)
            fallback.isTemplate = true
            button.image = fallback
            button.contentTintColor = .white
        }
        
        // Remove gray box — fully transparent
        button.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Hover effect — subtle glowing translucent white
        let tracking = NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: button,
            userInfo: nil
        )
        button.addTrackingArea(tracking)
    }
    
    private func formatTimerText(_ timeRemaining: TimeInterval) -> String {
        let duration = timer.duration
        let mins = Int(duration) / 60
        let hrs = mins / 60
        let m = mins % 60
        
        let durationText = hrs == 0 ? "\(m)m" : "\(hrs)h \(m)m"
        
        let remainingMins = Int(timeRemaining) / 60
        let remainingSecs = Int(timeRemaining) % 60
        let remainingText = String(format: "%d:%02d", remainingMins, remainingSecs)
        
        return "\(durationText) timer - \(remainingText)"
    }
    
    func updateTime(_ timeRemaining: TimeInterval) {
        titleLabel.stringValue = formatTimerText(timeRemaining)
    }
    
    @objc private func descriptionClicked() {
        onDescription?()
    }
    
    @objc private func editClicked() {
        onEdit?()
    }
    
    
    @objc private func deleteClicked() {
        // Call the delete action
        onDelete?()
        
        // Simple approach: just close the menu and let user reopen it
        // The menu will show updated state next time user clicks
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let menu = self.enclosingMenuItem?.menu {
                menu.cancelTracking()
            }
        }
    }
}

// MARK: - Button Hover Extension
extension NSButton {
    open override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if self.isEnabled {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                self.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.18).cgColor
                self.contentTintColor = .white
            }
        }
    }

    open override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            self.layer?.backgroundColor = NSColor.clear.cgColor
            self.contentTintColor = .white
        }
    }
}



// MARK: - Timer Description Window - TOP-MIDDLE POSITION
class TimerDescriptionWindow: NSPanel {
    init(timer: TimerItem) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 150),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Format the duration for the window title
        let duration = timer.duration
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        let durationText: String
        if hours > 0 {
            durationText = "\(hours)h \(remainingMinutes)m"
        } else {
            durationText = "\(minutes)m"
        }
        
        self.title = "\(durationText) - Timer Description"
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        setupUI(timer: timer)
    }
    
    private func setupUI(timer: TimerItem) {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 150))
        
        let titleLabel = NSTextField(labelWithString: timer.customName.isEmpty ? "Give a Title!" : timer.customName)
        titleLabel.frame = NSRect(x: 20, y: 95, width: 260, height: 20)
        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.alignment = .center
        contentView.addSubview(titleLabel)
        
        let descLabel = NSTextField(wrappingLabelWithString: timer.description.isEmpty ? "No description" : timer.description)
        descLabel.frame = NSRect(x: 20, y: 40, width: 260, height: 50)
        descLabel.font = .systemFont(ofSize: 12)
        descLabel.alignment = .center
        descLabel.textColor = .secondaryLabelColor
        contentView.addSubview(descLabel)
        
        let closeButton = NSButton(title: "OK", target: self, action: #selector(closeWindow))
        closeButton.frame = NSRect(x: 110, y: 10, width: 80, height: 25)
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"
        contentView.addSubview(closeButton)
        
        self.contentView = contentView
    }
    
    func showWindow() {
        // Position at TOP MIDDLE of screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowWidth: CGFloat = 300
            let windowHeight: CGFloat = 150
            let padding: CGFloat = 60 // More padding from top
            
            let x = screenRect.midX - (windowWidth / 2)
            let y = screenRect.maxY - windowHeight - padding
            
            self.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        }
        
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func closeWindow() {
        self.close()
    }
}



// MARK: - Timer Edit Window - FIXED ERRORS
class TimerEditWindow: NSPanel {
    private let nameField = NSTextField()
    private let descriptionTextView: NSTextView // Changed from descriptionField
    private var onSave: ((String, String) -> Void)?
    private var onCancel: (() -> Void)?
    private let timer: TimerItem
    private var textChangeObserver: NSObjectProtocol?
    
    init(timer: TimerItem, onSave: @escaping (String, String) -> Void, onCancel: @escaping () -> Void) {
        self.timer = timer
        self.onSave = onSave
        self.onCancel = onCancel
        self.descriptionTextView = NSTextView() // Initialize here
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 260),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Edit - " + timer.title
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        setupUI(timer: timer)
    }
    
    deinit {
        if let observer = textChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupUI(timer: TimerItem) {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 260))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
//        // Title label
//        let titleLabel = NSTextField(labelWithString: "Edit Timer")
//        titleLabel.frame = NSRect(x: 0, y: 220, width: 400, height: 24)
//        titleLabel.font = .boldSystemFont(ofSize: 16)
//        titleLabel.alignment = .center
//        titleLabel.isEditable = false
//        titleLabel.isBordered = false
//        titleLabel.backgroundColor = .clear
//        contentView.addSubview(titleLabel)
        
        // Timer Name section
        let nameLabel = NSTextField(labelWithString: "Timer Name:")
        nameLabel.frame = NSRect(x: 40, y: 200, width: 120, height: 20)
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.backgroundColor = .clear
        nameLabel.textColor = .labelColor
        contentView.addSubview(nameLabel)
        
        nameField.frame = NSRect(x: 160, y: 200, width: 200, height: 24)
        nameField.font = .systemFont(ofSize: 13)
        nameField.placeholderString = timer.title
        nameField.stringValue = timer.customName
        nameField.isBezeled = true
        nameField.bezelStyle = .roundedBezel
        contentView.addSubview(nameField)
        
        // Description section - FIXED MULTI-LINE
        let descLabel = NSTextField(labelWithString: "Description:")
        descLabel.frame = NSRect(x: 40, y: 160, width: 120, height: 20)
        descLabel.font = .systemFont(ofSize: 13, weight: .medium)
        descLabel.isEditable = false
        descLabel.isBordered = false
        descLabel.backgroundColor = .clear
        descLabel.textColor = .labelColor
        contentView.addSubview(descLabel)
        
        let descriptionScrollView = NSScrollView(frame: NSRect(x: 160, y: 120, width: 200, height: 70))
        descriptionScrollView.hasVerticalScroller = true
        descriptionScrollView.hasHorizontalScroller = false
        descriptionScrollView.autohidesScrollers = true
        descriptionScrollView.borderType = .bezelBorder
        descriptionScrollView.backgroundColor = .controlBackgroundColor
        
        // Configure the existing text view
        descriptionTextView.frame = NSRect(x: 0, y: 0, width: 184, height: 70)
        descriptionTextView.font = .systemFont(ofSize: 13)
        descriptionTextView.minSize = NSSize(width: 0, height: 0)
        descriptionTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        descriptionTextView.isVerticallyResizable = true
        descriptionTextView.isHorizontallyResizable = false
        descriptionTextView.autoresizingMask = [.width]
        
        // Configure text container
        descriptionTextView.textContainer?.containerSize = NSSize(width: 184, height: CGFloat.greatestFiniteMagnitude)
        descriptionTextView.textContainer?.widthTracksTextView = true
        descriptionTextView.textContainer?.heightTracksTextView = false
        
        // Set initial text
        if timer.description.isEmpty {
            descriptionTextView.string = "Add a description for your timer..."
            descriptionTextView.textColor = .placeholderTextColor
        } else {
            descriptionTextView.string = timer.description
            descriptionTextView.textColor = .textColor
        }
        
        // Set up text change notifications for placeholder
        textChangeObserver = NotificationCenter.default.addObserver(
            forName: NSText.didChangeNotification,
            object: descriptionTextView,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            if self.descriptionTextView.textColor == .placeholderTextColor {
                // User started typing, clear placeholder
                if !self.descriptionTextView.string.isEmpty {
                    self.descriptionTextView.textColor = .textColor
                    self.descriptionTextView.string = ""
                }
            } else if self.descriptionTextView.string.isEmpty {
                // User cleared all text, show placeholder
                self.descriptionTextView.textColor = .placeholderTextColor
                self.descriptionTextView.string = "Add a description for your timer..."
            }
        }
        
        descriptionScrollView.documentView = descriptionTextView
        contentView.addSubview(descriptionScrollView)
        
        // Timer information section
        let infoLabel = NSTextField(labelWithString: "Timer Information:")
        infoLabel.frame = NSRect(x: 40, y: 90, width: 120, height: 20)
        infoLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        infoLabel.isEditable = false
        infoLabel.isBordered = false
        infoLabel.backgroundColor = .clear
        infoLabel.textColor = .labelColor
        contentView.addSubview(infoLabel)
        
        // Original duration
        let durationLabel = NSTextField(labelWithString: "Duration:")
        durationLabel.frame = NSRect(x: 60, y: 70, width: 80, height: 20)
        durationLabel.font = .systemFont(ofSize: 13)
        durationLabel.isEditable = false
        durationLabel.isBordered = false
        durationLabel.backgroundColor = .clear
        durationLabel.textColor = .secondaryLabelColor
        contentView.addSubview(durationLabel)
        
        let durationValue = NSTextField(labelWithString: formatDuration(timer.duration))
        durationValue.frame = NSRect(x: 160, y: 70, width: 200, height: 20)
        durationValue.font = .systemFont(ofSize: 13)
        durationValue.isEditable = false
        durationValue.isBordered = false
        durationValue.backgroundColor = .clear
        durationValue.textColor = .secondaryLabelColor
        contentView.addSubview(durationValue)
        
        // End time
        let endTimeLabel = NSTextField(labelWithString: "Ends at:")
        endTimeLabel.frame = NSRect(x: 60, y: 50, width: 80, height: 20)
        endTimeLabel.font = .systemFont(ofSize: 13)
        endTimeLabel.isEditable = false
        endTimeLabel.isBordered = false
        endTimeLabel.backgroundColor = .clear
        endTimeLabel.textColor = .secondaryLabelColor
        contentView.addSubview(endTimeLabel)
        
        let endTimeValue = NSTextField(labelWithString: formatEndTime(timer.endTime))
        endTimeValue.frame = NSRect(x: 160, y: 50, width: 200, height: 20)
        endTimeValue.font = .systemFont(ofSize: 13)
        endTimeValue.isEditable = false
        endTimeValue.isBordered = false
        endTimeValue.backgroundColor = .clear
        endTimeValue.textColor = .secondaryLabelColor
        contentView.addSubview(endTimeValue)
        
        // Buttons with proper gap
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        cancelButton.frame = NSRect(x: 180, y: 10, width: 80, height: 28)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}" // Escape key
        contentView.addSubview(cancelButton)
        
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveClicked))
        saveButton.frame = NSRect(x: 270, y: 10, width: 80, height: 28)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r" // Return key
        contentView.addSubview(saveButton)
        
        self.contentView = contentView
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatEndTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    func showWindow() {
        // Position at TOP MIDDLE of screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowWidth: CGFloat = 400
            let windowHeight: CGFloat = 260
            let padding: CGFloat = 60
            
            let x = screenRect.midX - (windowWidth / 2)
            let y = screenRect.maxY - windowHeight - padding
            
            self.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        }
        
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Make name field first responder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.nameField.becomeFirstResponder()
        }
    }
    
    @objc private func saveClicked() {
        // Get the description text, handling placeholder case
        let descriptionText: String
        if descriptionTextView.textColor != .placeholderTextColor {
            descriptionText = descriptionTextView.string
        } else {
            descriptionText = ""
        }
        
        onSave?(nameField.stringValue, descriptionText)
    }
    
    @objc private func cancelClicked() {
        onCancel?()
    }
}



// MARK: - DragWindow - Character Version
class DragWindow: NSPanel {
    private let characterImageView = NSImageView()
    private let textLayer = CATextLayer()
    private let endTimeLayer = CATextLayer()
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
        
        let backgroundLayer = CALayer()
        backgroundLayer.frame = NSRect(x: 10, y: 10, width: 100, height: 80)
        backgroundLayer.cornerRadius = 20
        backgroundLayer.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        backgroundLayer.borderWidth = 2
        backgroundLayer.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        bgView.layer?.addSublayer(backgroundLayer)
        
        characterImageView.frame = NSRect(x: 20, y: 50, width: 80, height: 80)
        characterImageView.imageScaling = .scaleProportionallyUpOrDown
        characterImageView.alphaValue = 0.0
        bgView.addSubview(characterImageView)
        
        textLayer.frame = CGRect(x: 10, y: 25, width: 100, height: 30)
        textLayer.alignmentMode = .center
        textLayer.font = NSFont.boldSystemFont(ofSize: 18)
        textLayer.fontSize = 18
        textLayer.foregroundColor = NSColor.white.cgColor
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        textLayer.isWrapped = false
        textLayer.string = ""
        bgView.layer?.addSublayer(textLayer)
        
        endTimeLayer.frame = CGRect(x: 10, y: 8, width: 100, height: 20)
        endTimeLayer.alignmentMode = .center
        endTimeLayer.font = NSFont.systemFont(ofSize: 12)
        endTimeLayer.fontSize = 12
        endTimeLayer.foregroundColor = NSColor.systemGray.cgColor
        endTimeLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        endTimeLayer.isWrapped = false
        endTimeLayer.string = ""
        bgView.layer?.addSublayer(endTimeLayer)
        
        self.contentView = bgView
    }
    
    func show(at point: NSPoint) {
        let offset = NSPoint(x: point.x - 60, y: point.y - 140)
        self.setFrameOrigin(offset)
        
        characterImageView.alphaValue = 0.0
        textLayer.string = ""
        endTimeLayer.string = ""
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
            endTimeLayer.string = ""
            characterImageView.alphaValue = 0.0
            currentDuration = 0
            return
        }
        
        let adjusted = max(0, dragDistance - 20)
        let minutes = Int(adjusted / 100 * 90)
        let clampedMinutes = min(minutes, 4 * 60 + 59)
        currentDuration = TimeInterval(clampedMinutes * 60)
        
        let hours = clampedMinutes / 60
        let mins = clampedMinutes % 60
        
        characterImageView.alphaValue = 1
        
        if currentDuration < 60 {
            characterImageView.image = NSImage(named: "DragIconWorried")
            textLayer.string = "⏱"
            endTimeLayer.string = ""
            
        } else if clampedMinutes < 30 {
            characterImageView.image = NSImage(named: "DragIconHappy")
            textLayer.string = "\(mins)m"
            let endTime = Date().addingTimeInterval(currentDuration)
            endTimeLayer.string = formatEndTime(endTime)
            
        } else if hours >= 0 {
            characterImageView.image = NSImage(named: "DragIconTeeth")
            textLayer.string = "\(hours)h \(mins)m"
            let endTime = Date().addingTimeInterval(currentDuration)
            endTimeLayer.string = formatEndTime(endTime)
            
        } else {
            characterImageView.image = NSImage(named: "DragIconHappy")
            textLayer.string = "\(mins)m"
            let endTime = Date().addingTimeInterval(currentDuration)
            endTimeLayer.string = formatEndTime(endTime)
        }
    }
    
    private func formatEndTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func getDuration() -> TimeInterval {
        return currentDuration
    }
    
    func hide() {
        characterImageView.alphaValue = 0.0
        textLayer.string = ""
        endTimeLayer.string = ""
        currentDuration = 0
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            self.animator().alphaValue = 0
        } completionHandler: {
            self.close()
            self.orderOut(nil)
        }
    }
}

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

extension NSStatusBarButton {
    open override func mouseDown(with event: NSEvent) {
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
                    let duration = dragWindow?.getDuration() ?? 0
                    dragWindow?.hide()
                    
                    if duration >= 60 {
                        let minutes = Int(duration) / 60
                        TimerManager.shared.startTimer(duration: duration, title: "\(minutes) min timer")
                    }
                } else {
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
