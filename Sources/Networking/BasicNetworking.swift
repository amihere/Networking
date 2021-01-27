//
//  BasicNetworking.swift
//
//  Created by Ayeba Amihere on 14/10/2019.
//  Copyright © 2019 Ayeba Amihere. All rights reserved.
//

import Foundation

internal class BasicNetworking: Networkable, NetworkableError {
    public weak var delegate: NetworkableDelegate?
    public let tokenFinder: (() -> String)?
    
    let CONTENT_TYPE_HEADER = "Content-Type"
    let ACCEPT_HEADER = "Accept"
    let AUTH_HEADER = "Authorization"
    let JSON_SPEC = "application/json"
    let AUTH_PREPEND = "Bearer"
    
    let jsonEncoder: () -> JSONEncoder
    let jsonDecoder: () -> JSONDecoder
    
    typealias BeautifiedError = Networking.BeautifiedError
    typealias HTTPStatusCode = Networking.HTTPStatusCode
    typealias Result = Networking.Result
    
    init(tokenFinder: @escaping () -> String,
         jsonEncoder: @escaping () -> JSONEncoder = {JSONEncoder()},
         jsonDecoder: @escaping () -> JSONDecoder = {JSONDecoder()}) {
        self.tokenFinder = tokenFinder
        self.jsonEncoder = jsonEncoder
        self.jsonDecoder = jsonDecoder
    }
    
    /// Configures the timeout information
    private func getSessionConfig(isImageConfig: Bool = false) -> URLSessionConfiguration {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = isImageConfig ? 50.0 : 20.0
        sessionConfig.timeoutIntervalForResource = 30.0
        return sessionConfig
    }
    
    /// Make a new request with the url and authentication
    func createNewRequest(url: URL, method: HTTPMethod, isAuthenticated: Bool) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue(JSON_SPEC, forHTTPHeaderField: ACCEPT_HEADER)

        if let tokenFinder = tokenFinder, isAuthenticated {
            let authToken = tokenFinder()
            request.addValue("\(AUTH_PREPEND) \(authToken)", forHTTPHeaderField: AUTH_HEADER)
        }
        return request
    }
    
    /// Make a POST request with a body.
    private func createPostRequest<Posted: Codable>(url: URL, withParameters parameters: Posted, isAuthenticated:Bool, method: HTTPMethod = .POST) -> URLRequest {
        
        var request = createNewRequest(url: url, method: method, isAuthenticated: isAuthenticated)
        request.addValue(JSON_SPEC, forHTTPHeaderField: CONTENT_TYPE_HEADER)
        do {
            let encoder: JSONEncoder = jsonEncoder()
            request.httpBody = try encoder.encode(parameters)
        } catch {
            NSLog(error.localizedDescription)
        }
        
        return request
    }
    
    public func custom<K: Codable>(_ request: URLRequest, completion: @escaping (Networking.Result<K>) -> Void) {
        dataTaskHelper(request, isImageConfig: false, completion: completion)
    }
    
    /// Gets resources from a specified URL
    public func get<K: Codable>(url: URL, isAuthenticated: Bool, completion: @escaping (Result<K>) -> Void) {
        
        let request: URLRequest = createNewRequest(url: url, method: HTTPMethod.GET, isAuthenticated: isAuthenticated)
        dataTaskHelper(request, isImageConfig: false, completion: completion)
    }
    
    public func patch<Posted: Codable, K: Codable>(url: URL, parameters: Posted, isAuthenticated: Bool, completion: @escaping (Result<K>) -> Void) {
        
        //now creating the URLRequest object using the url object
        let request: URLRequest = createPostRequest(url: url, withParameters: parameters, isAuthenticated: isAuthenticated, method: .PATCH)
        dataTaskHelper(request, isImageConfig: false, completion: completion)
    }
    
    /// Posts resources to a specified URL
    public func post<Posted: Codable, K: Codable>(url: URL, parameters: Posted, isAuthenticated: Bool, completion: @escaping (Result<K>) -> Void) {
        
        //now creating the URLRequest object using the url object
        let request: URLRequest = createPostRequest(url: url, withParameters: parameters, isAuthenticated: isAuthenticated)
        dataTaskHelper(request, isImageConfig: false, completion: completion)
    }
    
    public func patchSignatureImage<K: Codable>(url: URL, parameters: [String: String], imageData: [String: Data], completion: @escaping (Result<K>) -> Void) {
        imageUploadHelper(url: url, method: .PATCH, parameters: parameters, imageData: imageData, completion: completion)
    }
    
    /// Upload image to url, parameters will be added within a multipart form.
    public func postImage<K: Codable>(url: URL, parameters: [String: String]?, imageData: [String: Data], completion: @escaping (Result<K>) -> Void) {
        imageUploadHelper(url: url, method: .POST, parameters: parameters, imageData: imageData, completion: completion)
    }
    
    /// Upload image to url, parameters will be added within a multipart form.
    func imageUploadHelper<K: Codable>(url: URL, method: HTTPMethod, parameters: [String: String]?, imageData: [String: Data], completion: @escaping (Result<K>) -> Void) {
        // generate boundary string using a unique per-app string
        let boundary = createBoundary()
        
        // Set Content-Type Header to multipart/form-data, this is equivalent to submitting form data with file upload in a web browser
        // And the boundary is also set here
        //var request = createNewRequest(url: url, method: HTTPMethod.POST, isAuthenticated: true)
        var request = createNewRequest(url: url, method: method, isAuthenticated: true)
        
        //request.setValue("*/*", forHTTPHeaderField: ACCEPT_HEADER)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: CONTENT_TYPE_HEADER)

        var data: Data = Data()
        
        // MARK:- Image is always in jpg
        let imageKey = "files"
        for (path, value) in imageData {
            // Add the image data to the raw http request data
            data.append(getBoundary(boundary))
            data.append("Content-Disposition: form-data; name=\"\(imageKey)\"; filename=\"\(path)\"\r\n")
            data.append("Content-Type: image/jpg\r\n\r\n")
            data.append(value)
        }
        
        parameters?.forEach {
            data.append(getBoundary(boundary))
            data.append("Content-Disposition: form-data; name=\"\($0)\"\r\n\r\n")
            data.append($1)
        }
        
        // End the raw http request data, note that there is 2 extra dash ("-") at the end, this is to indicate the end of the data
        data.append(getBoundary(boundary, isTerminating: true))
        
        request.httpBody = data
        dataTaskHelper(request, isImageConfig: true, completion: completion)
    }
}

