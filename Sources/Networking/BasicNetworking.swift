//
//  BasicNetworking.swift
//
//  Created by Ayeba Amihere on 14/10/2019.
//  Copyright © 2019 Ayeba Amihere. All rights reserved.
//

import Foundation

internal class BasicNetworking: Networkable, NetworkableError {
    public let tokenFinder: (() -> String)?
    public var unauthorizedHandler: (() -> ())?
    
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
         unauthorizedHandler: @escaping () -> () = {},
         jsonEncoder: @escaping () -> JSONEncoder = {JSONEncoder()},
         jsonDecoder: @escaping () -> JSONDecoder = {JSONDecoder()}) {
        self.tokenFinder = tokenFinder
        self.unauthorizedHandler = unauthorizedHandler
        self.jsonEncoder = jsonEncoder
        self.jsonDecoder = jsonDecoder
    }
    
    /// Configures the timeout information
    internal func getSessionConfig(_ requestTimeout: TimeInterval = 20.0) -> URLSessionConfiguration {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = requestTimeout
        sessionConfig.timeoutIntervalForResource = 30.0
        return sessionConfig
    }
    
    func cloneRequest(request modelRequest: URLRequest, isAuthenticated: Bool) -> URLRequest {
        var request = URLRequest(url: modelRequest.url!)
        request.httpMethod = modelRequest.httpMethod
        request.addValue(JSON_SPEC, forHTTPHeaderField: ACCEPT_HEADER)

        if let tokenFinder = tokenFinder, isAuthenticated {
            let authToken = tokenFinder()
            request.addValue("\(AUTH_PREPEND) \(authToken)", forHTTPHeaderField: AUTH_HEADER)
        }
        return request
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
    
    /// Gets resources from a specified URL
    public func get(url: URL, isAuthenticated: Bool, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        
        let request: URLRequest = createNewRequest(url: url, method: HTTPMethod.GET, isAuthenticated: isAuthenticated)
        let session: URLSession = URLSession(configuration: getSessionConfig())
        
        let task: URLSessionDataTask = session.dataTask(with: request) { data, response, error in
            completion(data,response,error)
        }
        task.resume()
    }
    
    /// Gets resources from a specified URL
    public func get<K: Codable>(url: URL, isAuthenticated: Bool, completion: @escaping (Result<K>) -> Void) {
        
        let request: URLRequest = createNewRequest(url: url, method: HTTPMethod.GET, isAuthenticated: isAuthenticated)
        dataTaskHelper(request, completion: completion)
    }
    
    public func perform<K: Codable>(request: URLRequest, method: HTTPMethod, completion: @escaping (Result<K>) -> Void) {
        var synthesizedRequest: URLRequest = request
        synthesizedRequest.httpMethod = method.rawValue
        dataTaskHelper(synthesizedRequest, completion: completion)
    }
    
    public func patch<Posted: Codable, K: Codable>(url: URL, parameters: Posted, isAuthenticated: Bool, completion: @escaping (Result<K>) -> Void) {
        
        //now creating the URLRequest object using the url object
        let request: URLRequest = createPostRequest(url: url, withParameters: parameters, isAuthenticated: isAuthenticated, method: .PATCH)
        dataTaskHelper(request, completion: completion)
    }
    
    /// Posts resources to a specified URL
    public func post<Posted: Codable, K: Codable>(url: URL, parameters: Posted, isAuthenticated: Bool, completion: @escaping (Result<K>) -> Void) {
        
        //now creating the URLRequest object using the url object
        let request: URLRequest = createPostRequest(url: url, withParameters: parameters, isAuthenticated: isAuthenticated)
        dataTaskHelper(request, completion: completion)
    }
    
    public func patchSignatureImage<K: Codable>(url: URL, parameters: [String: String], imageData: [String: Data], completion: @escaping (Result<K>) -> Void) {
        imageUploadHelper(url: url, method: .PATCH, parameters: parameters, imageData: imageData, completion: completion)
    }
    
    /// Upload image to url, parameters will be added within a multipart form.
    public func postImage<K: Codable>(url: URL, parameters: [String: String]?, imageData: [String: Data], completion: @escaping (Result<K>) -> Void) {
        imageUploadHelper(url: url, method: .POST, parameters: parameters, imageData: imageData, completion: completion)
    }
    
    func postMultipartContent<K>(url: URL, parameters: [String : String]?, contentMap: [String : (type: String, url: URL)], completion: @escaping (Result<K>) -> Void) where K : Decodable, K : Encodable {
        fatalError("postMultipartContent has not been implemented")
    }
    
    /// Upload image to url, parameters will be added within a multipart form.
    func imageUploadHelper<K: Codable>(url: URL, method: HTTPMethod, parameters: [String: String]?, imageData: [String: Data], completion: @escaping (Result<K>) -> Void) {
        // generate boundary string using a unique per-app string
        let boundary: String = createBoundary()
        let lineBreak: String = "\r\n"
        let formParameter: String = "files"
        
        // Set Content-Type Header to multipart/form-data, this is equivalent to submitting form data with file upload in a web browser
        // And the boundary is also set here
        var request = createNewRequest(url: url, method: method, isAuthenticated: true)
        
        //request.setValue("*/*", forHTTPHeaderField: ACCEPT_HEADER)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: CONTENT_TYPE_HEADER)

        var data: Data = Data()
        
        // MARK:- Image is always in jpg
        for (photo) in imageData {
            // Add the image data to the raw http request data
            data.append(getBoundary(boundary))
            data.append("Content-Disposition: form-data; name=\"\(formParameter)\"; filename=\"\(photo.key)\"\(lineBreak)")
            data.append("Content-Type: image/jpg\(lineBreak)\(lineBreak)")
            data.append(photo.value)
            data.append(lineBreak)
        }
        
        // End the raw http request data, note that there is 2 extra dash ("-") at the end, this is to indicate the end of the data
        data.append(getBoundary(boundary, isTerminating: true))
        
        request.httpBody = data
        
        dataTaskHelper(request, requestTimeout: 50.0, completion: completion)
    }
}

