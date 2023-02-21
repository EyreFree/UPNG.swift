
import UIKit
import EFFoundation
import WebKit

public class UPNG {
    
    public static let shared: UPNG = UPNG()
    
    private static var dictionary: [String: WKWebView] = [:]
    
    public init() {
        
    }
    
    lazy var isInAppex: Bool = {
        let bundleUrl: URL = Bundle.main.bundleURL
        let bundlePathExtension: String = bundleUrl.pathExtension
        let isAppex: Bool = bundlePathExtension == "appex"
        return isAppex
    }()
    
    private func getWebViewWith(tag: String, createIfNeeded: Bool, completion: ((WKWebView?) -> Void)?) {
        if let webView = UPNG.dictionary[tag] {
            completion?(webView)
        } else if createIfNeeded {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let tempView: WKWebView = WKWebView()
                tempView.isHidden = false
                self.setWebViewWith(tag: tag, webView: tempView)
                completion?(tempView)
            }
        }
    }
    
    private func removeWebViewWith(tag: String) {
        setWebViewWith(tag: tag, webView: nil)
    }
    
    private func setWebViewWith(tag: String, webView: WKWebView?) {
        if let webView = webView {
            UPNG.dictionary[tag] = webView
        } else {
            UPNG.dictionary.removeValue(forKey: tag)
        }
    }
    
    /// UPNG.com/optimize.
    /// - Parameters:
    ///   - imageUrl: imageUrl.
    ///   - compressionLevel: compressionLevel for Lossy Gif, 0 - no color but less size, 1000 - full color and full size, range [0, 1000], default 200.
    ///   - timeout: force completion with nil after seconds, to avoid dead cycle, default 20s.
    ///   - completion: completion.
    /// - Returns: Void..
    public func optimize(imageData: Data, compressionLevel: Int = 200, timeout: TimeInterval = 20, completion: ((Data?, Error?) -> Void)?) {
        let webViewTag: String = "\(Date().timeIntervalSince1970)"
        getWebViewWith(tag: webViewTag, createIfNeeded: true) { [weak self] webView in
            guard let self = self else { return }
            
            if let webView = webView {
                let timeoutDate: Date = Date().addingTimeInterval(timeout)
                func customCompletion(_ imageData: Data?, _ error: Error?) {
                    self.removeWebViewWith(tag: webViewTag)
                    completion?(imageData, error)
                }
                self.loadUPNGPage(webView: webView) { [weak self] success in
                    guard let self = self else { return }
                    
                    if success {
                        self.waitingPageLoading(webView: webView, timeoutDate: timeoutDate) { [weak self] result, error in
                            guard let self = self else { return }
                            
                            if true == result {
                                self.waitingSetCompressionLevel(webView: webView, value: compressionLevel) { [weak self] result, error in
                                    guard let self = self else { return }
                                    
                                    if true == result {
                                        let imageBase64String: String = imageData.base64EncodedString()
                                        self.waitingSetImageBase64String(webView: webView, imageBase64String: imageBase64String) { [weak self] result, error in
                                            guard let self = self else { return }
                                            
                                            if true == result {
                                                self.waitingInputButtonClicked(webView: webView) { [weak self] error in
                                                    guard let self = self else { return }
                                                    
                                                    if let error = error {
                                                        printLog("waitingInputButtonClicked: \(error.localizedDescription)")
                                                        customCompletion(nil, error)
                                                    } else {
                                                        self.waitingOutImageState(webView: webView, timeoutDate: timeoutDate) { [weak self] result, error in
                                                            guard let self = self else { return }
                                                            
                                                            if true == result {
                                                                self.waitingGetOutImageBase64String(webView: webView, timeoutDate: timeoutDate) { [weak self] imageBase64String, error in
                                                                    guard let _ = self else { return }
                                                                    
                                                                    if let imageBase64String = imageBase64String, imageBase64String.isEmpty == false,
                                                                       let imageData = Data(base64Encoded: imageBase64String, options: .ignoreUnknownCharacters) {
                                                                        customCompletion(imageData, error)
                                                                    } else {
                                                                        customCompletion(nil, error)
                                                                    }
                                                                }
                                                            } else {
                                                                printLog("waitingOptimizeState failed: \(error?.localizedDescription ?? "")")
                                                                customCompletion(nil, error)
                                                            }
                                                        }
                                                    }
                                                }
                                            } else {
                                                printLog("waitingSetImageBase64String failed: \(error?.localizedDescription ?? "")")
                                                customCompletion(nil, error)
                                            }
                                        }
                                    } else {
                                        printLog("waitingSetCompressionLevel failed: \(error?.localizedDescription ?? "")")
                                        customCompletion(nil, error)
                                    }
                                }
                            } else {
                                printLog("waitingPageLoading failed: \(error?.localizedDescription ?? "")")
                                customCompletion(nil, error)
                            }
                        }
                    } else {
                        customCompletion(nil, "loadUPNGPage failed")
                    }
                }
            } else {
                completion?(nil, "Create webView failed")
            }
        }
    }
    
    private func loadUPNGPage(webView: WKWebView, completion: ((Bool) -> Void)?) {
        printLog("loadUPNGPage")
        if isInAppex {
            if let link = URL(string:"https://upng.eyrefree.org/") {
                let request = URLRequest(url: link)
                
                DispatchQueue.main.async { [weak self] in
                    guard let _ = self else { return }
                    
                    webView.load(request)
                    completion?(true)
                }
            } else {
                completion?(false)
            }
        } else {
            if let url = Bundle(for: UPNG.self).url(forResource: "index", withExtension: "html", subdirectory: "") {
                DispatchQueue.main.async { [weak self] in
                    guard let _ = self else { return }
                    
                    // printLog("loadUPNGPage: \(url)")
                    webView.loadFileURL(url, allowingReadAccessTo: url)
                    webView.load(URLRequest(url: url))
                    completion?(true)
                }
            } else {
                completion?(false)
            }
        }
    }
    
    private func waitingPageLoading(webView: WKWebView, timeoutDate: Date, completion: ((Bool, Error?) -> Void)?) {
        printLog("waitingPageLoading")
        if Date() >= timeoutDate {
            completion?(false, "Timeout")
            return
        }
        
        let javascript: String = "document.getElementById('base64-textarea') != null && document.getElementById('base64-result-textarea') != null && document.getElementById('base64-button') != null && document.getElementById('eRNG') != null"
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            webView.evaluateJavaScript(javascript) { [weak self] data, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion?(false, error)
                } else if let result = data as? Bool, result == true {
                    completion?(true, nil)
                } else {
                    DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: DispatchTime.now() + 0.05) { [weak self] in
                        guard let self = self else { return }
                        
                        self.waitingPageLoading(webView: webView, timeoutDate: timeoutDate, completion: completion)
                    }
                }
            }
        }
    }
    
    private func waitingSetCompressionLevel(webView: WKWebView, value: Int, completion: ((Bool, Error?) -> Void)?) {
        printLog("waitingSetCompressionLevel")
        if value == 200 {
            completion?(true, nil)
        } else {
            let javascript: String = "document.getElementById('eRNG').value = \(value); moveQual(\(value));"
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                webView.evaluateJavaScript(javascript) { [weak self] data, error in
                    guard let _ = self else { return }
                    
                    if let error = error {
                        completion?(false, error)
                    } else if let result = data as? Int, result == value {
                        completion?(true, nil)
                    } else {
                        completion?(false, "evaluateJavaScript result not true")
                    }
                }
            }
        }
    }
    
    private func waitingSetImageBase64String(webView: WKWebView, imageBase64String: String, completion: ((Bool, Error?) -> Void)?) {
        printLog("waitingSetImageBase64String")
        let javascript: String = "document.getElementById('base64-textarea').value = '\(imageBase64String)'"
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            webView.evaluateJavaScript(javascript) { [weak self] data, error in
                guard let _ = self else { return }
                
                if let error = error {
                    completion?(false, error)
                } else if let result = data as? String, result == imageBase64String {
                    completion?(true, nil)
                } else {
                    completion?(false, "evaluateJavaScript result not true")
                }
            }
        }
    }
    
    private func waitingInputButtonClicked(webView: WKWebView, completion: ((Error?) -> Void)?) {
        printLog("waitingInputButtonClicked")
        let javascript: String = "document.getElementById('base64-button').click();"
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            webView.evaluateJavaScript(javascript) { [weak self] data, error in
                guard let _ = self else { return }
                
                completion?(error)
            }
        }
    }
    
    private func waitingOutImageState(webView: WKWebView, timeoutDate: Date, completion: ((Bool, Error?) -> Void)?) {
        printLog("waitingOutImageState")
        if Date() >= timeoutDate {
            completion?(false, "Timeout")
            return
        }
        
        let javascript: String = "document.getElementById('base64-result-textarea').value.length > 0"
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            webView.evaluateJavaScript(javascript) { [weak self] data, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion?(false, error)
                } else if let result = data as? Bool, result == true {
                    completion?(true, nil)
                } else {
                    DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: DispatchTime.now() + 0.05) { [weak self] in
                        guard let self = self else { return }
                        
                        self.waitingOutImageState(webView: webView, timeoutDate: timeoutDate, completion: completion)
                    }
                }
            }
        }
    }
    
    private func waitingGetOutImageBase64String(webView: WKWebView, timeoutDate: Date, completion: ((String?, Error?) -> Void)?) {
        printLog("waitingGetOutImageBase64String")
        if Date() >= timeoutDate {
            completion?(nil, "Timeout")
            return
        }
        
        let javascript: String = "document.getElementById('base64-result-textarea').value"
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            webView.evaluateJavaScript(javascript) { [weak self] data, error in
                guard let _ = self else { return }
                
                if let error = error {
                    completion?(nil, error)
                } else if let base64String = data as? String, base64String.isEmpty == false {
                    let base64DataString: String = base64String.removePrefix(string: "data:application/octet-stream;base64,")
                    completion?(base64DataString, nil)
                } else {
                    DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: DispatchTime.now() + 0.05) { [weak self] in
                        guard let self = self else { return }
                        
                        self.waitingGetOutImageBase64String(webView: webView, timeoutDate: timeoutDate, completion: completion)
                    }
                }
            }
        }
    }
}
