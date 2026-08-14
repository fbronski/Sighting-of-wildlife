// Edited by FBronski
// 20.07.2026

import SwiftUI

class PreferencesViewModel: ObservableObject {
    @AppStorage("languageIndex") var languageIndex = 0
    @AppStorage("ftpIP") var ftpIP = ""
    @AppStorage("ftpUser") var ftpUser = ""
    @AppStorage("ftpPassword") var ftpPassword = ""
    @AppStorage("ftpPort") var ftpPort = ""
    @AppStorage("ftpSecurityIndex") var ftpSecurityIndex = 0
    @AppStorage("modeIndex") var modeIndex = 0
    @AppStorage("enableNotifications") var enableNotifications = true
    @AppStorage("notificationIndex") var notificationIndex = 0
    @AppStorage("notificationPromo") var notificationPromo = true
    @AppStorage("notificationUpdates") var notificationUpdates = true
    @AppStorage("color") var color = 0xFF3100
    @AppStorage("immichurltext") var immichurltext = ""
    @AppStorage("immichapikey") var immichapikey = ""
    @Published var showingAlert = false
}

class WildsichtungCamera: ObservableObject {
    public let id: Int64
    var CameraRealName: String
    var CameraName: String
    var CameraType: String
    var creationDate: Date
    var standOrt64: String
    
    
    init(id: Int64,CameraRealName: String,CameraName: String, CameraType: String, standOrt64: String, creationDate: Date) {
        self.id = id
        self.CameraRealName = CameraRealName
        self.CameraName = CameraName
        self.CameraType = CameraType
        self.standOrt64 = standOrt64
        self.creationDate = creationDate
        
    }
}

private struct CameraFTPPayload: Codable {
    let id: Int64
    let cameraRealName: String
    let cameraName: String
    let cameraType: String
    let creationDate: String
    
    init(camera: WildsichtungCamera) {
        self.id = camera.id
        self.cameraRealName = camera.CameraRealName
        self.cameraName = camera.CameraName
        self.cameraType = camera.CameraType
        self.creationDate = camera.creationDate.formattedString(dateFormat: "yyyy-MM-dd’T’HH:mm:ss")
    }
}


struct SettingsView: View {
    @StateObject var model = PreferencesViewModel()
    @StateObject var cameraModel = WildsichtungCamera(id: 0, CameraRealName: "", CameraName: "", CameraType: "", standOrt64: "", creationDate: Date())
    
    @Binding var viewModel: RootViewModel
    @State private var cameras: [WildsichtungCamera] = []
    @State private var isRefreshing = false
    @State private var showFTPUploadAlert = false
    @State private var ftpUploadMessage = ""
    
