//
//  Networkable.swift
//
//  Created by Ayeba Amihere on 07/11/2019.
//  Copyright © 2019 Effect Studios. All rights reserved.
//

import Foundation

public class Networking {
    public static func getImproved(tokenFinder: @escaping () -> String) -> Networkable {
        VideoNetworking(tokenFinder: tokenFinder)
    }
    
    public static func getDefault(tokenFinder: @escaping () -> String) -> Networkable {
        BasicNetworking(tokenFinder: tokenFinder)
    }
    
    public static func getDefault(tokenFinder: @escaping () -> String, jsonDecoder: @escaping () -> JSONDecoder) -> Networkable {
        BasicNetworking(tokenFinder: tokenFinder, jsonDecoder: jsonDecoder)
    }
}

public protocol Networkable: AnyObject {
    typealias Result<K> = Networking.Result<K>
    
    var tokenFinder: (() -> String)? { get }
    var delegate: NetworkableDelegate? {get set}
    
    func patchSignatureImage<K: Codable>(url: URL, parameters: [String: String], imageData: [String: Data], completion: @escaping (Result<K>) -> Void)
    func patch<Posted: Codable, K: Codable>(url: URL, parameters: Posted, isAuthenticated: Bool, completion: @escaping (Result<K>) -> Void)
    func get<K: Codable>(url: URL, isAuthenticated: Bool, completion: @escaping (Result<K>) -> Void)
    func get(url: URL, isAuthenticated: Bool, completion: @escaping (Data?, URLResponse?, Error?) -> Void)
    func post<Posted: Codable, K: Codable>(url: URL, parameters: Posted, isAuthenticated: Bool, completion: @escaping (Result<K>) -> Void)
    func postImage<K: Codable>(url: URL, parameters: [String: String]?, imageData: [String: Data], completion: @escaping (Result<K>) -> Void)
    
    func perform<K: Codable>(request: URLRequest, method: HTTPMethod, completion: @escaping (Result<K>) -> Void)
    /// Upload content of all types, parameters will be added within a multipart form.
    /// - Parameters:
    ///   - url: endpoint on the upload server
    ///   - parameters: other important information e.g. metadata
    ///   - contentMap: a map of filenames to a tuple with content type and file url
    ///   - completion: a handler for results of the operation
    func postMultipartContent<K: Codable>(url: URL, parameters: [String: String]?, contentMap: [String: (type: String, url: URL)], completion: @escaping (Result<K>) -> Void)
}

public enum HTTPMethod: String {
    case GET = "GET"
    case PUT = "PUT"
    case POST = "POST"
    case PATCH = "PATCH"
}

public protocol NetworkableDelegate: AnyObject {
    typealias HTTPStatusCode = Networking.HTTPStatusCode
    
    func shouldRefreshToken(status: HTTPStatusCode) -> Bool
    func unauthorizedHandler(networking: Networkable)
}

public extension NetworkableDelegate {
    func shouldRefreshToken(status: HTTPStatusCode) -> Bool {
        if case HTTPStatusCode.unauthorized = status {
            return true
        }
        return false
    }
}

extension Networking {
    public enum Result<T> {
        case success(T)
        case failure(Error)
    }
}
