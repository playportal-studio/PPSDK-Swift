//
//  SocketClient.swift
//
//  Created by Lincoln Fraley on 6/27/19.
//

import Foundation
import CoreFoundation

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

protocol SocketClient {
  
  var isConnected: Bool { get }
  
  func open(atHost host: String, forPort port: Int)
  func close()
  func publish(data: Data)
  func subscribe(_ subscriber: @escaping (_ data: Any) -> Void)
}


//  `SocketClient` that internally uses `URLSessionStreamTask`
class StreamSocketClient: NSObject {
  
  private var task: URLSessionStreamTask?
  private var subscriber: ((_ data: Any) -> Void)?
  private var opened = false
  private var session: URLSession?
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
    
  }
  
  func publish(data: Data) {
    task?.write(data, timeout: 0) { error in
      if let error = error {
        print("Error writing data to socket: \(error)")
      } else {
        print("Wrote to socket without error")
      }
    }
  }
  
  func subscribe(_ subscriber: @escaping (_ data: Any) -> Void) {
    self.subscriber = subscriber
  }
  
  private func readData() {
    task?.readData(ofMinLength: 0, maxLength: Int.max, timeout: 0) { data, atEOF, error in
      print("reading data")
      if let data = data {
        print("got data")
      }
      if let error = error {
        print("error: \(error)")
      }
      if atEOF {
        
        print("stream at eof")
      } else if let error = error {
        print("stream error: \(error)")
      } else if let data = data {
        print("stream got data")
        self.subscriber?(data)
      } else {
        print("unknown error")
      }
    }
    
  }
}

extension StreamSocketClient: URLSessionDelegate, URLSessionTaskDelegate, URLSessionStreamDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate {
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    print()
  }
  
  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    print()
  }
  
  func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
    print()
  }
  
  func urlSession(_ session: URLSession, readClosedFor streamTask: URLSessionStreamTask) {
    print()
  }
  
  func urlSession(_ session: URLSession, writeClosedFor streamTask: URLSessionStreamTask) {
    print()
  }
  
  func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
    print()
  }
  
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    print()
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    
    if let error = error as? NSError {
      

      print("code: \(error.code)")
      print(error.domain)
    }
  }
  
  func urlSession(_ session: URLSession, betterRouteDiscoveredFor streamTask: URLSessionStreamTask) {
    print()
  }
  
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
    print()
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
    print()
  }
  
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
    print()
  }
  
  func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    print()
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
    print()
  }
  
  func urlSession(_ session: URLSession, streamTask: URLSessionStreamTask, didBecome inputStream: InputStream, outputStream: OutputStream) {
    print()
  }
  
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
    print()
  }
  
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    print()
  }
  
  @available(iOS 11.0, *)
  func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
    print()
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
    print()
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    print()
  }
  
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    print()
  }
  
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
    print()
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    print()
  }
}
