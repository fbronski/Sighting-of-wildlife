// Edited by FBronski
// 20.07.2026

import SwiftUI

private enum RootTab: Hashable {
    case sichtungen
    case archive
    case settings
}

@MainActor
struct RootView: View {
    @State var viewModel: RootViewModel
    let appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("languageIndex") private var languageIndex = 0
    @AppStorage("hasAskedPreferredAppLanguage") private var hasAskedPreferredAppLanguage = false
    @State private var detectedLanguage: AppLanguage?
    @State private var showPreferredLanguageAlert = false
    @State private var selectedTab: RootTab = .sichtungen

    private var selectedLanguage: AppLanguage {
        AppLanguage.language(for: languageIndex)
    }

    private var selectedLocale: Locale {
        Locale(identifier: selectedLanguage.localeIdentifier)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SichtungView(viewModel: viewModel)
                .tabItem {
                    Label(appText(.wildSightings, languageIndex: languageIndex), systemImage: "photo.artframe.circle")
                }
                .tag(RootTab.sichtungen)

            ContentView(viewModel: viewModel)
                .tabItem {
                    Label(appText(.archiveImmich, languageIndex: languageIndex), systemImage: "archivebox.circle")
                }
                .tag(RootTab.archive)

            SettingsView(viewModel: $viewModel)
                .tabItem {
                    Label(appText(.settings, languageIndex: languageIndex), systemImage: "gear.circle")
                }
                .tag(RootTab.settings)
        }
        .environment(\.locale, selectedLocale)
        .onAppear {
            preparePreferredLanguagePromptIfNeeded()
            updateSichtungVisibility()
        }
        .onChange(of: selectedTab) { _, _ in
            updateSichtungVisibility()
        }
        .onChange(of: scenePhase) { _, _ in
            updateSichtungVisibility()
        }
        .onDisappear {
            appDelegate.setSichtungViewVisible(false)
        }
        .alert(appText(.confirmUseLanguage, languageIndex: languageIndex), isPresented: $showPreferredLanguageAlert, presenting: detectedLanguage) { language in
            Button(String(format: appText(.useLanguageButton, languageIndex: languageIndex), language.name)) {
                languageIndex = language.id
                hasAskedPreferredAppLanguage = true
            }
            Button(appText(.no, languageIndex: languageIndex), role: .cancel) {
                hasAskedPreferredAppLanguage = true
            }
        } message: { language in
            Text(String(format: appText(.detectedLanguageMessage, languageIndex: languageIndex), language.name))
        }
    }

    private func updateSichtungVisibility() {
        appDelegate.setSichtungViewVisible(selectedTab == .sichtungen && scenePhase == .active)
    }

    private func preparePreferredLanguagePromptIfNeeded() {
        guard !hasAskedPreferredAppLanguage,
              let preferredLanguage = detectedPreferredLanguage() else {
            return
        }

        detectedLanguage = preferredLanguage
        showPreferredLanguageAlert = true
    }

    private func detectedPreferredLanguage() -> AppLanguage? {
        guard let identifier = Locale.preferredLanguages.first else {
            return nil
        }

        let locale = Locale(identifier: identifier)
        let languageCode = locale.language.languageCode?.identifier ?? identifier.split(separator: "-").first.map(String.init) ?? identifier
        return AppLanguage.allCases.first { language in
            language.languageCodes.contains(languageCode)
        }
    }
}

//#if DEBUG

#Preview {
    RootView(viewModel: RootViewModel(), appDelegate: AppDelegate())
}

//#endif
