// SplashScreenView.swift
// ReScan
//
// Animated launch screen with modern iOS design aesthetics.

import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0.0
    @State private var glowOpacity: Double = 0.0
    @State private var textOffset: CGFloat = 24
    @State private var textOpacity: Double = 0.0
    @State private var lineWidth: CGFloat = 0
    @State private var taglineOpacity: Double = 0.0
    @State private var particleOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Multi-layer dark background
            Color.black.ignoresSafeArea()

            // Ambient glow
            RadialGradient(
                colors: [.cyan.opacity(0.18 * glowOpacity), .blue.opacity(0.10 * glowOpacity), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 300
            )
            .ignoresSafeArea()
            .animation(.easeIn(duration: 1.2), value: glowOpacity)

            VStack(spacing: 0) {
                Spacer()

                // Logo
                ZStack {
                    // Outer ring
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.cyan.opacity(0.4), .blue.opacity(0.2), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 144, height: 144)
                        .scaleEffect(logoScale)

                    // Inner fill
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.cyan.opacity(0.12), .blue.opacity(0.04)],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 116, height: 116)
                        .scaleEffect(logoScale)

                    // Icon
                    Image(systemName: "viewfinder")
                        .font(.system(size: 58, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(logoScale)
                }
                .opacity(logoOpacity)

                Spacer().frame(height: 40)

                // Title group
                VStack(spacing: 14) {
                    // App name
                    Text("ReScan")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .tracking(1)

                    // Animated separator line
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .cyan, .blue, .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: lineWidth, height: 1.5)
                        .animation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.45), value: lineWidth)

                    // Tagline
                    Text("The first VFX oriented scanning app")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .opacity(taglineOpacity)
                }
                .offset(y: textOffset)
                .opacity(textOpacity)

                Spacer()

                // Version badge
                Text("v1.0")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
                    .opacity(taglineOpacity)
                    .padding(.bottom, 48)
            }
        }
        .onAppear { animate() }
    }

    private func animate() {
        // 1. Logo appears with spring bounce
        withAnimation(.spring(response: 0.65, dampingFraction: 0.6)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // 2. Ambient glow fades in
        withAnimation(.easeIn(duration: 1.2).delay(0.1)) {
            glowOpacity = 1.0
        }

        // 3. Text slides up
        withAnimation(.easeOut(duration: 0.55).delay(0.25)) {
            textOffset = 0
            textOpacity = 1.0
        }

        // 4. Line extends
        withAnimation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.45)) {
            lineWidth = 170
        }

        // 5. Tagline + version fade in
        withAnimation(.easeIn(duration: 0.4).delay(0.7)) {
            taglineOpacity = 1.0
        }
    }
}

// MARK: - Preview

#Preview {
    SplashScreenView()
}
