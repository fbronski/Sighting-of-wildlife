//
//  FTPCredentials.swift
//
//
//  Created by Alexander Ruiz Ponce on 14/09/24.
//

import Foundation

/// Defines how the FTP control and data connections are secured.
public enum FTPConnectionSecurity: Sendable {
    /// Plain FTP without transport encryption.
    case none
    /// FTP upgraded to TLS after AUTH TLS, commonly used on port 21.
    case explicitTLS
    /// FTP over TLS from the first byte, commonly used on port 990.
    case implicitTLS
}

/// Represents the credentials needed to connect to an FTP server.
public struct FTPCredentials: Sendable {
    /// The hostname or IP address of the FTP server.
    let host: String
    /// The port number of the FTP server.
    let port: UInt16
    /// The username for authentication.
    let username: String
    /// The password for authentication.
    let password: String
    /// The transport security mode used for control and data connections.
    let security: FTPConnectionSecurity
    /// Allows connecting to FTPS servers with self-signed or otherwise untrusted certificates.
    let allowsUntrustedTLSCertificate: Bool
    
    public init(
        host: String,
        port: UInt16,
        username: String,
        password: String,
        security: FTPConnectionSecurity = .none,
        allowsUntrustedTLSCertificate: Bool = false
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.security = security
        self.allowsUntrustedTLSCertificate = allowsUntrustedTLSCertificate
    }
}
