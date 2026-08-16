// Edited by FBronski
// 20.07.2026

import SwiftUI

struct NotificationsSetupView: View {
    @State var viewModel: RootViewModel
    @State private var showIncoming = true
    @AppStorage("languageIndex") private var languageIndex = 0

    private func t(_ key: AppTextKey) -> String {
        appText(key, languageIndex: languageIndex)
    }

    var body: some View {
        VStack {
            VStack {
                HStack {
                    Text(t(.notificationStatusLine))
                    Spacer()
                    VStack {
                        switch(viewModel.status) {
                        case .notDetermined:
                            Text(t(.notDetermined))
                        case .denied:
                            Text(t(.denied))
                        case .authorized:
                            Text(t(.authorized)).bold(true)
                        case .provisional:
                            Text(t(.provisional))
                        case .ephemeral:
                            Text(t(.ephemeral))
                        @unknown default:
                            Text(t(.unknown))
                        }
                    }
                }
                .padding()

                Button(t(.checkNotificationStatus), systemImage: "arrow.clockwise") {
                    Task { await viewModel.checkStatus() }
                }
                .padding()

                Picker("", selection: $viewModel.requestType) {
                    Text(t(.explicit)).tag(0)
                    Text(t(.provisional)).tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                Button(t(.requestPermission), systemImage: "gear.badge.questionmark") {
                    Task { await viewModel.requestPermission() }
                }
                .padding()
            }

            Spacer()

            VStack {
                Button(t(.testLocalPush), systemImage: "paperplane") {
                    //Task { await viewModel.sendLocalPush() }
                }
                .padding()
            }

            VStack {
                Button(t(.performNetworkRequest), systemImage: "network") {
                    Task { await viewModel.performDummyNetworkRequest() }
                }
                .padding()
                Text(viewModel.networkStatus)
            }

            VStack {
                HStack {
                    Text(t(.title)).bold()
                    Text(viewModel.notificationTitle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text(t(.subtitle)).bold()
                    Text(viewModel.notificationSubtitle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text(t(.body)).bold()
                    Text(viewModel.notificationBody)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text(t(.immichId)).bold()
                    Text(viewModel.notificationImmichId)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text(t(.customActions)).bold()
                    Text(viewModel.customAction)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .sheet(isPresented: $viewModel.isPresentingSettings) {
            Form {
                Toggle(t(.incomingPaymentsNotifications), isOn: $showIncoming)
            }
            .presentationDetents([.medium])
        }
    }
}

#Preview {
    NotificationsSetupView(viewModel: RootViewModel())
}
