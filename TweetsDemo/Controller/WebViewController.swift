//
//  WebViewController.swift
//  TweetsDemo
//
//  Created by Ying Zhang on 3/6/19.
//  Copyright © 2019 Ying Zhang. All rights reserved.
//

import UIKit
import WebKit

class WebViewController: UIViewController {
	
	let webView: WKWebView
	var embeddedHtml: String?
	var tweetId: String?
	required init?(coder aDecoder: NSCoder) {
		let webConfiguration = WKWebViewConfiguration()
		webConfiguration.dataDetectorTypes = [.link, .phoneNumber]
		webView = WKWebView(frame: .zero, configuration: webConfiguration)
		super.init(coder: aDecoder)
	}
	
	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		let webConfiguration = WKWebViewConfiguration()
		webConfiguration.dataDetectorTypes = [.link, .phoneNumber]
		webView = WKWebView(frame: .zero, configuration: webConfiguration)
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
	}
	
	convenience init(embedded: String?, tweetId: String?) {
		self.init(nibName: nil, bundle: nil)
		self.embeddedHtml = embedded
		self.tweetId = tweetId
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Retweet", style: .plain, target: self, action: #selector(retweet(_:)))
		setupWebView()
		loadTermsAndConditions()
	}
	@objc func retweet(_ barButtonItem: UIBarButtonItem) {
		
		if let tweetId = self.tweetId, let link = URL(string: "https://twitter.com/intent/retweet?tweet_id=\(tweetId)") {
			UIApplication.shared.open(link)
		}
	}

	func loadTermsAndConditions() {
		let htmlFile = Bundle.main.path(forResource: "template", ofType: "html")
		let fileUrl = URL(fileURLWithPath: htmlFile!, isDirectory: false)
		var contentsOfFile = try! String(contentsOfFile: htmlFile!, encoding: String.Encoding.utf8)
		
		contentsOfFile = contentsOfFile.replacingOccurrences(of: "$EmbededHtml", with: embeddedHtml ?? "", options: .caseInsensitive, range: nil)
		
		self.webView.loadHTMLString(contentsOfFile, baseURL: fileUrl)
		self.webView.scrollView.isScrollEnabled = false
	}
	
	func setupWebView() {

		webView.navigationDelegate = self
		self.view.addSubview(webView)
		
		webView.isOpaque = false
		webView.contentMode = .scaleToFill
		webView.translatesAutoresizingMaskIntoConstraints = false
		webView.anchorToView(self.view, anchors: [.left, .top, .right, .bottom])
		
		webView.backgroundColor = .white
	}
}

extension WebViewController: WKNavigationDelegate {
	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		
		if navigationAction.navigationType == WKNavigationType.linkActivated {
			UIApplication.shared.open(navigationAction.request.url!)
			decisionHandler(.cancel)
			return
		}
		decisionHandler(.allow)
	}
}
