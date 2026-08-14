// Edited by FBronski
// 20.07.2026

import Foundation
import CFNetwork
import Network
import Security

private final class FTPContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    func resumeOnce(_ operation: () -> Void) {
        lock.lock()
        defer { lock.unlock() }

        guard !didResume else { return }
        didResume = true
        operation()
    }
}

private final class FTPStreamSession: @unchecked Sendable {
    private let credentials: FTPCredentials
    private let remotePath: String
    private let bufferSize: Int
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private var isCancelled = false

    init(credentials: FTPCredentials, remotePath: String, bufferSize: Int) {
        self.credentials = credentials
        self.remotePath = remotePath
        self.bufferSize = bufferSize
    }

    func upload(
        files: [FTPUploadable],
        progress: Progress,
        progressHandler: @escaping (Progress) -> Void
    ) throws {
        try connect()
        defer { disconnect() }

        for uploadable in files {
            if isCancelled {
                throw FTPError.cancelled
            }

            switch uploadable {
            case .file(let url, let remoteFileName):
                try uploadFile(url: url, remoteFileName: remoteFileName, progress: progress, progressHandler: progressHandler)
            case .data(let data, let remoteFileName):
                try uploadData(data, remoteFileName: remoteFileName, progress: progress, progressHandler: progressHandler)
            }
        }
    }

    func verifyConnection() throws {
        try connect()
        disconnect()
    }

    func cancel() {
        isCancelled = true
        disconnect()
    }

    private func connect() throws {
        try openStreams(host: credentials.host, port: credentials.port, useTLSImmediately: false)
        _ = try readResponse()

        try sendCommand("AUTH TLS")
        let authResponse = try readResponse()
        guard authResponse.starts(with: "234") else {
            throw FTPError.connectionFailed("Server did not accept AUTH TLS: \(authResponse)")
        }
        try startTLS()

        try sendCommand("USER \(credentials.username)")
        let userResponse = try readResponse()
        guard userResponse.starts(with: "331") || userResponse.starts(with: "230") else {
            throw FTPError.authenticationFailed("Username not accepted: \(userResponse)")
        }

        if userResponse.starts(with: "331") {
            try sendCommand("PASS \(credentials.password)")
            let passResponse = try readResponse()
            guard passResponse.starts(with: "230") else {
                throw FTPError.authenticationFailed("Password not accepted: \(passResponse)")
            }
        }

        try sendCommand("PBSZ 0")
        let pbszResponse = try readResponse()
        guard pbszResponse.starts(with: "200") else {
            throw FTPError.other("Failed to set FTPS protection buffer size: \(pbszResponse)")
        }

        try sendCommand("PROT P")
        let protResponse = try readResponse()
        guard protResponse.starts(with: "200") else {
            throw FTPError.other("Failed to enable protected FTPS data channel: \(protResponse)")
        }

        try sendCommand("TYPE I")
        let typeResponse = try readResponse()
        guard typeResponse.starts(with: "200") else {
            throw FTPError.other("Failed to switch FTP transfer mode to binary: \(typeResponse)")
        }

        if !remotePath.isEmpty {
            try sendCommand("CWD \(remotePath)")
            let cwdResponse = try readResponse()
            guard cwdResponse.starts(with: "250") else {
                throw FTPError.other("Failed to change to remote directory: \(cwdResponse)")
            }
        }
    }

    private func openStreams(host: String, port: UInt16, useTLSImmediately: Bool) throws {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocketToHost(nil, host as CFString, UInt32(port), &readStream, &writeStream)

        guard let readStream, let writeStream else {
            throw FTPError.connectionFailed("Failed to create streams to \(host):\(port)")
        }

        let input = readStream.takeRetainedValue() as InputStream
        let output = writeStream.takeRetainedValue() as OutputStream
        inputStream = input
        outputStream = output

        if useTLSImmediately {
            try configureTLS(input: input, output: output)
        }

        input.open()
        output.open()
        guard input.streamStatus != .error, output.streamStatus != .error else {
            throw FTPError.connectionFailed("Failed to open streams to \(host):\(port)")
        }
    }

    private func startTLS() throws {
        guard let inputStream, let outputStream else {
            throw FTPError.connectionFailed("No stream available for TLS upgrade.")
        }

        try configureTLS(input: inputStream, output: outputStream)
        waitForStreamHandshake(inputStream)
        waitForStreamHandshake(outputStream)
    }

