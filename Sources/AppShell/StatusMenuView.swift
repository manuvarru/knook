import AppKit
import Core
import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var model: AppModel
    var dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if shouldShowUpdateBanner {
                updateBanner
                Divider().padding(.vertical, 4)
            }

            if model.menuBarMode == .setup {
                setupMenu
            } else {
                activeMenu
            }
        }
    }

    @ViewBuilder
    private var updateBanner: some View {
        switch model.updateState {
        case let .available(version, releaseURL):
            VStack(alignment: .leading, spacing: 10) {
                Text("Knook Ita \(version) è disponibile")
                    .font(.headline)

                Text("Aggiorna con Homebrew oppure apri l'ultima release GitHub se Homebrew non è disponibile.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("Aggiorna") {
                        model.installAvailableUpdate()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Più tardi") {
                        model.dismissUpdateNotice()
                    }
                    .buttonStyle(.bordered)

                    if let releaseURL {
                        Link("Vedi release", destination: releaseURL)
                            .font(.footnote)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
        case .installing:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Preparazione aggiornamento...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        case let .installingProgress(step):
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(step)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        case .installed:
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Aggiornamento installato. Riavvio...")
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        case let .error(message):
            VStack(alignment: .leading, spacing: 8) {
                Text("Aggiornamento non riuscito")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)

                HStack(spacing: 8) {
                    Button("Riprova") {
                        model.checkForUpdates()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Mostra nel Terminale") {
                        model.retryUpdateInTerminal()
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button("Chiudi") {
                        model.dismissUpdateNotice()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
        default:
            EmptyView()
        }
    }

    private var shouldShowUpdateBanner: Bool {
        switch model.updateState {
        case .available, .error, .installing, .installingProgress, .installed:
            true
        default:
            false
        }
    }

    private var setupMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Inizia con la configurazione consigliata oppure modificala prima di partire.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider().padding(.vertical, 4)

            PopoverMenuRow(title: "Inizia a usare Knook Ita", systemImage: "play.fill") {
                model.dismissStarterSetupWithDefaults()
                dismiss()
            }

            PopoverMenuRow(title: "Cerca aggiornamenti", systemImage: "arrow.down.circle") {
                model.checkForUpdates()
                dismiss()
            }

            Divider().padding(.vertical, 4)

            PopoverMenuRow(
                title: model.appState.activeBreak == nil ? "Esci" : "Esci non disponibile durante la pausa",
                systemImage: "power",
                isLast: true,
                isDisabled: model.appState.activeBreak != nil
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 8)
    }

    private var activeMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.appState.statusText)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            HStack(spacing: 12) {
                Label("\(model.breakStats.todayCount()) oggi", systemImage: "cup.and.saucer")
                if model.breakStats.currentStreak > 0 {
                    Label("Serie di \(model.breakStats.currentStreak) giorni", systemImage: "flame")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            Divider().padding(.vertical, 4)

            PopoverMenuRow(title: "Avvia pausa ora", systemImage: "cup.and.saucer") {
                model.startBreakNow()
                dismiss()
            }

            PopoverMenuRow(title: "Rimanda di 5 minuti", systemImage: "clock.arrow.circlepath") {
                model.postpone(minutes: 5)
                dismiss()
            }

            PopoverMenuRow(title: "Rimanda di 15 minuti", systemImage: "clock.arrow.circlepath") {
                model.postpone(minutes: 15)
                dismiss()
            }

            PopoverMenuRow(
                title: model.appState.isPaused ? "Riprendi promemoria" : "Metti in pausa promemoria",
                systemImage: model.appState.isPaused ? "play.circle" : "pause.circle"
            ) {
                model.pauseOrResume()
                dismiss()
            }

            if model.appState.activeBreak != nil {
                PopoverMenuRow(title: "Salta pausa attuale", systemImage: "forward.end") {
                    model.skipCurrentBreak()
                    dismiss()
                }

                PopoverMenuRow(title: "Termina pausa prima", systemImage: "stop.circle") {
                    model.endBreakEarly()
                    dismiss()
                }
            }

            PopoverMenuRow(title: "Apri impostazioni", systemImage: "gearshape") {
                model.openSettings()
                dismiss()
            }

            PopoverMenuRow(title: "Cerca aggiornamenti", systemImage: "arrow.down.circle") {
                model.checkForUpdates()
                dismiss()
            }

            Divider().padding(.vertical, 4)

            PopoverMenuRow(title: "Esci", systemImage: "power", isLast: true) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 8)
    }
}

private struct PopoverMenuRow: View {
    let title: String
    let systemImage: String?
    let isLast: Bool
    let isDisabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    init(title: String, systemImage: String? = nil, isLast: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isLast = isLast
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if let systemImage {
                    Image(systemName: systemImage)
                        .frame(width: 20)
                }
                Text(title)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .foregroundStyle(foregroundColor)
        .background(!isDisabled && isHovered ? Color.accentColor : .clear)
        .clipShape(MenuRowShape(topRadius: 4, bottomRadius: isLast ? 12 : 4))
        .onHover { isHovered = isDisabled ? false : $0 }
    }

    private var foregroundColor: Color {
        if isDisabled { return .secondary }
        return isHovered ? .white : .primary
    }
}

private struct MenuRowShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let tr = topRadius
        let br = bottomRadius
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tr, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + tr), radius: tr)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - br, y: rect.maxY), radius: br)
        path.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - br), radius: br)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tr))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + tr, y: rect.minY), radius: tr)
        path.closeSubpath()
        return path
    }
}