//MARK: - Data processing
extension BasicNetworking {
    private func dataTaskHelper<K: Codable>(_ request: URLRequest, retryCount: Int = 0, requestTimeout: TimeInterval = 20.0, completion: @escaping (Result<K>) -> Void) {
        //creating dataTask using the session object to send data to the server
        let session: URLSession = URLSession(configuration: getSessionConfig(requestTimeout))
        let task: URLSessionDataTask = session.dataTask(with: request) { [unowned self] data, response, error in
            dataTaskCompletion(response, error, data, request: request, retryCount: retryCount, completion: completion)
        }
        task.resume()
    }
    
    fileprivate func dataTaskCompletion<K: Codable>(_ response: URLResponse?, _ error: Error?, _ data: Data?, request: URLRequest, retryCount: Int = 0, completion: @escaping (Result<K>) -> Void) {
        let response: HTTPURLResponse? = response as? HTTPURLResponse
        
        if let error = error {
            process(error: error, completion: completion)
            return
        } 
        
        if hasServerErrors(response), let status = response?.status {
            
            if shouldRefreshToken(status: status), retryCount < 1, let unauthorizedHandler = unauthorizedHandler {
                unauthorizedHandler()
                
                // wait
                sleep(2)
                
                // Re run request which failed on authorization
                let newRequest = cloneRequest(request: request, isAuthenticated: true)
                dataTaskHelper(newRequest, retryCount: retryCount + 1, completion: completion)
            } else {
                process(status: status, completion: completion)
            }
            
        } else if let jsonData = data {
            parse(json: jsonData, completion: completion)
        }
    }
    
    func process<K: Codable>(status: HTTPStatusCode, completion: @escaping (Result<K>) -> Void) {
        NSLog(status.localizedDescription)
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

//MARK: - Helpers
extension BasicNetworking {
    func createBoundary() -> String {
        "B-\(UUID().uuidString)"
    }
    
    func getBoundary(_ boundary: String, isTerminating end: Bool = false, lineBreak: String = "\r\n") -> String {
        return "--\(boundary)\(end ? "--" : "")\(lineBreak)"
    }
    
    func printError(_ data: Data) {
        if let errorStr = String(data: data, encoding: .utf8) {
            NSLog("Error: \(errorStr)")
        }
    }
}

internal extension Data {
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