    private func configureTLS(input: InputStream, output: OutputStream) throws {
        let sslSettings: [String: Any] = [
            kCFStreamSSLPeerName as String: credentials.host,
            kCFStreamSSLValidatesCertificateChain as String: (credentials.allowsUntrustedTLSCertificate ? kCFBooleanFalse : kCFBooleanTrue) as Any
        ]

        guard input.setProperty(sslSettings, forKey: Stream.PropertyKey(kCFStreamPropertySSLSettings as String)),
              output.setProperty(sslSettings, forKey: Stream.PropertyKey(kCFStreamPropertySSLSettings as String)) else {
            throw FTPError.connectionFailed("Failed to configure TLS settings.")
        }
    }

    private func waitForStreamHandshake(_ stream: Stream) {
        let deadline = Date().addingTimeInterval(10)
        while stream.streamStatus == .opening && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }

    private func uploadFile(
        url: URL,
        remoteFileName: String,
        progress: Progress,
        progressHandler: @escaping (Progress) -> Void
    ) throws {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }

        let dataStream = try openDataStream()
        defer { closeStreams(input: dataStream.input, output: dataStream.output) }

        try sendCommand("STOR \(remoteFileName)")
        let storResponse = try readResponse()
        guard storResponse.starts(with: "150") || storResponse.starts(with: "125") else {
            throw FTPError.transferFailed("Failed to initiate file transfer: \(storResponse)")
        }

        while true {
            if isCancelled {
                throw FTPError.cancelled
            }

            let data = try fileHandle.read(upToCount: bufferSize)
            guard let data, !data.isEmpty else {
                break
            }

            try write(data, to: dataStream.output)
            progress.completedUnitCount += Int64(data.count)
            progressHandler(progress)
        }

