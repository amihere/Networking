//
//  File.swift
//  
//
//  Created by Ayeba on 28/01/2023.
//

import Foundation

class VideoNetworking: BasicNetworking {
    public func postMultipartContent<K: Codable>(url: URL, parameters: [String: String]?, contentMap: [String: (type: String, url: URL)], completion: @escaping (Result<K>) -> Void) {
        multipartContentUploadHelper(url: url, method: .POST, parameters: parameters, contentMap: contentMap, completion: completion)
    }
    
    func multipartContentUploadHelper<K: Codable>(url: URL, method: HTTPMethod, parameters: [String: String]?, contentMap: [String: (type: String, url: URL)], completion: @escaping (Result<K>) -> Void) {
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
        for (content) in contentMap {
            let contentType: String = content.value.type
            let fileURL: URL = content.value.url
            let fileData: Data! = try! Data(contentsOf: fileURL)
            // Add the image data to the raw http request data
            data.append(getBoundary(boundary))
            data.append("Content-Disposition: form-data; name=\"\(formParameter)\"; filename=\"\(content.key)\"\(lineBreak)")
            data.append("Content-Type: \(contentType)\(lineBreak)\(lineBreak)")
            data.append(fileData)
            data.append(lineBreak)
        }
        
        // End the raw http request data, note that there is 2 extra dash ("-") at the end, this is to indicate the end of the data
        data.append(getBoundary(boundary, isTerminating: true))
        
        // set content length
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        
        upload(request, data: data) {
            completion($0)
        }
    }
    
    private func upload<K: Codable>(_ request: URLRequest, data: Data, requestTimeout: TimeInterval = 60.0, completion: @escaping (Result<K>) -> Void) {
        let session: URLSession = URLSession(configuration: getSessionConfig(requestTimeout))
        let task: URLSessionDataTask = session.uploadTask(with: request, from: data) { [unowned self] data, response, error in
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
}
