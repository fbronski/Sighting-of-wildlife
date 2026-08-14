//
//  FTPError.swift
//  
//
//  Created by Alexander Ruiz Ponce on 14/09/24.
//

import Foundation

/// Represents errors that can occur during FTP operations.
public enum FTPError: Error, Sendable {
    case connectionFailed(String)
    case authenticationFailed(String)
    case transferFailed(String)
    case cancelled
    case other(String)
}
