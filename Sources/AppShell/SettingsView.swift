import Core
import SwiftUI

enum AppVersion {
    static let current: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.9"
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "Generali"
    case breaks = "Pause"
    case schedule = "Programmazione"
    case appearance = "Aspetto"
    case wellness = "Benessere"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "gearshape.fill"
        case .breaks: "clock.fill"
        case .schedule: "calendar"
        case .appearance: "paintbrush.fill"
        case .wellness: "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .general: .blue
        case .breaks: .orange
        case .schedule: .green
        case .appearance: .purple
        case .wellness: .pink
        }
    }
}

private struct SidebarIcon: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background {
                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                    .fill(color.gradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.25), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    )
            }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            VStack {
                List(SettingsTab.allCases, selection: $selectedTab) { tab in
                    Label {
                        Text(tab.rawValue)
                    } icon: {
                        SidebarIcon(systemImage: tab.icon, color: tab.color)
                    }
                    .tag(tab)
                }
                .listStyle(.sidebar)

                Spacer()

                Text("v\(AppVersion.current)")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .padding(.bottom, 12)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: 200)
        } detail: {
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsPane(model: model)
                case .breaks:
                    BreaksSettingsPane(model: model)
                case .schedule:
                    ScheduleSettingsPane(model: model)
                case .appearance:
                    AppearanceSettingsPane(model: model)
                case .wellness:
                    WellnessSettingsPane(model: model)
                }
            }
            .frame(minWidth: 380, idealWidth: 420)
        }
        .toolbar(content: { ToolbarItem { EmptyView() } })
        .toolbar(.hidden)
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject var model: AppModel

    private var idleMinutes: Binding<Double> {
        Binding(
            get: { model.settings.scheduleSettings.idleResetThreshold / 60 },
            set: { newValue in
                model.settings.scheduleSettings.idleResetThreshold = newValue * 60
                model.saveSettings()
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle("Avvia al login", isOn: Binding(
                    get: { model.settings.scheduleSettings.launchAtLogin },
                    set: { newValue in
                        model.settings.scheduleSettings.launchAtLogin = newValue
                        model.saveSettings()
                    }
                ))
            } footer: {
                Text("Avvia Knook Ita automaticamente quando accedi.")
            }

            Section {
                Toggle("Pausa durante le app a schermo intero", isOn: Binding(
                    get: { model.settings.smartPauseSettings.pauseDuringFullscreenFocus },
                    set: { newValue in
                        model.settings.smartPauseSettings.pauseDuringFullscreenFocus = newValue
                        model.saveSettings()
                    }
                ))

                Toggle("Pausa durante le chiamate", isOn: Binding(
                    get: { model.settings.smartPauseSettings.pauseDuringMicrophoneActive },
                    set: { newValue in
                        model.settings.smartPauseSettings.pauseDuringMicrophoneActive = newValue
                        model.saveSettings()
                    }
                ))
            } footer: {
                Text("Mette automaticamente in pausa i promemoria durante le app a schermo intero o quando il microfono è in uso.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Soglia di inattività")
                        Spacer()
                        Text("\(Int(idleMinutes.wrappedValue)) min")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: idleMinutes, in: 1...15, step: 1)
                }
            } footer: {
                Text("Azzera il timer delle pause dopo questo periodo di inattività.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Generali")
    }
}

private struct BreaksSettingsPane: View {
    @ObservedObject var model: AppModel

    private var workMinutes: Binding<Double> {
        Binding(
            get: { model.settings.breakSettings.workInterval / 60 },
            set: { newValue in
                model.settings.breakSettings.workInterval = newValue * 60
                model.saveSettings()
            }
        )
    }

    private var breakSeconds: Binding<Double> {
        Binding(
            get: { model.settings.breakSettings.microBreakDuration },
            set: { newValue in
                model.settings.breakSettings.microBreakDuration = newValue
                model.saveSettings()
            }
        )
    }

    private var longBreakMinutes: Binding<Double> {
        Binding(
            get: { model.settings.breakSettings.longBreakDuration / 60 },
            set: { newValue in
                model.settings.breakSettings.longBreakDuration = newValue * 60
                model.saveSettings()
            }
        )
    }