        closeStreams(input: dataStream.input, output: dataStream.output)
        let transferResponse = try readResponse()
        guard transferResponse.starts(with: "226") else {
            throw FTPError.transferFailed("File transfer failed: \(transferResponse)")
        }
    }

    private func uploadData(
        _ data: Data,
        remoteFileName: String,
        progress: Progress,
        progressHandler: @escaping (Progress) -> Void
    ) throws {
        let dataStream = try openDataStream()
        defer { closeStreams(input: dataStream.input, output: dataStream.output) }

        try sendCommand("STOR \(remoteFileName)")
        let storResponse = try readResponse()
        guard storResponse.starts(with: "150") || storResponse.starts(with: "125") else {
            throw FTPError.transferFailed("Failed to initiate data transfer: \(storResponse)")
        }

        try write(data, to: dataStream.output)
        progress.completedUnitCount += Int64(data.count)
        progressHandler(progress)

        closeStreams(input: dataStream.input, output: dataStream.output)
        let transferResponse = try readResponse()
        guard transferResponse.starts(with: "226") else {
            throw FTPError.transferFailed("Data transfer failed: \(transferResponse)")
        }
    }

    private func openDataStream() throws -> (input: InputStream, output: OutputStream) {
        let endpoint = try passiveEndpoint()
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocketToHost(nil, endpoint.host as CFString, UInt32(endpoint.port), &readStream, &writeStream)

        guard let readStream, let writeStream else {
            throw FTPError.connectionFailed("Failed to create FTPS data stream.")
        }

        let input = readStream.takeRetainedValue() as InputStream
        let output = writeStream.takeRetainedValue() as OutputStream
        try configureTLS(input: input, output: output)

        input.open()
        output.open()
        guard input.streamStatus != .error, output.streamStatus != .error else {
            throw FTPError.connectionFailed("Failed to open FTPS data stream.")
        }

        waitForStreamHandshake(input)
        waitForStreamHandshake(output)
        return (input, output)
    }

    private func passiveEndpoint() throws -> (host: String, port: UInt16) {
        try sendCommand("EPSV")
        let epsvResponse = try readResponse()
        if epsvResponse.starts(with: "229"), let port = parseEPSVPort(from: epsvResponse) {
            return (credentials.host, port)
        }

        try sendCommand("PASV")
        let pasvResponse = try readResponse()
        guard pasvResponse.starts(with: "227") else {
            throw FTPError.other("Failed to enter passive mode. EPSV: \(epsvResponse) PASV: \(pasvResponse)")
        }
        return try parsePASVEndpoint(from: pasvResponse)
    }

    private func parseEPSVPort(from response: String) -> UInt16? {
        let pattern = #"\(\|\|\|(\d+)\|\)"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
            let range = Range(match.range(at: 1), in: response),
            let port = UInt16(response[range])
        else {
            return nil
        }
        return port
    }

    private func parsePASVEndpoint(from response: String) throws -> (host: String, port: UInt16) {
        let pattern = "\\((.*?)\\)"
        let regex = try NSRegularExpression(pattern: pattern)
        guard let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
              let range = Range(match.range(at: 1), in: response) else {
            throw FTPError.other("Failed to parse PASV response: \(response)")
        }

        let numbers = response[range]
            .split(separator: ",")
            .compactMap { UInt16($0.trimmingCharacters(in: .whitespaces)) }
        guard numbers.count == 6 else {
            throw FTPError.other("Invalid PASV response format: \(response)")
        }

        let host = "\(numbers[0]).\(numbers[1]).\(numbers[2]).\(numbers[3])"
        let port = (numbers[4] << 8) + numbers[5]
        return (host, port)
    }

    private func sendCommand(_ command: String) throws {
        try write(Data((command + "\r\n").utf8), to: requiredOutputStream())
    }

    private func readResponse() throws -> String {
        let input = try requiredInputStream()
        var response = ""
        var buffer = [UInt8](repeating: 0, count: 1024)

        repeat {
            let count = input.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                response += String(decoding: buffer.prefix(count), as: UTF8.self)
            } else if count < 0 {
                throw FTPError.connectionFailed(input.streamError?.localizedDescription ?? "Failed to read FTP response.")
            } else {
                throw FTPError.connectionFailed("Connection closed while reading FTP response.")
            }
        } while !isCompleteFTPResponse(response)

        return response
    }

    private func isCompleteFTPResponse(_ response: String) -> Bool {
        let lines = response
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let firstLine = lines.first, firstLine.count >= 3 else {
            return false
        }

        let code = String(firstLine.prefix(3))
        if firstLine.dropFirst(3).first == "-" {
            return lines.contains { $0.hasPrefix(code + " ") }
        }
        return response.hasSuffix("\r\n")
    }

    private func write(_ data: Data, to output: OutputStream) throws {
        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return
            }

            var bytesSent = 0
            while bytesSent < data.count {
                let sent = output.write(baseAddress.advanced(by: bytesSent), maxLength: data.count - bytesSent)
                if sent > 0 {
                    bytesSent += sent
                } else if sent < 0 {
                    throw FTPError.transferFailed(output.streamError?.localizedDescription ?? "Failed to write FTP data.")
                } else {
                    throw FTPError.transferFailed("FTP stream stopped accepting data.")
                }
            }
        }
    }

    private func requiredInputStream() throws -> InputStream {
        guard let inputStream else {
            throw FTPError.connectionFailed("No input stream available.")
        }
        return inputStream
    }

    private func requiredOutputStream() throws -> OutputStream {
        guard let outputStream else {
            throw FTPError.connectionFailed("No output stream available.")
        }
        return outputStream
    }

    private func disconnect() {
        closeStreams(input: inputStream, output: outputStream)
        inputStream = nil
        outputStream = nil
    }

    private func closeStreams(input: InputStream?, output: OutputStream?) {
        input?.close()
        output?.close()
    }
}

/// A client for interacting with FTP servers.
///
/// This class provides functionality to connect to an FTP server, upload files or data,
/// and manage the transfer process.
///
/// Example usage:
/// ```swift
/// let credentials = FTPCredentials(host: "ftp.example.com", port: 21, username: "user", password: "pass")
/// let remotePath = "/upload/path"
///
/// let ftpClient = FTPClient(credentials: credentials, remotePath: remotePath)
///
/// let filesToUpload: [FTPUploadable] = [
///     .file(url: URL(fileURLWithPath: "/path/to/local/file1.txt"), remoteFileName: "file1.txt"),
///     .data(data: Data("Sample data".utf8), remoteFileName: "sample.txt")
/// ]
///
/// ftpClient.upload(files: filesToUpload, progressHandler: { progress in
///     print("Overall progress: \(progress.fractionCompleted * 100)%")
/// }, completionHandler: { result in
///     switch result {
///     case .success:
///         print("All files uploaded successfully.")
///     case .failure(let error):
///         print("An error occurred: \(error)")
///     }
/// })
/// ```

@MainActor
public class FTPClient {
    private let credentials: FTPCredentials
    private let remotePath: String
    private var controlConnection: NWConnection?
    private var explicitFTPSession: FTPStreamSession?
    private var isCancelled = false
    private var progress: Progress?
    private let bufferSize: Int

