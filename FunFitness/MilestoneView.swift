//
//  MilestoneView.swift
//  FunFitness
//
//  Created by Jay Jones on 3/29/26.
//

import SwiftUI

struct MilestoneView: View {
    let milestone: Milestone
    let theme: Theme
    let onDismiss: () -> Void
    
    @State private var showContent = false
    @State private var confettiTrigger = 0
    
    var body: some View {
        ZStack {
            // Dark dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            // Confetti Effect
            ConfettiView(trigger: confettiTrigger)
            
            VStack(spacing: 24) {
                Spacer()
                
                // Large emoji
                Text(milestone.getEmoji(for: theme))
                    .font(.system(size: 100))
                    .scaleEffect(showContent ? 1.0 : 0.5)
                    .opacity(showContent ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showContent)
                
                VStack(spacing: 12) {
                    // Milestone headline
                    Text(milestone.getTitle(for: theme))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)
                    
                    // Comparison text
                    Text(milestone.getComparison(for: theme))
                        .font(.title3)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.3), value: showContent)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    // Keep Going button
                    Button {
                        onDismiss()
                    } label: {
                        Text("Keep Going")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "#5B21B6"))
                            .cornerRadius(14)
                    }
                    .opacity(showContent ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: showContent)
                    
                    // Share button (placeholder for V2)
                    Button {
                        // V2: Share functionality
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(14)
                    }
                    .opacity(showContent ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6).delay(0.5), value: showContent)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            showContent = true
            confettiTrigger += 1
        }
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    let trigger: Int
    
    @State private var particles: [ConfettiParticle] = []
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                
                for particle in particles {
                    let progress = now - particle.creationTime
                    
                    if progress < particle.lifetime {
                        let yOffset = progress * particle.speed
                        let rotation = progress * particle.rotationSpeed
                        let opacity = 1.0 - (progress / particle.lifetime)
                        
                        var particleContext = context
                        particleContext.opacity = opacity
                        
                        let position = CGPoint(
                            x: particle.x + sin(progress * particle.wobble) * 20,
                            y: particle.y + yOffset
                        )
                        
                        particleContext.translateBy(x: position.x, y: position.y)
                        particleContext.rotate(by: .degrees(rotation))
                        
                        particleContext.fill(
                            Circle().path(in: CGRect(x: -3, y: -3, width: 6, height: 6)),
                            with: .color(particle.color)
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onChange(of: trigger) {
            generateParticles()
        }
    }
    
    private func generateParticles() {
        particles = (0..<60).map { _ in
            ConfettiParticle(
                x: Double.random(in: 0...UIScreen.main.bounds.width),
                y: -20,
                speed: Double.random(in: 100...250),
                lifetime: Double.random(in: 2...4),
                rotationSpeed: Double.random(in: -360...360),
                wobble: Double.random(in: 2...6),
                color: [.red, .blue, .green, .yellow, .orange, .pink, .purple].randomElement() ?? .blue,
                creationTime: Date().timeIntervalSinceReferenceDate
            )
        }
    }
}

struct ConfettiParticle {
    let x: Double
    let y: Double
    let speed: Double
    let lifetime: Double
    let rotationSpeed: Double
    let wobble: Double
    let color: Color
    let creationTime: TimeInterval
}

#Preview {
    MilestoneView(
        milestone: ComparisonEngine.distanceMilestones[0],
        theme: .animals,
        onDismiss: {}
    )
}
