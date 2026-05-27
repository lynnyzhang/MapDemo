//
//  APIError.swift
//  MapDemo
//
//  Created by Ying Zhang on 2026-05-26.
//  Copyright © 2026 Ying Zhang. All rights reserved.
//

import Foundation

enum APIError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingFailed(Error)
    case networkError(Error)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .invalidResponse:
            return "Invalid server response."
        case .httpError(let code, let message):
            if let message {
                return "HTTP \(code): \(message)"
            }
            return "HTTP error \(code)."
        case .decodingFailed(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .emptyResponse:
            return "Server returned empty response."
        }
    }
}