    /// Initializes a new FTP client.
    /// - Parameters:
    ///   - credentials: The credentials for connecting to the FTP server.
    ///   - remotePath: The remote path on the server where files will be uploaded.
    public init(credentials: FTPCredentials, remotePath: String, progress: Progress? = nil, bufferSize: Int = 512 * 1024) {
        self.credentials = credentials
        self.remotePath = remotePath
        self.progress = progress
        self.bufferSize = bufferSize
    }

    // MARK: - Public Methods

    /// Uploads multiple files to the FTP server.
    /// - Parameters:
    ///   - files: An array of `FTPUploadable` items to be uploaded.
    ///   - progressHandler: A closure that is called with updates on the overall progress of the upload.
    ///   - completionHandler: A closure that is called when all uploads are complete, or if an error occurs.
    public func upload(
        files: [FTPUploadable],
        progressHandler: @escaping (Progress) -> Void,
        completionHandler: @escaping (Result<Void, FTPError>) -> Void
    ) {
        Task {
            do {
                try await upload(files: files, progressHandler: progressHandler)
                completionHandler(.success(()))
            } catch let error as FTPError {
                completionHandler(.failure(error))
            } catch {
                completionHandler(.failure(FTPError.other(error.localizedDescription)))
            }
        }
    }

    /// Cancels any ongoing transfer operations.
    public func cancel() {
        isCancelled = true
        controlConnection?.cancel()
        explicitFTPSession?.cancel()
    }

    // MARK: - Private Methods

    public func upload(
        files: [FTPUploadable],
        progressHandler: @escaping (Progress) -> Void
    ) async throws {
        if credentials.security == .explicitTLS {
            try await uploadWithExplicitTLS(files: files, progressHandler: progressHandler)
            return
        }

        // Connect and authenticate
        try await connect()

        // Calculate total size for Progress
        let totalSize = try files.reduce(0) { (result, uploadable) -> Int64 in
            switch uploadable {
            case .file(let url, _):
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                return result + (attributes[.size] as? Int64 ?? 0)
            case .data(let data, _):
                return result + Int64(data.count)
            }
        }

        let progress = self.progress ?? Progress(totalUnitCount: totalSize)
        progressHandler(progress)

        for uploadable in files {
            if isCancelled {
                throw FTPError.cancelled
            }

            switch uploadable {
            case .file(let url, let remoteFileName):
                try await uploadFile(url: url, remoteFileName: remoteFileName, progress: progress, progressHandler: progressHandler)
            case .data(let data, let remoteFileName):
                try await uploadData(data: data, remoteFileName: remoteFileName, progress: progress, progressHandler: progressHandler)
            }
        }

        // Close control connection
        controlConnection?.cancel()
    }