    var body: some View {
        /// Ff you want to show the search bar, just change `isSearchable` to true.

        SettingStack(isSearchable: false) {
            SettingPage(title: "Einstellungen") {
                SettingGroup {
                    SettingPage(title: "Allgemein") {
                        SettingCustomView(id: "Header View") {
                            VStack(spacing: 10) {
                                Image(systemName: "gearshape.fill")
                                    .font(.largeTitle)

                                Text("Wildsichtungen Setting!")
                                    .font(.headline)
                            }
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color(hex: 0x006DC1))
                            .frame(maxWidth: .infinity)
                            .padding(32)
                            .background(Color(hex: 0x006DC1).opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }

                        SettingGroup {
                            SettingButton(title: "Siehe Wildsichtung auf GitHub") {
                                if let url = URL(string: "https://github.com/fbronski/Sighting-of-wildlife") {
                                    #if os(iOS)
                                        UIApplication.shared.open(url)
                                    #else
                                        NSWorkspace.shared.open(url)
                                    #endif
                                }
                            }

                            /*SettingButton(title: "My Twitter") {
                                if let url = URL(string: "https://twitter.com/aheze0") {
                                    #if os(iOS)
                                        UIApplication.shared.open(url)
                                    #else
                                        NSWorkspace.shared.open(url)
                                    #endif
                                }
                            }*/
                        }

                        SettingGroup {
                            SettingPicker(
                                title: "Language",
                                choices: [
                                    "English",
                                    "Spanish",
                                    "French",
                                    "Italian",
                                    "Chinese",
                                    "Japanese",
                                    "Korean",
                                    "German",
                                ],
                                selectedIndex: $model.languageIndex
                            )
                        }

                        SettingGroup(header: "FTP Settings", footer: "Optionale Anbindung an einen FTP Server: \(model.ftpIP)") {
                            /*SettingSlider(value: $model.brightness, range: 0 ... 100, minimumImage: Image(systemName: "sun.min"), maximumImage: Image(systemName: "sun.max"))*/
                            SettingTextField(placeholder: "Host / IP", secure: false, text: $model.ftpIP)
                            SettingTextField(placeholder: "Ftp Benutzer",secure: false, text: $model.ftpUser)
                            SettingTextField(placeholder: "Ftp Password", secure: true,text: $model.ftpPassword)
                            SettingTextField(placeholder: "FTP Port", secure: false,text: $model.ftpPort)
                            SettingPicker(
                                title: "Protokoll",
                                choices: ["FTP", "FTPS explizit"],
                                selectedIndex: $model.ftpSecurityIndex
                            )
                            .pickerDisplayMode(.menu)
                        }

                        SettingGroup(header: "Immich Url") {
                            //SettingToggle(title: "Turbo Mode", isOn: $model.turboMode)
                            SettingTextField(placeholder: "https://www.example.com",secure: false, text: $model.immichurltext)
                            
                            /*if model.turboMode {
                                SettingText(title: "Turbo mode is on!", foregroundColor: .secondary)
                            }

                            SettingButton(title: "Show Alert") {
                                model.showingAlert = true
                            }*/
                        }
                        
                        SettingGroup(header: "Immich API Key") {
                            //SettingToggle(title: "Turbo Mode", isOn: $model.turboMode)
                            SettingTextField(placeholder: "API Key",secure: true, text: $model.immichapikey)
                            
                            
                        }
                        
                    }
                    .previewIcon(icon: .system(icon: "gear", backgroundColor: Color(hex: 0x006DC1)))
                }
                
                SettingGroup {
                    SettingPage(title: "Kameras") {
                        SettingGroup {
                            SettingButton(title: "Neue Kamera hinzufügen") {
                                addNewCamera()
                            }
                            
                            SettingButton(title: "Kameras an den JagdBildBot senden") {
                                Task {
                                    await sendCamerasPerFTP()
                                }
                            }
                        }
                        
                        SettingCustomView(id: "Kameras") {
                            kameras
                        }
                    }.previewIcon(icon: .system(icon: "camera", backgroundColor: Color(hex: 0x239923)))
                }
                
                SettingGroup {
                    SettingPage(title: "Notifications") {
                        SettingGroup(footer: model.enableNotifications ? nil : "Turn on to see more settings.") {
                            SettingToggle(title: "Enable Notifications", isOn: $model.enableNotifications)
                        }
                        
                        if model.enableNotifications {
                            
                            
                            SettingGroup {
                                SettingPicker(
                                    title: "Notification Status",
                                    choices: [
                                        "nicht Entschieden",
                                        "Verweigert",
                                        "Autorisiert",
                                        "Provisional",
                                        "Ephemeral"
                                    ],
                                    selectedIndex: $model.notificationIndex
                                )
                                .pickerDisplayMode(.menu)
                                
                                SettingButton(title: "Check Notificationstatus") {
                                    Task { await viewModel.checkStatus() }
                                }
                            }
                            
                           
                        }
                    }
                    .previewIcon(icon: .system(icon: "bell.badge.fill", backgroundColor: Color(hex: 0xFF2300)))
                }
                   
                SettingGroup {
                    SettingPage(title: "Über Wildsichtung", selectedChoice: "Wildsichtung") {
                        SettingGroup {
                            SettingText(title: "Was ist Wildsichtung", bold: true)
                            SettingText(title: "Wildsichtung ist ein App, welche dir hilft, das Wildmanagement zu verbessern. Wildtiere zu Monitoren und zu beobachten. 🐗 🦌 🦊 🦡")
                            SettingText(title: "Was benötige ich für Wildsichtung", bold: true)
                            SettingButton(title: "Siehe Wildsichtung auf GitHub") {
                                if let url = URL(string: "https://github.com/fbronski/Sighting-of-wildlife") {
                                    #if os(iOS)
                                    UIApplication.shared.open(url)
                                    #else
                                    NSWorkspace.shared.open(url)
                                    #endif
                                }
                            }
                            
                            
                        }
                        
                        SettingGroup {
                            SettingCustomView {
                                HStack {
                                    Spacer()
                                    Image("Hirsch")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .scaledToFit()
                                        .frame(width: 160)
                                        .padding(20)
                                    Spacer()
                                }
                                    
                               
                                    
                                
                                
                            }
                        }
                        
                    }.previewIcon(icon: .system(icon: "camera.on.rectangle", backgroundColor: Color(hex: 0xF09020)))
                }
                
                

                SettingCustomView(id: "Custom Footer", titleForSearch: "Wildsichtungen !") {
                    Text("Wildsichtungen")
                        .foregroundColor(.white)
                        .font(.headline)
                        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 20)
                        .background {
                            LinearGradient(
                                colors: [
                                    Color(hex: 0xFF00C7),
                                    Color(hex: 0xFFBF00),
                                ],
                                startPoint: .bottomLeading,
                                endPoint: .topTrailing
                            )
                            .brightness(50 / 200 - 0.5)
                        }
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                }

              
            }
        }
        /*.alert("Here's an alert!", isPresented: $model.showingAlert) {
           Button("OK") {}
        }*/
        .onAppear {
            refreshCameras()
        }
        .alert("FTP Upload", isPresented: $showFTPUploadAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(ftpUploadMessage)
        }
    }
    
    
    var kameras: some View {
        VStack(spacing: 0) {
            if cameras.isEmpty {
                Text("Keine Kameras vorhanden")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            } else {
                ForEach(cameras, id: \.id) { camera in
                    NavigationLink {
                        DetailCameraView(camera: camera) {
                            refreshCameras()
                        }
                    } label: {
                        cameraRow(camera)
                    }
                    .buttonStyle(.plain)

                    if camera.id != cameras.last?.id {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
    
    private func cameraRow(_ camera: WildsichtungCamera) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color(hex: 0x239923))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(camera.CameraRealName.isEmpty ? camera.CameraName : camera.CameraRealName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text([camera.CameraName, camera.CameraType].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .contentShape(Rectangle())
    }
    
    private func refreshCameras() {
        cameras = DatabaseManager.shared.getAllCameras()
    }
    
    private func sendCamerasPerFTP() async {
        refreshCameras()
        guard !cameras.isEmpty else {
            showFTPMessage("Keine Kameras zum Senden vorhanden.")
            return
        }
        
        guard let credentials = ftpCredentials else {
            showFTPMessage("FTP Einstellungen sind unvollständig oder der Port ist ungültig.")
            return
        }
        
        do {
            let payload = cameras.map(CameraFTPPayload.init(camera:))
            let payloadData = try JSONEncoder().encode(payload)
            guard let payloadText = String(data: payloadData, encoding: .utf8) else {
                showFTPMessage("Kameraeinträge konnten nicht serialisiert werden.")
                return
            }
            
            let command = CommandModel(
                id: UUID().uuidString,
                cmd: "SyncCameras",
                text: payloadText,
                immichid: "",
                creationDate: Date.now.formattedString(dateFormat: "yyyy-MM-dd’T’HH:mm:ss")
            )
            let commandText = command.getJsonStringAsBase64()
            let filename = "XXXX_CMD_\(Date.now.timeIntervalSince1970).txt"
            let ftpClient = FTPClient(credentials: credentials, remotePath: "")
            let filesToUpload: [FTPUploadable] = [
                .data(data: Data(commandText.utf8), remoteFileName: filename)
            ]
            
            try await ftpClient.upload(files: filesToUpload) { progress in
                print("Camera upload progress: \(progress.fractionCompleted * 100)%")
            }
        } catch {
            showFTPMessage("FTP Upload fehlgeschlagen: \(error.localizedDescription)")
        }
    }
    
    private var ftpCredentials: FTPCredentials? {
        let host = UserDefaults.standard.string(forKey: "ftpIP") ?? ""
        let portText = UserDefaults.standard.string(forKey: "ftpPort") ?? ""
        let username = UserDefaults.standard.string(forKey: "ftpUser") ?? ""
        let password = UserDefaults.standard.string(forKey: "ftpPassword") ?? ""
        
        guard !host.isEmpty,
              !username.isEmpty,
              let port = UInt16(portText) else {
            return nil
        }
        
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let security: FTPConnectionSecurity = model.ftpSecurityIndex == 1 ? .explicitTLS : .none
        let allowsUntrustedCertificate = security == .explicitTLS && normalizedHost == "upload.wildbild.cloud"
        return FTPCredentials(
            host: host,
            port: port,
            username: username,
            password: password,
            security: security,
            allowsUntrustedTLSCertificate: allowsUntrustedCertificate
        )
    }
    
    private func showFTPMessage(_ message: String) {
        ftpUploadMessage = message
        showFTPUploadAlert = true
    }
    
    private func addNewCamera() {
        let cameraName = uniqueCameraName()
        _ = DatabaseManager.shared.addCamera(
            CameraName: cameraName,
            CameraRealName: "Neue Kamera",
            CameraType: "Wildkamera",
            standOrt64: "",
            creationDate: Date()
        )
        refreshCameras()
    }
    
    private func uniqueCameraName() -> String {
        var cameraName = randomString(length: 4)
        let existingCameraNames = Set(cameras.map(\.CameraName))
        
        while existingCameraNames.contains(cameraName) {
            cameraName = randomString(length: 4)
        }
        
        return cameraName
    }
    
    func randomString(length: Int) -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString = ""
        for _ in 0 ..< length {
            let randomIndex = Int(arc4random_uniform(UInt32(letters.count)))
            let letter = letters[letters.index(letters.startIndex, offsetBy: randomIndex)]
            randomString += String(letter)
        }
        return randomString
    }
}
