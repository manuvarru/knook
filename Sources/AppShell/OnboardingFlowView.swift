import ConfettiSwiftUI
import Core
import SwiftUI

enum OnboardingStep: Equatable {
    case welcome
    case durationSetup
    case complete
}

struct OnboardingFlowView: View {
    @State private var step: OnboardingStep = .welcome
    @State private var welcomeVisible = false
    @State private var setupVisible = false
    @State private var completeVisible = false
    @State private var confettiTrigger = 0
    @State private var selectedPreset: OnboardingPreset = .eyeCare
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onFinish: (OnboardingPreset) -> Void

    private var enterSpring: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(duration: 0.45, bounce: 0.08)
    }
    private var exitCurve: Animation {
        reduceMotion ? .linear(duration: 0) : .timingCurve(0.23, 1, 0.32, 1, duration: 0.25)
    }
    private var chipAnimation: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(duration: 0.25, bounce: 0)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)

            ZStack {
                if step == .welcome {
                    welcomeContent
                        .offset(y: welcomeVisible ? 0 : 20)
                        .opacity(welcomeVisible ? 1 : 0)
                }

                if step == .durationSetup {
                    durationSetupContent
                        .offset(y: setupVisible ? 0 : 24)
                        .opacity(setupVisible ? 1 : 0)
                }

                if step == .complete {
                    completeContent
                        .offset(y: completeVisible ? 0 : 20)
                        .opacity(completeVisible ? 1 : 0)
                        .confettiCannon(
                            counter: $confettiTrigger,
                            num: 50,
                            colors: [.white, .white.opacity(0.8), .white.opacity(0.6)],
                            confettiSize: 8,
                            rainHeight: 600,
                            radius: 400,
                            repetitions: 2,
                            repetitionInterval: 0.5
                        )
                }
            }
        }
        .ignoresSafeArea()
        .task {
            withAnimation(enterSpring) {
                welcomeVisible = true
            }
            try? await Task.sleep(for: .seconds(3))
            withAnimation(exitCurve) {
                welcomeVisible = false
            }
            try? await Task.sleep(for: .milliseconds(300))
            step = .durationSetup
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(enterSpring) {
                setupVisible = true
            }
        }
    }

    private var welcomeContent: some View {
        VStack(spacing: 24) {
            pauseIcon(size: 64, cornerRadius: 16, barWidth: 7, barHeight: 26, barSpacing: 8)

            Text("Trova la tua pausa.")
                .font(.system(size: 42))
                .fontWeight(.semibold)
                .tracking(-1)
                .foregroundStyle(.white)
        }
    }

    private var durationSetupContent: some View {
        VStack(spacing: 0) {
            presetSelectionCard
                .frame(maxWidth: 580)
        }
    }

    private func handleFinishSetup(_ preset: OnboardingPreset) {
        selectedPreset = preset
        Task { @MainActor in
            withAnimation(exitCurve) {
                setupVisible = false
            }
            try? await Task.sleep(for: .milliseconds(300))
            step = .complete
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(enterSpring) {
                completeVisible = true
            }
            try? await Task.sleep(for: .milliseconds(200))
            confettiTrigger += 1
            try? await Task.sleep(for: .seconds(2.5))
            onFinish(preset)
        }
    }

    private var presetSelectionCard: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 14) {
                pauseIcon(size: 44, cornerRadius: 10, barWidth: 6, barHeight: 20, barSpacing: 6)

                Text("Scegli il tuo ritmo")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
            }

            Text("Scegli una configurazione per iniziare. Potrai personalizzarla più tardi nelle impostazioni.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))

            VStack(spacing: 12) {
                ForEach(OnboardingPreset.allCases, id: \.rawValue) { preset in
                    presetRow(preset)
                }
            }
        }
        .padding(32)
        .modifier(GlassCardModifier(cornerRadius: 28))
    }

    private func presetRow(_ preset: OnboardingPreset) -> some View {
        Button { handleFinishSetup(preset) } label: {
            HStack(spacing: 16) {
                Image(systemName: preset.systemImage)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text(preset.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(16)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .pointerCursor()
    }

    private var completeContent: some View {
        VStack(spacing: 24) {
            pauseIcon(size: 64, cornerRadius: 16, barWidth: 7, barHeight: 26, barSpacing: 8)

            Text("È tutto pronto!")
                .font(.system(size: 42))
                .fontWeight(.semibold)
                .tracking(-1)
                .foregroundStyle(.white)
        }
    }

    private func pauseIcon(size: CGFloat, cornerRadius: CGFloat, barWidth: CGFloat, barHeight: CGFloat, barSpacing: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.white)
            .frame(width: size, height: size)
            .overlay {
                HStack(spacing: barSpacing) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .frame(width: barWidth, height: barHeight)
                    RoundedRectangle(cornerRadius: 2.5)
                        .frame(width: barWidth, height: barHeight)
                }
                .foregroundStyle(.black)
            }
    }
}

private struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
#if compiler(>=6.3)
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            fallbackCard(content: content)
        }
#else
        fallbackCard(content: content)
#endif
    }

    private func fallbackCard(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            }
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
    }
}

private struct GlassChipModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
#if compiler(>=6.3)
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            fallbackChip(content: content)
        }
#else
        fallbackChip(content: content)
#endif
    }

    private func fallbackChip(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.15))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.thinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}