    private func uploadWithExplicitTLS(
        files: [FTPUploadable],
        progressHandler: @escaping (Progress) -> Void
    ) async throws {
        let totalSize = try files.reduce(0) { (result, uploadable) -> Int64 in
            switch uploadable {
            case .file(let url, _):
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                return result + (attributes[.size] as? Int64 ?? 0)
            case .data(let data, _):
                return result + Int64(data.count)
            }
        }

        let progress = self.progress ?? Progress(totalUnitCount: totalSize)
        progressHandler(progress)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let session = FTPStreamSession(credentials: credentials, remotePath: remotePath, bufferSize: bufferSize)
            explicitFTPSession = session

            DispatchQueue.global(qos: .utility).async {
                do {
                    try session.upload(files: files, progress: progress) { _ in }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        progressHandler(progress)
        explicitFTPSession = nil
    }

    private func connect() async throws {
        let endpoint = NWEndpoint.Host(credentials.host)
        let port = try ftpPort(credentials.port)
        controlConnection = NWConnection(
            host: endpoint,
            port: port,
            using: connectionParameters(usesTLS: credentials.security == .implicitTLS)
        )

        try await waitUntilReady(controlConnection, context: "control connection")

        _ = try await readResponse()

        try await sendCommand("USER \(credentials.username)")
        let userResponse = try await readResponse()
        guard userResponse.starts(with: "331") || userResponse.starts(with: "230") else {
            throw FTPError.authenticationFailed("Username not accepted: \(userResponse)")
        }

        if userResponse.starts(with: "331") {
            try await sendCommand("PASS \(credentials.password)")
            let passResponse = try await readResponse()
            guard passResponse.starts(with: "230") else {
                throw FTPError.authenticationFailed("Password not accepted: \(passResponse)")
            }
        }

        try await configureTransferMode()

        if !remotePath.isEmpty {
            try await sendCommand("CWD \(remotePath)")
            let cwdResponse = try await readResponse()
            guard cwdResponse.starts(with: "250") else {
                throw FTPError.other("Failed to change to remote directory: \(cwdResponse)")
            }
        }
    }

    private func connectionParameters(usesTLS: Bool) -> NWParameters {
        guard usesTLS else {
            return .tcp
        }

        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, credentials.host)
        return NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
    }

    private func ftpPort(_ rawValue: UInt16) throws -> NWEndpoint.Port {
        guard let port = NWEndpoint.Port(rawValue: rawValue) else {
            throw FTPError.connectionFailed("Invalid FTP port: \(rawValue)")
        }
        return port
    }

    private func waitUntilReady(_ connection: NWConnection?, context: String) async throws {
        guard let connection else {
            throw FTPError.connectionFailed("No \(context) available.")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let continuationBox = FTPContinuationBox()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuationBox.resumeOnce {
                        continuation.resume()
                    }
                case .failed(let error):
                    continuationBox.resumeOnce {
                        continuation.resume(throwing: FTPError.connectionFailed("\(context): \(error.localizedDescription)"))
                    }
                case .cancelled:
                    continuationBox.resumeOnce {
                        continuation.resume(throwing: FTPError.cancelled)
                    }
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }
    }

    private func configureTransferMode() async throws {
        if credentials.security == .implicitTLS {
            try await sendCommand("PBSZ 0")
            let pbszResponse = try await readResponse()
            guard pbszResponse.starts(with: "200") else {
                throw FTPError.other("Failed to set FTPS protection buffer size: \(pbszResponse)")
            }

            try await sendCommand("PROT P")
            let protResponse = try await readResponse()
            guard protResponse.starts(with: "200") else {
                throw FTPError.other("Failed to enable protected FTPS data channel: \(protResponse)")
            }
        }

        try await sendCommand("TYPE I")
        let typeResponse = try await readResponse()
        guard typeResponse.starts(with: "200") else {
            throw FTPError.other("Failed to switch FTP transfer mode to binary: \(typeResponse)")
        }
    }

    private func sendCommand(_ command: String) async throws {
        guard let connection = controlConnection else {
            throw FTPError.connectionFailed("No control connection available.")
        }
        let commandWithCRLF = command + "\r\n"
        guard let data = commandWithCRLF.data(using: .utf8) else {
            throw FTPError.other("Failed to encode command.")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed({ error in
                if let error = error {
                    continuation.resume(throwing: FTPError.connectionFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }))
        }
    }

    private func readResponse() async throws -> String {
        guard let connection = controlConnection else {
            throw FTPError.connectionFailed("No control connection available.")
        }

        var completeResponse = ""
        while true {
            let partialResponse: String = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, isComplete, error in
                    if let error = error {
                        continuation.resume(throwing: FTPError.connectionFailed(error.localizedDescription))
                    } else if let data = data, let response = String(data: data, encoding: .utf8) {
                        continuation.resume(returning: response)
                    } else if isComplete {
                        continuation.resume(throwing: FTPError.other("Connection closed while reading response."))
                    } else {
                        continuation.resume(throwing: FTPError.other("Failed to read response from server."))
                    }
                }
            }
            completeResponse += partialResponse
            // Check if response is complete (ends with \r\n)
            if completeResponse.hasSuffix("\r\n") {
                break
            }
        }
        return completeResponse
    }

    private func uploadFile(
        url: URL,
        remoteFileName: String,
        progress: Progress,
        progressHandler: @escaping (Progress) -> Void
    ) async throws {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer {
            try? fileHandle.close()
        }

        // Enter passive mode
        let dataConnection = try await enterPassiveModeAndOpenDataConnection()

        // Send STOR command
        try await sendCommand("STOR \(remoteFileName)")
        let storResponse = try await readResponse()
        guard storResponse.starts(with: "150") else {
            throw FTPError.transferFailed("Failed to initiate file transfer: \(storResponse)")
        }

        // Send file data
        while true {
            if isCancelled {
                dataConnection.cancel()
                throw FTPError.cancelled
            }

            if #available(macOS 10.15.4, *) {
                let data = try fileHandle.read(upToCount: bufferSize)
                if let data = data, !data.isEmpty {
                    try await sendData(data: data, over: dataConnection)
                    progress.completedUnitCount += Int64(data.count)
                    progressHandler(progress)
                } else {
                    break
                }
            } else {
                fatalError("SwiftFTPClient requires macOS 10.15.4 or later.")
            }
        }

