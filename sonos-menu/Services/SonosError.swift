//
//  SonosError.swift
//  sonos-menu
//

import Foundation

enum SonosError: Error {
    case badURL
    case badResponse
    case httpStatus(code: Int)
    case soapFault(detail: String)
    case parseFailed
}

extension SonosError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid device URL."
        case .badResponse: return "Unexpected response from device."
        case .httpStatus(let code): return "Device returned HTTP \(code)."
        case .soapFault(let detail): return "SOAP fault: \(detail)"
        case .parseFailed: return "Failed to parse device response."
        }
    }
}
