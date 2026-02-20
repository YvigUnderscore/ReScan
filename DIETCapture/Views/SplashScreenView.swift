// SplashScreenView.swift
// ReScan
//
// Animated entry screen shown before the main interface.

import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale = 0.8
    @State private var logoOpacity = 0.0
    @State private var textOffset: CGFloat = 20
    @State private var textOpacity = 0.0
    @State private var showGradientLine = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.12), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Animated Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.cyan.opacity(0.15), .blue.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(logoScale)
                    
                    Image(systemName: "viewfinder")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .scaleEffect(logoScale)
                }
                .opacity(logoOpacity)
                
                // Title and Gradient Line
                VStack(spacing: 12) {
                    Text("ReScan")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, .cyan.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                        )
                    
                    // Animated underline
                    Rectangle()
                        .fill(
                            LinearGradient(colors: [.clear, .cyan, .blue, .clear], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(height: 2)
                        .frame(width: showGradientLine ? 160 : 0)
                        .opacity(showGradientLine ? 1 : 0)
                }
                .offset(y: textOffset)
                .opacity(textOpacity)
            }
        }
        .onAppear {
            animateSplash()
        }
    }
    
    private func animateSplash() {
        // 1. Icon pop in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // 2. Text slide up
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            textOffset = 0
            textOpacity = 1.0
        }
        
        // 3. Gradient line stretch
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.4)) {
            showGradientLine = true
        }
    }
}

// MARK: - Preview

#Preview {
    SplashScreenView()
}