    private var longBreakCadence: Binding<Int> {
        Binding(
            get: { model.settings.breakSettings.longBreakCadence },
            set: { newValue in
                model.settings.breakSettings.longBreakCadence = newValue
                model.saveSettings()
            }
        )
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Durata lavoro")
                        Spacer()
                        Text("\(Int(workMinutes.wrappedValue)) min")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: workMinutes, in: 10...90, step: 5)
                }
            } footer: {
                Text("Quanto lavori prima che appaia un promemoria di pausa.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Durata pausa")
                        Spacer()
                        Text("\(Int(breakSeconds.wrappedValue)) sec")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: breakSeconds, in: 10...120, step: 5)
                }
            } footer: {
                Text("Per quanto tempo la pausa resta visibile sullo schermo.")
            }

            Section {
                Picker("Regola salto", selection: Binding(
                    get: { model.settings.breakSettings.skipPolicy },
                    set: { newValue in
                        model.settings.breakSettings.skipPolicy = newValue
                        model.saveSettings()
                    }
                )) {
                    ForEach(SkipPolicy.allCases) { policy in
                        Text(policy.title).tag(policy)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Consenti di terminare le pause in anticipo", isOn: Binding(
                    get: { model.settings.breakSettings.allowEarlyEnd },
                    set: { newValue in
                        model.settings.breakSettings.allowEarlyEnd = newValue
                        model.saveSettings()
                    }
                ))
            } footer: {
                Text("Flessibile: salta quando vuoi. Bilanciata: salta dopo 8 secondi. Rigorosa: non puoi saltare.")
            }

            Section {
                Toggle("Pause lunghe", isOn: Binding(
                    get: { model.settings.breakSettings.longBreaksEnabled },
                    set: { newValue in
                        model.settings.breakSettings.longBreaksEnabled = newValue
                        model.saveSettings()
                    }
                ))

                if model.settings.breakSettings.longBreaksEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Durata pausa lunga")
                            Spacer()
                            Text("\(Int(longBreakMinutes.wrappedValue)) min")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: longBreakMinutes, in: 1...15, step: 1)
                    }

                    Stepper(value: longBreakCadence, in: 2...10) {
                        HStack {
                            Text("Ogni")
                            Text("\(longBreakCadence.wrappedValue) pause")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("Ogni tanto fai una pausa più lunga invece di una micro pausa.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Pause")
    }
}

private struct AppearanceSettingsPane: View {
    @ObservedObject var model: AppModel

