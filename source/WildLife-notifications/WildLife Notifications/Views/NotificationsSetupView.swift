// Edited by FBronski
// 20.07.2026

import SwiftUI

struct NotificationsSetupView: View {
    @State var viewModel: RootViewModel
    @State private var showIncoming = true
    var body: some View {
        VStack {
            VStack {
                HStack {
                    Text("Push notifications status:")
                    Spacer()
                    VStack {
                        switch(viewModel.status) {
                            case .notDetermined:
                            Text("nicht entschieden")
                        case .denied:
                            Text("Verweigert")
                        case .authorized:
                            Text("Autorisiert").bold(true)
                        case .provisional:
                            Text("Provisional")
                        case .ephemeral:
                            Text("Ephemeral")
                        @unknown default:
                            Text("Unbekannt")
                        }
                        
                    }
                }
                .padding()

                Button("Check status", systemImage: "arrow.clockwise") {
                    Task { await viewModel.checkStatus() }
                }
                .padding()

                Picker("", selection: $viewModel.requestType) {
                    Text("Explicit").tag(0)
                    Text("Provisional").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                Button("Request permission", systemImage: "gear.badge.questionmark") {
                    Task { await viewModel.requestPermission() }
                }
                .padding()
            }

            Spacer()

            VStack {
                Button("Test local push", systemImage: "paperplane") {
                    //Task { await viewModel.sendLocalPush() }
                }
                .padding()
            }

            VStack {
                Button("Perform network request", systemImage: "network") {
                    Task { await viewModel.performDummyNetworkRequest() }
                }
                .padding()
                Text(viewModel.networkStatus)
            }

            VStack {
                HStack {
                    Text("Title:").bold()
                    Text(viewModel.notificationTitle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text("Subtitle:").bold()
                    Text(viewModel.notificationSubtitle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text("Body:").bold()
                    Text(viewModel.notificationBody)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text("ImmichId:").bold()
                    Text(viewModel.notificationImmichId)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text("Custom actions:").bold()
                    Text(viewModel.customAction)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()

            //Spacer()

            /*VStack {
                Button("Subscribe to topic", systemImage: "bell") {
                    Task { await viewModel.subscribeToTopic() }
                }
                .padding()

                Button("Unsubscribe from topic", systemImage: "bell.slash") {
                    Task { await viewModel.unsubscribeFromTopic() }
                }
                .padding()
            }*/
        }
        .sheet(isPresented: $viewModel.isPresentingSettings) {
            Form {
                Toggle("Enable incoming payments notifications", isOn: $showIncoming)
            }
            .presentationDetents([.medium])
        }
    }
}

#Preview {
    NotificationsSetupView(viewModel: RootViewModel())
}
