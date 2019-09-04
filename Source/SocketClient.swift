//
//  SocketClient.swift
//
//  Created by Lincoln Fraley on 6/27/19.
//

import Foundation
import CoreFoundation
import AnyCodable

class SocketConfiguration {
  
  static let sandboxHost = ""
  static let productionHost = ""
  static let developHost = "develop-events.goplayportal.com"
  
  static let port = 80
  
  static var host: String {
    switch PlayPortalHTTPClient.environment {
    case .sandbox:
      return sandboxHost
    case .develop:
      return developHost
    case .production:
      return productionHost
    }
  }
}

class SocketMessage: Codable {
  
  let type: SocketMessageType
  let `internal`: Bool
  let success: Bool
  private let _data: [String: AnyCodable]
  public private(set) lazy var data: [String: Any]? = {
    guard let d = try? JSONEncoder().encode(_data) else { return nil }
    return (try? JSONSerialization.jsonObject(with: d, options: [])) as? [String: Any]
  }()
  
  enum CodingKeys: String, CodingKey {
    case type = "type"
    case `internal` = "internal"
    case success = "success"
    case _data = "data"
  }
  
  enum SocketMessageType: String, Codable {
    
    case authenticate = "authenticate"
    case status = "status"
    case game = "game"
    case error = "error"
  }
}


protocol SocketClient {
  
  typealias SocketSubscriber = (_ error: Error?, _ data: [String: Any]?) -> Void
  
  var isConnected: Bool { get }
  
  func open(atHost host: String, forPort port: Int)
  func close()
  func publish(data: Data)
  func subscribe(_ subscriber: @escaping SocketSubscriber)
}


//  `SocketClient` that internally uses `URLSessionStreamTask`
class StreamSocketClient: NSObject {
  
  private var task: URLSessionStreamTask?
  private var subscriber: SocketSubscriber?
  private var opened = false
  private var session: URLSession?
  private var messageBuffer = ""
  private let lock = NSLock()
}

//  Methods
extension StreamSocketClient: SocketClient {
  
  var isConnected: Bool {
    return opened
  }
  
  func open(atHost host: String, forPort port: Int) {
    session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    task = session!.streamTask(withHostName: host, port: port)
    readData()
    task?.resume()
  }
  
  func close() {
    task?.closeRead()
    task?.closeWrite()
    session?.invalidateAndCancel()
  }
  
  func publish(data: Data) {
    task?.write(data, timeout: 0) { [weak self] error in
      if let error = error {
        self?.subscriber?(error, nil)
      }
    }
  }
  
  func subscribe(_ subscriber: @escaping SocketSubscriber) {
    self.subscriber = subscriber
  }
  
  private func readData() {
    task?.readData(ofMinLength: 0, maxLength: Int.max, timeout: 0) { [weak self] data, atEOF, error in
      guard let self = self else { return }
      
      self.lock.lock(); defer { self.lock.unlock() }
      
      if let error = error {
        self.subscriber?(error, nil)
      } else if let data = data, let stringData = String(data: data, encoding: .utf8) {
        
        var fullMessages = (self.messageBuffer + stringData).split(separator: "\n")
        var indicesToRemove = [Int]()

        for (i, stringMessage) in fullMessages.enumerated() {
          if let data = stringMessage.data(using: .utf8),
            let message = try? JSONDecoder().decode(SocketMessage.self, from: data)
          {
            indicesToRemove.append(i)

            if !message.success {
              //  TODO: handle error messages
            } else if message.internal {
              //  TODO: handle internal messages
            } else {
              if let data = message.data {
                self.subscriber?(nil, data)
              }
            }
          }
        }
        
        for i in indicesToRemove where i < fullMessages.count {
          fullMessages.remove(at: i)
        }
        self.messageBuffer = fullMessages.joined()
      }
      
      if !atEOF {
        self.readData()
      }
    }
  }
}

extension StreamSocketClient: URLSessionDelegate, URLSessionTaskDelegate, URLSessionStreamDelegate, URLSessionDataDelegate {
  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    print()
  }
  
  func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
    if let error = error {
      subscriber?(error, nil)
    }
  }
  
  func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
    print()
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    
    if let error = error {
      subscriber?(error, nil)
    }
  }
  
  func urlSession(_ session: URLSession, betterRouteDiscoveredFor streamTask: URLSessionStreamTask) {
    print()
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
    print()
  }
  
  @available(iOS 11.0, *)
  func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
    print()
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
    print()
  }
  
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
    print()
  }
  
}