    private static func previewSound(_ sound: BreakSound) {
        switch sound {
        case .none: break
        case .breeze: NSSound(named: "Submarine")?.play()
        case .glass: NSSound(named: "Glass")?.play()
        case .hero: NSSound(named: "Hero")?.play()
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Suono pausa", selection: Binding(
                    get: { model.settings.breakSettings.selectedSound },
                    set: { newValue in
                        model.settings.breakSettings.selectedSound = newValue
                        model.saveSettings()
                        Self.previewSound(newValue)
                    }
                )) {
                    ForEach(BreakSound.allCases) { sound in
                        Text(sound.title).tag(sound)
                    }
                }
            } footer: {
                Text("Suono riprodotto quando inizia una pausa.")
            }

            Section {
                let selected = model.settings.breakSettings.backgroundStyle
                let usesDesktopWallpaper = model.settings.breakSettings.useDesktopWallpaper
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(BreakBackgroundStyle.allCases) { style in
                        let isSelected = style == selected
                        Button {
                            guard !usesDesktopWallpaper else { return }
                            model.settings.breakSettings.backgroundStyle = style
                            model.saveSettings()
                        } label: {
                            VStack(spacing: 6) {
                                BreakBackgroundView(style: style)
                                    .frame(height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(isSelected && !usesDesktopWallpaper ? Color.accentColor : .clear, lineWidth: 2)
                                    )
                                    .saturation(usesDesktopWallpaper ? 0.25 : 1)
                                    .opacity(usesDesktopWallpaper ? 0.35 : 1)

                                Text(style.title)
                                    .font(.caption)
                                    .foregroundStyle(usesDesktopWallpaper ? .tertiary : (isSelected ? .primary : .secondary))
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(usesDesktopWallpaper)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Stile sfondo")
            } footer: {
                Text(model.settings.breakSettings.useDesktopWallpaper ? "Disattiva lo sfondo del Mac per scegliere un tema colore." : "Tema visivo della schermata di pausa.")
            }

            Section {
                Toggle("Usa lo sfondo del Mac", isOn: Binding(
                    get: { model.settings.breakSettings.useDesktopWallpaper },
                    set: { newValue in
                        model.settings.breakSettings.useDesktopWallpaper = newValue
                        if !newValue {
                            model.settings.breakSettings.blurDesktopWallpaper = false
                        }
                        model.saveSettings()
                    }
                ))

                Toggle("Sfoca lo sfondo del Mac", isOn: Binding(
                    get: { model.settings.breakSettings.blurDesktopWallpaper },
                    set: { newValue in
                        model.settings.breakSettings.blurDesktopWallpaper = newValue
                        model.saveSettings()
                    }
                ))
                .disabled(!model.settings.breakSettings.useDesktopWallpaper)
            } footer: {
                Text("Quando è attivo, la schermata di pausa usa lo sfondo attuale di macOS al posto del tema colore.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Aspetto")
    }
}

private struct ScheduleSettingsPane: View {
    @ObservedObject var model: AppModel

    private var hasOfficeHours: Bool {
        !model.settings.scheduleSettings.officeHours.isEmpty
    }

    private var hasSuggestions: Bool {
        model.activityLogStore.hasEnoughData()
    }

    var body: some View {
        Form {
            Section {
                if hasOfficeHours {
                    ForEach(model.settings.scheduleSettings.officeHours) { rule in
                        HStack {
                            Text(weekdayName(rule.weekday))
                                .frame(width: 50, alignment: .leading)
                            Text("\(formatTime(rule.startMinutes)) \u{2013} \(formatTime(rule.endMinutes))")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Cancella orari di lavoro") {
                        model.clearOfficeHours()
                    }
                } else if hasSuggestions {
                    Text("Knook Ita ha imparato il tuo ritmo di lavoro.")
                        .foregroundStyle(.secondary)

                    Button("Applica orari suggeriti") {
                        model.applySuggestedOfficeHours()
                    }
                } else {
                    Text("Knook Ita sta imparando quando lavori. Ricontrolla tra qualche giorno.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Orari di lavoro")
            } footer: {
                Text("Quando imposti gli orari di lavoro, i promemoria delle pause funzionano solo in quelle fasce.")
            }
        }
        .formStyle(.grouped)
    }

    private func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "?" }
        return symbols[weekday - 1]
    }

    private func formatTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = h
        components.minute = m
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
}

private struct WellnessSettingsPane: View {
    @ObservedObject var model: AppModel

    private var postureMinutes: Binding<Double> {
        Binding(
            get: { model.settings.wellnessSettings.posture.interval / 60 },
            set: { newValue in
                model.settings.wellnessSettings.posture.interval = newValue * 60
                model.saveSettings()
            }
        )
    }

    private var blinkMinutes: Binding<Double> {
        Binding(
            get: { model.settings.wellnessSettings.blink.interval / 60 },
            set: { newValue in
                model.settings.wellnessSettings.blink.interval = newValue * 60
                model.saveSettings()
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle("Promemoria postura", isOn: Binding(
                    get: { model.settings.wellnessSettings.posture.isEnabled },
                    set: { newValue in
                        model.settings.wellnessSettings.posture.isEnabled = newValue
                        model.saveSettings()
                    }
                ))

                if model.settings.wellnessSettings.posture.isEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Intervallo")
                            Spacer()
                            Text("\(Int(postureMinutes.wrappedValue)) min")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: postureMinutes, in: 5...60, step: 5)
                    }

                    Picker("Metodo", selection: Binding(
                        get: { model.settings.wellnessSettings.posture.deliveryStyle },
                        set: { newValue in
                            model.settings.wellnessSettings.posture.deliveryStyle = newValue
                            model.saveSettings()
                        }
                    )) {
                        Text("Pannello").tag(WellnessDeliveryStyle.panel)
                        Text("Notifica").tag(WellnessDeliveryStyle.notification)
                    }
                    .pickerStyle(.segmented)
                }
            } footer: {
                Text("Promemoria delicati per controllare la postura.")
            }

            Section {
                Toggle("Promemoria occhi", isOn: Binding(
                    get: { model.settings.wellnessSettings.blink.isEnabled },
                    set: { newValue in
                        model.settings.wellnessSettings.blink.isEnabled = newValue
                        model.saveSettings()
                    }
                ))

                if model.settings.wellnessSettings.blink.isEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Intervallo")
                            Spacer()
                            Text("\(Int(blinkMinutes.wrappedValue)) min")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: blinkMinutes, in: 5...30, step: 5)
                    }

                    Picker("Metodo", selection: Binding(
                        get: { model.settings.wellnessSettings.blink.deliveryStyle },
                        set: { newValue in
                            model.settings.wellnessSettings.blink.deliveryStyle = newValue
                            model.saveSettings()
                        }
                    )) {
                        Text("Pannello").tag(WellnessDeliveryStyle.panel)
                        Text("Notifica").tag(WellnessDeliveryStyle.notification)
                    }
                    .pickerStyle(.segmented)
                }
            } footer: {
                Text("Promemoria per sbattere le palpebre e riposare gli occhi.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Benessere")
    }
}
