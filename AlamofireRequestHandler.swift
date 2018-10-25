//
//  AlamofireRequestHandler.swift
//  Alamofire
//
//  Created by Lincoln Fraley on 10/25/18.
//

import Foundation
import Alamofire

//  Class implementing `RequestHandler` and using Alamofire internally
internal class AlamofireRequestHandler {
    
    //  MARK: - Properties
    
    //  Internal properties for tokens
    private var _accessToken: String?
    
    private var _refreshToken: String?
    
    //  Singleton instance
    internal static let shared = AlamofireRequestHandler()
    
    //  `SessionManager` instance
    fileprivate static let sessionManager: SessionManager = {
        var sessionManager = SessionManager(configuration: .default)
        sessionManager.retrier = TokenRetrier()
        sessionManager.adapter = TokenAdapter()
        return sessionManager
    }()
    
    
    //  MARK: - Initializers
    
    //  Private init to force use of singleton
    private init() {}
}


//  `RequestHandler` conformance
extension AlamofireRequestHandler: RequestHandler {

    //  MARK: - Properties
    
    //  playPORTAL SSO tokens
    var accessToken: String? {
        get { return _accessToken }
        set { _accessToken = newValue }
    }

    var refreshToken: String? {
        get { return _refreshToken }
        set { _refreshToken = newValue }
    }

    //  User is authenticated if both `accessToken` and `refreshToken` aren't nil
    var isAuthenticated: Bool {
        return AlamofireRequestHandler.shared.accessToken != nil && AlamofireRequestHandler.shared.refreshToken != nil
    }

    
    //  MARK: - Methods
    
    /**
     Make request using internal `sessionManager` instance
    */
    func request(_ request: URLRequest, _ completion: ((Error?, Any?) -> Void)?) {
        AlamofireRequestHandler.sessionManager
            .request(request)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                switch response.result {
                case let .failure(error):
                    guard let urlResponse = response.response else {
                        completion?(error, nil)
                        return
                    }
                    let error = PlayPortalError.API.createError(from: urlResponse)
                    completion?(error, urlResponse)
                case let .success(value):
                    completion?(nil, value)
                }
        }
    }
}

//  Class implementing Alamofire `RequestAdapter`
fileprivate class TokenAdapter {
    
}

extension TokenAdapter: RequestAdapter {
    
    //  Add access token to header for requests to playPORTAL apis
    func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        var urlRequest = urlRequest
        if let accessToken = AlamofireRequestHandler.shared.accessToken {
            urlRequest.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        }
        return urlRequest
    }
}


//  Class implementing Alamofire `RequestRetrier`
fileprivate class TokenRetrier {
    
    //  MARK: - Properties
    
    //  Lock when refreshing
    fileprivate let lock = NSLock()
    
    fileprivate var isRefreshing = false
}

extension TokenRetrier: RequestRetrier {
    
    //  Requests should be retried when there is a refresh error
    func should(_ manager: SessionManager, retry request: Request, with error: Error, completion: @escaping RequestRetryCompletion) {
        //  Lock to allow one refresh at a time
        lock.lock(); defer { lock.unlock() }
        
        if let response = request.task?.response as? HTTPURLResponse {
            let error = PlayPortalError.API.createError(from: response)
            switch error {
            case let .requestFailed(error, _):
                switch error {
                //  Refresh should only occur on 4010 error
                case .tokenRefreshRequired:
                    //  TODO: implement refresh
                    break
                default:
                    completion(false, 0.0)
                }
                break
            default:
                //  TODO: should logout
                break
            }
        } else {
            completion(false, 0.0)
        }
    }
}



















