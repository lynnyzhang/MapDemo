//
//  ServerCommManager.swift
//  TweetsDemo
//
//  Created by Ying Zhang on 3/7/19.
//  Copyright © 2019 Ying Zhang. All rights reserved.
//

import UIKit

enum ServerCommError: Int {
	case invalid_json = -101
	case response_empty = -103
	case invalid_response = -106
	
	var message: String {
		switch self {
		case .invalid_json: return "Server response is not a valid json string."
		case .response_empty: return "Server response is empty."
		case .invalid_response: return "Invalid response."
		}
	}
}
private let SESSION_TIMEOUT_TIME: TimeInterval = 60

private var _session: URLSession?

class ServerCommManager: NSObject, URLSessionDelegate {
	private let requestSemaphore = DispatchSemaphore(value: 0)
	private var domain : String {
		return "www.lynx-tweetdem0.com"
	}
	
	func getSession() -> URLSession {
		if _session == nil {
			let sessionConfig = URLSessionConfiguration.default
			// 1
			sessionConfig.allowsCellularAccess = true
			sessionConfig.timeoutIntervalForRequest = SESSION_TIMEOUT_TIME
			sessionConfig.timeoutIntervalForResource = SESSION_TIMEOUT_TIME
			sessionConfig.httpMaximumConnectionsPerHost = 1
			_session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
		}
		return _session!
	}
	
