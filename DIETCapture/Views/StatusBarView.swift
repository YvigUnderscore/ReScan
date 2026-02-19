// StatusBarView.swift
// ReScan
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
        HStack(spacing: 10) {
            // Tracking State
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.fromString(trackingColor))
                    .frame(width: 7, height: 7)
                Text(trackingState)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            
            Spacer()
            
            // Recording Indicator
            if isRecording {
                HStack(spacing: 5) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .shadow(color: .red.opacity(0.6), radius: 4)
                    
                    Text(elapsedTime)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                    
                    Text("\(frameCount)f")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            }
            
            Spacer()
            
            // System Status
            HStack(spacing: 8) {
                if thermalState != .nominal {
                    Image(systemName: "thermometer.high")
                        .font(.caption2)
                        .foregroundStyle(thermalColor)
                }
                
                HStack(spacing: 2) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 8))
                    Text(storageMB.storageString)
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundStyle(storageMB < 1024 ? .red : .secondary)
                
                HStack(spacing: 2) {
                    Image(systemName: batteryIcon)
                        .font(.system(size: 8))
                    if batteryPercent >= 0 {
                        Text("\(batteryPercent)%")
                            .font(.system(size: 9, design: .monospaced))
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
