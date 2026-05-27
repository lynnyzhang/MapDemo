//
//  ServerCommManager.swift
//  MapDemo
//
//  Created by Ying Zhang on 2026-05-26.
//  Copyright © 2026 Ying Zhang. All rights reserved.
//

import Foundation

private let session: URLSession = {
    let config = URLSessionConfiguration.default
    config.allowsCellularAccess = true
    config.timeoutIntervalForRequest = 60
    config.timeoutIntervalForResource = 60
    return URLSession(configuration: config)
}()

func sendRequest(urlPath: String,
                 verb: String = "GET",
                 headers: [String: String] = [:],
                 body: Data? = nil) async throws -> Data {
    guard let url = URL(string: urlPath) else {
        throw APIError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = verb
    request.httpBody = body
    for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
    }

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.invalidResponse
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
        let message: String?
        if httpResponse.statusCode == 429,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorObj = json["error"] as? [String: Any],
           let errorMessage = errorObj["message"] as? String {
            message = errorMessage
        } else {
            message = String(data: data, encoding: .utf8)
        }
        throw APIError.httpError(statusCode: httpResponse.statusCode, message: message)
    }

    return data
}
