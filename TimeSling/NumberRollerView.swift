//  NumberRollerView.swift
//  TimeSling
//  Created by Meghasrivardhan Pulakhandam on 5/18/23.
//
import SwiftUI

struct NumberRollerView: View {
    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 0
    @State private var isAppearing = false
    @State private var buttonHoverCancel = false
    @State private var buttonHoverStart = false

    var onSetTimer: (TimeInterval) -> Void
    var onClose: () -> Void

    private let hours = Array(0...11)
    private let minutes = Array(0...59)

    var body: some View {
        ZStack {
            // MAIN BACKGROUND — FULLY OPAQUE, NO BLUR
            RoundedRectangle(cornerRadius: 40)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.12),
                            Color(white: 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 40)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            RoundedRectangle(cornerRadius: 40)
                .stroke(Color.black.opacity(0.3), lineWidth: 1)
                .blur(radius: 2)
                .offset(x: 0, y: 1)
                .mask(RoundedRectangle(cornerRadius: 40))

            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Set Timer")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.95))
                .opacity(isAppearing ? 1 : 0)
                .padding(.top, 4)

                HStack(spacing: 12) {
                    VStack(spacing: 6) {
                        Menu {
                            ForEach(hours, id: \.self) { hour in
                                Button(action: { selectedHours = hour }) {
                                    Text("\(hour)")
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("\(selectedHours)")
                                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 30)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)

                        Text("HOURS")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.45))
                            .kerning(0.8)
                    }

                    Text(":")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, 20)

                    VStack(spacing: 6) {
                        Menu {
                            ForEach(minutes, id: \.self) { minute in
                                Button(action: { selectedMinutes = minute }) {
                                    Text(String(format: "%02d", minute))
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(String(format: "%02d", selectedMinutes))
                                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 36)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)

                        Text("MINUTES")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.45))
                            .kerning(0.8)
                    }
                }
                .opacity(isAppearing ? 1 : 0)
                .scaleEffect(isAppearing ? 1 : 0.95)

                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
                    .opacity(isAppearing ? 1 : 0)

                HStack(spacing: 10) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { onClose() }
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(buttonHoverCancel ? 0.08 : 0.05))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hover in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            buttonHoverCancel = hover
                        }
                    }

                    Button {
                        let total = TimeInterval(selectedHours * 3600 + selectedMinutes * 60)
                        if total > 0 { onSetTimer(total); onClose() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                            Text("Start")
                        }
                        .foregroundColor(selectedHours == 0 && selectedMinutes == 0 ? .white.opacity(0.3) : .white.opacity(0.95))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(buttonHoverStart ? 0.18 : 0.12))
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hover in
                        if selectedHours > 0 || selectedMinutes > 0 {
                            withAnimation(.easeInOut(duration: 0.15)) { buttonHoverStart = hover }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .frame(width: 260, height: 220)
        .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 10)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                isAppearing = true
            }
        }
    }
}

class NumberRollerWindow: NSPanel {
    private var hostingView: NSHostingView<NumberRollerView>?

    init(onSetTimer: @escaping (TimeInterval) -> Void,
         onClose: @escaping () -> Void) {

        let frame = NSRect(x: 0, y: 0, width: 260, height: 220)

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Window configuration
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .floating
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Allow moving
        self.isMovable = true
        self.isMovableByWindowBackground = true

        // Create hosting view
        hostingView = NSHostingView(
            rootView: NumberRollerView(onSetTimer: onSetTimer, onClose: onClose)
        )

        hostingView?.wantsLayer = true
        hostingView?.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView?.frame = self.contentView!.bounds
        hostingView?.autoresizingMask = [.width, .height]

        // Apply corner radius to match SwiftUI view
        hostingView?.layer?.cornerRadius = 40
        hostingView?.layer?.masksToBounds = true

        // Set as content view directly
        self.contentView = hostingView
    }

    func showWindow() {
        // Position at top right of screen with some padding
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowWidth: CGFloat = 260
            let windowHeight: CGFloat = 220
            let padding: CGFloat = 20
            
            let x = screenRect.maxX - windowWidth - padding
            let y = screenRect.maxY - windowHeight - padding
            
            let targetFrame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
            
            // Set initial position slightly above the target (for animation)
            let startFrame = targetFrame.offsetBy(dx: 0, dy: 12)
            
            self.setFrame(startFrame, display: false)
            self.alphaValue = 0
            
            self.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.animator().alphaValue = 1
                self.animator().setFrame(targetFrame, display: true)
            }
        } else {
            // Fallback if no screen is found
            self.center()
            self.alphaValue = 0
            self.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                self.animator().alphaValue = 1
            }
        }
    }
}
