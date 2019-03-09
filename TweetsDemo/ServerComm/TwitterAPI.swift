//
//  TwitterAPI.swift
//  TweetsDemo
//
//  Created by Ying Zhang on 3/7/19.
//  Copyright © 2019 Ying Zhang. All rights reserved.
//

import UIKit

public enum HTTPMethod: String {
	case get     = "GET"
	case post    = "POST"
	//...
}

class TwitterAPI: NSObject {
	// Auth
	var baseURL: URL = URL(string: "https://api.twitter.com/")!
	var path: String
	var method: HTTPMethod
	var parameters: [String: Any]?
	var headers: [String: String]
	static var bearer: String = ""
	static var since_id: String? = nil
	
	init(baseURL: String? = nil,
		 path: String,
		 method: HTTPMethod = .get,
		 params: [String: Any]? = nil,
		 headers: [String: String] = [:]) {
		if let base = baseURL {
			self.baseURL = URL(string: base)!
		}
		self.path = path
		self.method = method
		self.parameters = params
		self.headers = headers

		super.init()
	}
	
	override private init(){
		self.path = ""
		self.method = .get
		self.parameters = nil
		self.headers = [:]
		super.init()
	}
	
	static func request(_ wsCallDef: TwitterAPI) -> (result: Any?, error: Error?) {
		var urlPath: String = "\(wsCallDef.baseURL)\(wsCallDef.path)"
		let verb: String = wsCallDef.method.rawValue
		var paramData: Data? = nil
		if HTTPMethod.get == wsCallDef.method  {
			if let url = URL(string: urlPath), var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
				let percentEncodedQuery = (wsCallDef.parameters?.count ?? 0) > 0 ? (urlComponents.percentEncodedQuery.map { $0 + "&" } ?? "") + ServerCommManager.query(wsCallDef.parameters!) : urlComponents.percentEncodedQuery
				urlComponents.percentEncodedQuery = percentEncodedQuery
				urlPath = urlComponents.url?.absoluteString ?? ""
				
			}
		} else {
			if let url = URL(string: urlPath), let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
				urlPath = urlComponents.url?.absoluteString ?? ""
			}
			if let params = wsCallDef.parameters, params.count > 0 {
				if wsCallDef.headers["Content-Type"] != "application/json" {
					let parameterArray = params.map { (key, value) -> String in
						let escapedKey = key.addingPercentEncoding(withAllowedCharacters:.urlQueryAllowed) ?? ""
						let newValue = String(describing: value)
						let escapedValue = newValue.addingPercentEncoding(withAllowedCharacters:.urlQueryAllowed) ?? ""
						return "\(escapedKey)=\(escapedValue)"
					}
					paramData = parameterArray.joined(separator: "&").data(using:String.Encoding.ascii, allowLossyConversion: false)
				} else {
					paramData = try? JSONSerialization.data(withJSONObject: params as Any, options: [])
				}
			}
		}
		
		var headers : [String : String] = wsCallDef.headers
		
		if TwitterAPI.bearer.count > 0 {
			headers["Authorization"] = "Bearer \(TwitterAPI.bearer)"
		}
	
		let ret = ServerCommManager().requestSync(urlPath: urlPath, verb: verb, headers: headers, paramData:paramData)
		
		return ret
	}
	
	
	@discardableResult
	static func getToken() -> (token: String?, error: Error?) {
		let wsCallDef = TwitterAPI(path: "oauth2/token",
							 method: .post,
							 params: ["grant_type": "client_credentials"],
							 headers:["Content-Type": "application/x-www-form-urlencoded",
									  "Authorization": "Basic SFppa2hFbmJKSDRtOGRXY2lBRjZxSFB3TTpDRExHeTRXVzNlbVRDZmtJT3BzdXBVR2Q4OHN3Q2VtdGFMc2ZUVFNoRHlqcDloWFZuNQ=="])
		let ret = request(wsCallDef)
		if let json = ret.result as? [String : Any], let bearer = json["access_token"] as? String {
			TwitterAPI.bearer = bearer
			return (bearer, ret.error)
		}
		return (nil, ret.error)
	}
	
	static func searchNearBy(geoLocation: String) -> (result:[TweetPost], error: Error?) {
		let radius:Int = MapRegionRadius/1000
		let wsCallDef = TwitterAPI(path: "1.1/search/tweets.json",
								   method: .get,
								   params: ["q":"", "geocode": "\(geoLocation),\(radius)km", "include_entities":"true", "count":"100", "since_id":"\(since_id ?? "")"])
		let ret = request(wsCallDef)
		if let json = ret.result as? [String : Any], let statuses = json["statuses"] as? [Any] {
			let tweets = statuses.map { (json) -> TweetPost? in
				return TweetPost(json: json)
				}.compactMap({$0})
			if let metaData = json["search_metadata"] as? [String:Any], let max_id = metaData["max_id_str"] as? String {
				TwitterAPI.since_id = max_id
			}
			return (tweets, nil)
		}
		return ([TweetPost](), ret.error)
	}
	
	static func getEmbeddedHtmlString(id_str: String) -> (result: String?, error: Error?) {
		let wsCallDef = TwitterAPI(baseURL: "https://publish.twitter.com/",
								   path: "oembed",
								   method: .get,
								   params: ["url":"https://twitter.com/Interior/status/\(id_str)", "partner": "", "hide_thread":"false"])
		let ret = request(wsCallDef)
		if let json = ret.result as? [String : Any], let html = json["html"] as? String {
			return (html, nil)
		}
		return (nil, ret.error)
	}
}
