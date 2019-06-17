//
//  PlayPortalClient.swift
//  Alamofire
//
//  Created by Lincoln Fraley on 4/24/19.
//

import Foundation

typealias HTTPBody = [String: Any?]
typealias HTTPHeaderFields = [String: Any?]
typealias HTTPQueryParameters = [String: Any?]

typealias CreateRequest = (
  String,
  HTTPMethod,
  HTTPQueryParameters?,
  HTTPBody?,
  HTTPHeaderFields?
  ) -> URLRequest

typealias HandleFailure = (
  Error?,
  HTTPURLResponse
  ) -> Error

typealias HandleSuccess<Result> = (
  HTTPURLResponse,
  Data
  ) throws -> Result

class EndpointsBase {
  
  static let sandboxHost = "https://sandbox.playportal.io"
  static let productionHost = "https://api.playportal.io"
  static let developHost = "https://develop-api.goplayportal.com"
  
  static var host: String {
    switch (PlayPortalClient.environment) {
    case .sandbox:
      return sandboxHost
    case .develop:
      return URLs.developHost
    case .production:
      return URLs.productionHost
    }
  }
}

/**
 Class used internally by the SDK
 */
public class PlayPortalClient {
  
  
  //  MARK: - Properties
  
  static var environment = PlayPortalEnvironment.sandbox
  static var clientId = ""
  static var clientSecret = ""
  
  static var accessToken: String? {
    get { return globalStorageHandler.get("accessToken") }
    set(accessToken) {
      if let accessToken = accessToken {
        globalStorageHandler.set(accessToken, atKey: "accessToken")
      }
    }
  }
  
  static var refreshToken: String? {
    get { return globalStorageHandler.get("refreshToken") }
    set(refreshToken) {
      if let refreshToken = refreshToken {
        globalStorageHandler.set(refreshToken, atKey: "refreshToken")
      }
    }
  }
  
  static var isAuthenticated: Bool {
    return PlayPortalClient.accessToken != nil && PlayPortalClient.refreshToken != nil
  }
  
  
  static var isRefreshing = false
  static var requestsToRetry = [() -> Void]()
  static var lock = NSLock()
  
  
  //  Standard request creator
  //  Just takes params and creates a url request
  func defaultRequestCreator(
    url: String,
    method: HTTPMethod,
    queryParameters: HTTPQueryParameters? = nil,
    body: HTTPBody? = nil,
    headers: HTTPHeaderFields? = nil
    ) -> URLRequest
  {
    let _url = url
    guard var url = URL(string: url) else {
      fatalError("Couldn't create url from \(_url)")
    }
    
    if let queryParameters = queryParameters,
      var components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
      components.queryItems = queryParameters
        .filter { $0.1 != nil }
        .map { URLQueryItem(name: $0.0, value: String(describing: $0.1!) ) }
      url = try! components.asURL()
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    
    if let body = body {
      request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted])
    }
    
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    if let headers = headers {
      for header in headers where header.value != nil {
        request.setValue(String(describing: header.value!), forHTTPHeaderField: header.key)
      }
    }
    
    return request
  }
  
  
  //  Creates an authenticated request using access token
  func standardAuthRequestCreator(accessToken: String?) -> CreateRequest {
    guard let accessToken = accessToken else {
      //  TODO: - should just logout
      fatalError("Attempting to make authenticatd request when not authenticated.")
    }
    return { url, method, queryParameters, body, headers -> URLRequest in
      var _headers = headers ?? [:]
      _headers["Authorization"] = "Bearer \(accessToken)"
      return self.defaultRequestCreator(url: url, method: method, queryParameters: queryParameters, body: body, headers: _headers)
    }
  }
  
  
  //  Standard failure handler
  //  Tries to create a PlayPortalError from response, otherwises returns a default error
  func defaultFailureHandler(
    error: Error?,
    response: HTTPURLResponse
    ) -> Error
  {
    return PlayPortalError.API.createError(from: response)
      ?? error
      ?? PlayPortalError.API.requestFailedForUnknownReason(message: "Request returned without response.")
  }
  
  
  //  Standard success handler
  //  Attempts to decode data to given Result type
  func defaultSuccessHandler<Result: Decodable>(
    response: HTTPURLResponse,
    data: Data
    ) throws -> Result
  {
    return try JSONDecoder().decode(Result.self, from: data)
  }
  
  
  //  Override to handle events
  func onEvent() {
    
  }
  
  func request(
    url: String,
    method: HTTPMethod,
    queryParameters: HTTPQueryParameters? = nil,
    body: HTTPBody? = nil,
    headers: HTTPHeaderFields? = nil,
    createRequest: CreateRequest? = nil,
    handleFailure: HandleFailure? = nil,
    handleSuccess: HandleSuccess<Any>? = nil,
    _ completion: @escaping (Error?, Any?) -> Void
    ) -> Void
  {
    
  }
  
  func request<Result: Decodable>(
    url: String,
    method: HTTPMethod,
    queryParameters: HTTPQueryParameters? = nil,
    body: HTTPBody? = nil,
    headers: HTTPHeaderFields? = nil,
    createRequest: CreateRequest? = nil,
    handleFailure: HandleFailure? = nil,
    handleSuccess: HandleSuccess<Result>? = nil,
    _ completion: ((Error?, Result?) -> Void)?
    ) -> Void
  {
    //  TODO: - move all refresh code to RefreshClient
    
    PlayPortalClient.lock.lock(); defer { PlayPortalClient.lock.unlock() }
    
    let failureHandler = handleFailure ?? defaultFailureHandler
    let successHandler = handleSuccess ?? defaultSuccessHandler
    
    if PlayPortalClient.isRefreshing {
      PlayPortalClient.requestsToRetry.append {
        
        self.request(url: url, method: method, queryParameters: queryParameters, body: body, headers: headers, createRequest: createRequest, handleFailure: failureHandler, handleSuccess: successHandler, completion)
      }
    } else {
      
      let requestCreator = createRequest ?? standardAuthRequestCreator(accessToken: PlayPortalClient.accessToken)
      let urlRequest = requestCreator(url, method, queryParameters, body, headers)
      
      HTTPClient.perform(urlRequest) { error, response, data in
        if error != nil || (response?.statusCode != nil && response!.statusCode > 299) {
          guard let response = response else {
            completion?(error, nil); return
          }
          
          if PlayPortalError.API.ErrorCode.errorCode(for: response) == .tokenRefreshRequired {
            PlayPortalClient.lock.lock(); defer { PlayPortalClient.lock.unlock() }
            
            PlayPortalClient.requestsToRetry.append {
              
              self.request(url: url, method: method, queryParameters: queryParameters, body: body, headers: headers, createRequest: createRequest, handleFailure: failureHandler, handleSuccess: successHandler, completion)
            }
            
            if !PlayPortalClient.isRefreshing {
              PlayPortalClient.isRefreshing = true
              RefreshClient.shared.refresh()
            }
          } else {
            completion?(failureHandler(error, response), nil)
          }
          
          
        } else {
          guard let response = response, let data = data else {
            completion?(PlayPortalError.API.requestFailedForUnknownReason(message: "Request returned without response."), nil); return
          }
          
          do {
            completion?(nil, try successHandler(response, data))
          } catch {
            completion?(error, nil)
          }
        }
      }
    }
  }
}