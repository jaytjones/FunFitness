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
    @State private var confettiActive = false
    @State private var shareCardURL: URL?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            ConfettiView(trigger: confettiTrigger, isActive: confettiActive)

            VStack(spacing: 24) {
                Spacer()

                Text(milestone.getEmoji(for: theme))
                    .font(.system(size: 100))
                    .scaleEffect(showContent ? 1.0 : 0.5)
                    .opacity(showContent ? 1.0 : 0.0)
                    .animation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.7), value: showContent)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text(milestone.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(reduceMotion ? .none : .easeOut(duration: 0.6).delay(0.2), value: showContent)

                    Text(milestone.getComparison(for: theme))
                        .font(.title3)
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(reduceMotion ? .none : .easeOut(duration: 0.6).delay(0.3), value: showContent)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Keep Going")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "#5B21B6"))
                            .clipShape(.rect(cornerRadius: 14))
                    }
                    .opacity(showContent ? 1.0 : 0.0)
                    .animation(reduceMotion ? .none : .easeOut(duration: 0.6).delay(0.4), value: showContent)
                    .accessibilityIdentifier("keepGoingButton")

                    shareButton
                        .opacity(showContent ? 1.0 : 0.0)
                        .animation(reduceMotion ? .none : .easeOut(duration: 0.6).delay(0.5), value: showContent)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .task {
            shareCardURL = ShareCardRenderer.pngURL(
                for: .milestone(milestone, theme: theme),
                filename: "funfitness_milestone.png"
            )
        }
        .onAppear {
            showContent = true
            if !reduceMotion {
                confettiTrigger += 1
                confettiActive = true
                // Stop driving the TimelineView after max particle lifetime
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    confettiActive = false
                }
            }
        }
        .sensoryFeedback(.success, trigger: confettiTrigger)
        .accessibilityElement(children: .contain)
    }

    // Shares the rendered milestone card image; falls back to text until the
    // image finishes rendering.
    @ViewBuilder
    private var shareButton: some View {
        Group {
            if let shareCardURL {
                ShareLink(item: shareCardURL, preview: SharePreview(milestone.title)) {
                    shareLabel
                }
            } else {
                ShareLink(item: "\(milestone.title)\n\(milestone.getComparison(for: theme))\n\nLogged with FunFitness!") {
                    shareLabel
                }
            }
        }
        .accessibilityIdentifier("milestoneShareButton")
    }

    private var shareLabel: some View {
        HStack {
            Image(systemName: "square.and.arrow.up")
            Text("Share")
        }
        .font(.subheadline)
        .foregroundStyle(Color(hex: "#9CA3AF"))
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.1))
        .clipShape(.rect(cornerRadius: 14))
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    let trigger: Int
    let isActive: Bool

    @State private var particles: [ConfettiParticle] = []
    @State private var viewWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(paused: !isActive)) { timeline in
                Canvas { context, _ in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    for particle in particles {
                        let progress = now - particle.creationTime
                        guard progress < particle.lifetime else { continue }

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
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { viewWidth = geometry.size.width }
            .onChange(of: geometry.size.width) { viewWidth = geometry.size.width }
            .onChange(of: trigger) { generateParticles() }
        }
    }

    private func generateParticles() {
        let width = viewWidth > 0 ? viewWidth : 400
        particles = (0..<60).map { _ in
            ConfettiParticle(
                x: Double.random(in: 0...width),
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