	func sendRequestGeneric(urlPath: String,
							verb: String,
							headers: [String: String],
							paramData: Data?,
							onComplete completionHandler: @escaping (_ response:Any?) -> Void) {
		if let urlString = urlPath.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed), let url = URL(string: urlString) {
			let request = NSMutableURLRequest(url: url)
			request.httpMethod = verb
			
			for key: String in headers.keys {
				request.setValue(headers[key], forHTTPHeaderField: key)
			}
			let originCompletionHandler = { (data: Data?, response: URLResponse?, error: Error?) -> Void in
				var retError: NSError? = nil
				var result: Any? = nil
				if let error = error {
					retError = error as NSError
				}
				else {
					let httpResp = response as? HTTPURLResponse
					if let code = httpResp?.statusCode, (code < 200 || code >= 300) {
						retError = NSError(domain: self.domain, code: code, userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: code)])
					}
					if let data = data, data.count > 0 {
						do {
							let jsonDictionary = try JSONSerialization.jsonObject(with: data) as? [String : Any]
							result = jsonDictionary
						} catch {
							retError = NSError(domain: self.domain, code: ServerCommError.invalid_json.rawValue, userInfo: [NSLocalizedDescriptionKey:ServerCommError.invalid_json.message])
						}
					}
				}
				if let e = retError {
					completionHandler(e as Error)
				} else {
					completionHandler(result)
				}
			}
			
			if let paramData = paramData {
				let upTask: URLSessionUploadTask? = getSession().uploadTask(with: request as URLRequest, from: paramData, completionHandler: originCompletionHandler)
				upTask?.resume()
			}
			else {
				let dataTask: URLSessionDataTask? = getSession().dataTask(with: request as URLRequest, completionHandler: originCompletionHandler)
				dataTask?.resume()
			}
		}
	}
	
	func requestSync(urlPath: String, verb: String, headers:[String: String], paramData: Data?) -> (result:Any?, error: Error?) {
		let retResult: Any? = nil
		let retError: Error? = nil
		var completeResult = (result: retResult, error: retError)
		
		let successHandler : (_ result: Any?, _ error: Error?) -> Void = { [weak self] (result, error) in
			guard let self = self else { return }
			completeResult.result = result
			completeResult.error = error
			self.requestSemaphore.signal()
		}
		
		let failHandler : (_ error: Error) -> Void = { [weak self] (error) in
			guard let self = self else { return }
			completeResult.error = error
			self.requestSemaphore.signal()
		}
		
		sendRequest(urlPath: urlPath, verb: verb, headers: headers, paramData: paramData, onSuccess: successHandler, onFail: failHandler)
		
		_ = requestSemaphore.wait(timeout: .distantFuture)
	
		return completeResult
	}
	
	private func sendRequest(urlPath: String,
							 verb: String,
							 headers: [String: String],
							 paramData: Data?,
							 onSuccess completionHandlerSuccess: @escaping (_: Any?, _: Error?) -> Void,
							 onFail completionHandlerFail: @escaping (_: Error) -> Void) {
		if let urlString = urlPath.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed), let url = URL(string: urlString) {
			let request = NSMutableURLRequest(url: url)
			request.httpMethod = verb

			for key: String in headers.keys {
				request.setValue(headers[key], forHTTPHeaderField: key)
			}
			debugPrint("====Server Communication====: HTTP REQUEST: \(urlPath)")
			if let paramData = paramData {
				debugPrint("====Server Communication====: PARAM DATA: \(String(data: paramData, encoding: .utf8) ?? "")")
			}
			let completionHandler = { [weak self] (data: Data?, response: URLResponse?, error: Error?) -> Void in
				guard let self = self else { return }
				var retError: NSError? = nil
				var result: Any? = nil
				if let error = error {
					retError = error as NSError
				}
				else {
					let httpResp = response as? HTTPURLResponse
					if let code = httpResp?.statusCode, (code < 200 || code >= 300) {
						debugPrint("====Server Communication====: HTTP STATUS ERROR: (\(code)) \(HTTPURLResponse.localizedString(forStatusCode: code))")
						retError = NSError(domain: self.domain, code: code, userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: code)])
					}
					if let data = data, data.count > 0 {
						do {
							let resString = String(data: data, encoding: .utf8) ?? ""
							debugPrint("====Server Communication====: HTTP RESPONSE: \(resString)")
							result = try JSONSerialization.jsonObject(with: data)
						} catch {
							retError = NSError(domain: self.domain, code: ServerCommError.invalid_json.rawValue, userInfo: [NSLocalizedDescriptionKey:ServerCommError.invalid_json.message])
						}
					}
				}
				if let e = retError {
					completionHandlerFail(e as Error)
				} else {
					completionHandlerSuccess(result, retError)
				}
			}
			if let paramData = paramData {
				let upTask: URLSessionUploadTask? = getSession().uploadTask(with: request as URLRequest, from: paramData, completionHandler: completionHandler)
				upTask?.resume()
			}
			else {
				let dataTask: URLSessionDataTask? = getSession().dataTask(with: request as URLRequest, completionHandler: completionHandler)
				dataTask?.resume()
			}
		}
	}
	
	
	static func query(_ parameters: [String: Any]) -> String {
		var components: [(String, String)] = []
		
		for key in parameters.keys.sorted(by: <) {
			let value = parameters[key]!
			components += queryComponents(fromKey: key, value: value)
		}
		return components.map { "\($0)=\($1)" }.joined(separator: "&")
		
	}

	private static func queryComponents(fromKey key: String, value: Any) -> [(String, String)] {
		var components: [(String, String)] = []
		
		if let dictionary = value as? [String: Any] {
			for (nestedKey, value) in dictionary {
				components += queryComponents(fromKey: "\(key)[\(nestedKey)]", value: value)
			}
		} else if let array = value as? [Any] {
			for value in array {
				components += queryComponents(fromKey: "\(key)[]", value: value)
			}
		} else if let value = value as? NSNumber {
			if CFBooleanGetTypeID() == CFGetTypeID(value) {
				components.append((escape(key), escape((value.boolValue ? "1" : "0"))))
			} else {
				components.append((escape(key), escape("\(value)")))
			}
		} else if let bool = value as? Bool {
			components.append((escape(key), escape((bool ? "1" : "0"))))
		} else {
			components.append((escape(key), escape("\(value)")))
		}
		
		return components
	}
	
	private static func escape(_ string: String) -> String {
		let allowedCharacterSet = CharacterSet.urlQueryAllowed
		let escaped = string.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? string
		return escaped
	}
}


