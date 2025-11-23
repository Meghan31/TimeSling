//
//  DragGestureView.swift
//  TimeSling
//
//  Created by Meghasrivardhan Pulakhandam on 11/23/25.
//

import SwiftUI

struct DragGestureView: View {
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    var body: some View {
        VStack {
            Text("Drag to set timer")
                .font(.headline)
                .padding()
            
            Text(timeString)
                .font(.system(size: 48, weight: .bold))
                .padding()
            
            Spacer()
        }
        .frame(width: 300, height: 400)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation.height
                }
                .onEnded { _ in
                    isDragging = false
                    if dragOffset < 0 {
                        let duration = calculateDuration(from: abs(dragOffset))
                        TimerManager.shared.startTimer(duration: duration, title: "Timer")
                    }
                    dragOffset = 0
                }
        )
    }
    
    private var timeString: String {
        if !isDragging || dragOffset >= 0 {
            return "00:00"
        }
        
        let duration = calculateDuration(from: abs(dragOffset))
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func calculateDuration(from offset: CGFloat) -> TimeInterval {
        // 100 pixels = 1 minute
        let minutes = Int(offset / 100.0 * 60.0)
        return TimeInterval(min(minutes * 60, 240 * 60)) // Max 4 hours
    }
}

#Preview {
    DragGestureView()
}