// MARK:- Refresh token
extension BasicNetworking {
    func unauthorizedHandler() {
        guard let delegate = delegate else {
            NSLog("Configure refresh token completion")
            return
        }
        delegate.unauthorizedHandler()
    }
}

//MARK:- Data processing
extension BasicNetworking {
    private func dataTaskHelper<K: Codable>(_ request: URLRequest, isImageConfig: Bool, completion: @escaping (Result<K>) -> Void) {
        //creating dataTask using the session object to send data to the server
        let session: URLSession = URLSession(configuration: getSessionConfig(isImageConfig: isImageConfig))
        
        let task: URLSessionDataTask = session.dataTask(with: request) { [unowned self] data, response, error in
            let response: HTTPURLResponse? = response as? HTTPURLResponse
            
            if let error = error {
                process(error: error, completion: completion)
            } else if hasServerErrors(response), let status = response?.status {
                process(status: status, completion: completion)
            } else if let jsonData = data {
                parse(json: jsonData, completion: completion)
            }
        }
        task.resume()
    }
    
    func process<K: Codable>(status: HTTPStatusCode, completion: @escaping (Result<K>) -> Void) {
        NSLog(status.localizedDescription)
        if let delegate = delegate, delegate.shouldRefreshToken(status: status) {
            unauthorizedHandler()
        }
        #warning("might cause race conditions")
        completion(.failure(BeautifiedError.serverRejection))
    }
    
    func process<K: Codable>(error: Error, completion: @escaping (Result<K>) -> Void) {
        NSLog(error.localizedDescription)
        completion(.failure(BeautifiedError(error: error)))
    }
    
    func parse<K: Codable>(json jsonData: Data, completion: @escaping (Result<K>) -> Void) {
        let decoder: JSONDecoder = jsonDecoder()
        do {
            let objects = try decoder.decode(K.self, from: jsonData)
            completion(.success(objects))
        } catch {
            NSLog(error.localizedDescription)
            printError(jsonData)
            completion(.failure(BeautifiedError.jsonMismatch))
        }
    }
}

//MARK:- Helpers
extension BasicNetworking {
    func createBoundary() -> String {
        UUID().uuidString
    }
    
    func getBoundary(_ boundary: String, isTerminating end: Bool = false) -> String {
        return "\r\n--\(boundary)\(end ? "--" : "")\r\n"
    }
    
    func printError(_ data: Data) {
        if let errorStr = String(data: data, encoding: .utf8) {
            NSLog("Error: \(errorStr)")
        }
    }
}

fileprivate extension Data {
    /// Append string to Data
    ///
    /// Rather than littering my code with calls to `data(using: .utf8)` to convert `String` values to `Data`, this wraps it in a nice convenient little extension to Data. This defaults to converting using UTF-8.
    ///
    /// - parameter string: The string to be added to the `Data`.
    mutating func append(_ string: String, using encoding: String.Encoding = .utf8) {
        if let data = string.data(using: encoding) {
            append(data)
        }
    }
}
