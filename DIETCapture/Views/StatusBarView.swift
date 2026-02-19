// StatusBarView.swift
// DIETCapture
//
// Top overlay bar: tracking state, recording indicator, battery, storage, thermal.

import SwiftUI

struct StatusBarView: View {
    let trackingState: String
    let trackingColor: String
    let isRecording: Bool
    let elapsedTime: String
    let frameCount: String
    let batteryPercent: Int
    let storageMB: Double
    let thermalState: ProcessInfo.ThermalState
    
    var body: some View {
        HStack(spacing: 12) {
            // Tracking State
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.fromString(trackingColor))
                    .frame(width: 8, height: 8)
                Text(trackingState)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            
            Spacer()
            
            // Recording Indicator
            if isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                        .opacity(pulsingOpacity)
                    
                    Text(elapsedTime)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text("\(frameCount) frames")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
            }
            
            Spacer()
            
            // System Status
            HStack(spacing: 10) {
                // Thermal
                if thermalState != .nominal {
                    Image(systemName: "thermometer.high")
                        .font(.caption)
                        .foregroundStyle(thermalColor)
                }
                
                // Storage  
                HStack(spacing: 2) {
                    Image(systemName: "internaldrive")
                        .font(.caption2)
                    Text(storageMB.storageString)
                        .font(.caption2)
                }
                .foregroundStyle(storageMB < 1024 ? .red : .secondary)
                
                // Battery
                HStack(spacing: 2) {
                    Image(systemName: batteryIcon)
                        .font(.caption2)
                    if batteryPercent >= 0 {
                        Text("\(batteryPercent)%")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(batteryPercent < 20 ? .red : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal)
    }
    
    // MARK: - Computed
    
    @State private var pulsingOpacity: Double = 1.0
    
    private var thermalColor: Color {
        switch thermalState {
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        default: return .gray
        }
    }
    
    private var batteryIcon: String {
        if batteryPercent > 75 { return "battery.100" }
        if batteryPercent > 50 { return "battery.75" }
        if batteryPercent > 25 { return "battery.50" }
        return "battery.25"
    }
}