        // Close data connection
        dataConnection.cancel()

        // Read server response
        let transferResponse = try await readResponse()
        guard transferResponse.starts(with: "226") else {
            throw FTPError.transferFailed("File transfer failed: \(transferResponse)")
        }
    }

    private func uploadData(
        data: Data,
        remoteFileName: String,
        progress: Progress,
        progressHandler: @escaping (Progress) -> Void
    ) async throws {
        // Enter passive mode
        let dataConnection = try await enterPassiveModeAndOpenDataConnection()

        // Send STOR command
        try await sendCommand("STOR \(remoteFileName)")
        let storResponse = try await readResponse()
        guard storResponse.starts(with: "150") else {
            throw FTPError.transferFailed("Failed to initiate data transfer: \(storResponse)")
        }

        // Send data
        try await sendData(data: data, over: dataConnection)
        progress.completedUnitCount += Int64(data.count)
        progressHandler(progress)

        // Close data connection
        dataConnection.cancel()

        // Read server response
        let transferResponse = try await readResponse()
        guard transferResponse.starts(with: "226") else {
            throw FTPError.transferFailed("Data transfer failed: \(transferResponse)")
        }
    }

    private func enterPassiveModeAndOpenDataConnection() async throws -> NWConnection {
        let passiveEndpoint = try await passiveEndpoint()
        let dataConnection = NWConnection(
            host: NWEndpoint.Host(passiveEndpoint.host),
            port: try ftpPort(passiveEndpoint.port),
            using: connectionParameters(usesTLS: credentials.security == .implicitTLS)
        )

        try await waitUntilReady(dataConnection, context: "data connection")
        return dataConnection
    }

    private func passiveEndpoint() async throws -> (host: String, port: UInt16) {
        try await sendCommand("EPSV")
        let epsvResponse = try await readResponse()
        if epsvResponse.starts(with: "229"), let port = parseEPSVPort(from: epsvResponse) {
            return (credentials.host, port)
        }

        try await sendCommand("PASV")
        let pasvResponse = try await readResponse()
        guard pasvResponse.starts(with: "227") else {
            throw FTPError.other("Failed to enter passive mode. EPSV: \(epsvResponse) PASV: \(pasvResponse)")
        }
        return try parsePASVEndpoint(from: pasvResponse)
    }

    private func parseEPSVPort(from response: String) -> UInt16? {
        let pattern = #"\(\|\|\|(\d+)\|\)"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
            let range = Range(match.range(at: 1), in: response),
            let port = UInt16(response[range])
        else {
            return nil
        }
        return port
    }

    private func parsePASVEndpoint(from response: String) throws -> (host: String, port: UInt16) {
        let pattern = "\\((.*?)\\)"
        let regex = try NSRegularExpression(pattern: pattern)
        guard let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)) else {
            throw FTPError.other("Failed to parse PASV response: \(response)")
        }
        guard let range = Range(match.range(at: 1), in: response) else {
            throw FTPError.other("Invalid PASV response range: \(response)")
        }

        let numbers = response[range]
            .split(separator: ",")
            .compactMap { UInt16($0.trimmingCharacters(in: .whitespaces)) }
        guard numbers.count == 6 else {
            throw FTPError.other("Invalid PASV response format: \(response)")
        }

        let host = "\(numbers[0]).\(numbers[1]).\(numbers[2]).\(numbers[3])"
        let port = (numbers[4] << 8) + numbers[5]
        return (host, port)
    }

    private func sendData(data: Data, over connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed({ error in
                if let error = error {
                    continuation.resume(throwing: FTPError.transferFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }))
        }
    }

    /// Verifies the connection to the FTP server.
    /// This method attempts to connect to the server, authenticate, and then disconnect.
    /// - Returns: A boolean indicating whether the connection was successful.
    /// - Throws: An `FTPError` if the connection or authentication fails.
    public func verifyConnection() async throws -> Bool {
        do {
            if credentials.security == .explicitTLS {
                try await verifyExplicitTLSConnection()
            } else {
                try await connect()
                await disconnect()
            }
            return true
        } catch {
            throw error
        }
    }

    private func verifyExplicitTLSConnection() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let session = FTPStreamSession(credentials: credentials, remotePath: remotePath, bufferSize: bufferSize)
            explicitFTPSession = session

            DispatchQueue.global(qos: .utility).async {
                do {
                    try session.verifyConnection()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        explicitFTPSession = nil
    }

    private func disconnect() async {
        controlConnection?.cancel()
        controlConnection = nil
    }
}
