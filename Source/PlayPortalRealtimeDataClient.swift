//
//  PlayPortalRealtimeDataClient.swift
//  KeychainSwift
//
//  Created by Lincoln Fraley on 6/26/19.
//

import Foundation

//  Responsible for making requests to playPORTAL game api
public final class PlayPortalRealtimeClient: PlayPortalHTTPClient {
  
  public static let shared = PlayPortalRealtimeClient()
  let socketClient: SocketClient = StreamSocketClient()
  
  private override init() {
    
  }
}


//  Methods
extension PlayPortalRealtimeClient {
  
  /**
   Request authentication token to open socket connection.
   - Parameter completion: The closure called when the request finishes.
   - Parameter error: The error returned for an unsuccessful request.
   */
  func getToken(
    completion: @escaping (_ error: Error?, _ token: String?) -> Void)
    -> Void
  {
    
    let handleSuccess: HandleSuccess<String> = { response, data in
      guard let json = (try JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
        , let token = json["token"] as? String
        else {
          throw PlayPortalError.API.unableToDeserializeResult(message: "Unable to deserialize socket token.")
      }
      
      return token
    }
    
    request(
      url: GameEndpoints.token,
      method: .get,
      handleSuccess: handleSuccess,
      completionWithDecodableResult: completion
    )
  }
  
  public func connect(
    completion: @escaping (_ error: Error?, _ sessionId: String?) -> Void)
    -> Void
  {
    guard !socketClient.isConnected else {
      //  todo: handle socket already opened
      return
    }
    
    getToken { error, token in
      guard error == nil,
        let token = token else {
          return completion(error ?? PlayPortalError.Socket.failedToConnect(reason: "Request for socket authentication token failed."), nil)
      }
      
      self.socketClient.subscribe { message in
        if let message = message as? [String: Any] {
          print("got socket message")
          print(message)
        } else {
          print("message was not dictionary")
        }
      }
      
      self.socketClient.open(atHost: SocketConfiguration.host, forPort: SocketConfiguration.port)
      
      let authenticationMessage = [
        "type": "authenticate",
        "data": token
      ]
      
      guard let jsonString = authenticationMessage.toJSONString(),
        let data = jsonString.data(using: .utf8) else {
        //  todo: handle this
        return
      }
      
      self.socketClient.publish(data: data)
    }
  }
}
