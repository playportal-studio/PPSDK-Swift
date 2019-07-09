//
//  PlayPortalGameClient.swift
//  PPSDK-Swift
//
//  Created by Lincoln Fraley on 7/9/19.
//

import Foundation

//  Available game endpoints
class GameEndpoints: EndpointsBase {
  
  private static let base = GameEndpoints.host + "/game/v1"
  
  static let token = GameEndpoints.base + "/token"
  static let startGame = GameEndpoints.base + "/start"
  static let update = GameEndpoints.base + "/update"
  static let list = GameEndpoints.base + "/list"
  static let get = GameEndpoints.base
  static let join = GameEndpoints.base + "/join"
  static let leave = GameEndpoints.base + "/leave"
  static let event = GameEndpoints.base + "/event"
}


//  Represents a game's metadata and state
public struct PlayPortalGame {
  
  public let id: String
  public let isPublic: Bool
  public let users: [String]
  public let data: [String: Any]
  
  init?(_ json: Any) {
    guard let json = json as? [String: Any] else { return nil }
    
    guard let users = json["users"] as? [String] else { return nil}
    guard let id = json["id"] as? String else { return nil}
    guard let isPublic = json["public"] as? Bool else { return nil }
    guard let data = json["data"] as? [String: Any] else { return nil }
    
    self.id = id
    self.isPublic = isPublic
    self.users = users
    self.data = data
  }
}


//  Responsible for making requests to playPORTAL game api
public final class PlayPortalGameClient: PlayPortalHTTPClient {
  
  public static let shared = PlayPortalGameClient()
  
  private override init() {}
  
  
}


extension PlayPortalGameClient {
  
  public func startGame(
    withUsers users: [String] = [],
    andInitialState state: [String: Codable]? = nil,
    _ completion: @escaping (_ error: Error?, _ game: PlayPortalGame?) -> Void
    ) -> Void
  {
    let body: [String: Any?] = [
      "users": users,
      "state": state
    ]
    
    let handleSuccess: HandleSuccess<PlayPortalGame> = { response, data in
      guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
        let game = PlayPortalGame(json)
        else {
          throw PlayPortalError.API.unableToDeserializeResult(message: "Couldn't deserialize `PlayPortalGame` instance.")
      }
      return game
    }

    request(
      url: GameEndpoints.startGame,
      method: .put,
      body: body,
      handleSuccess: handleSuccess,
      completionWithResult: completion
    )
  }
  
  public func update<V: Codable>(
    game gameId: String,
    forKey key: String,
    withValue value: V,
    _ completion: @escaping (_ error: Error?, _ game: PlayPortalGame?) -> Void
    ) -> Void
  {
    let body: [String: Any] = [
      "gameId": gameId,
      "key": key,
      "value": value
    ]
    
    let handleSuccess: HandleSuccess<PlayPortalGame> = { response, data in
      guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
        let game = PlayPortalGame(json)
        else {
          throw PlayPortalError.API.unableToDeserializeResult(message: "Couldn't deserialize `PlayPortalGame` instance.")
      }
      return game
    }

    request(
      url: GameEndpoints.update,
      method: .post,
      body: body,
      handleSuccess: handleSuccess,
      completionWithResult: completion
    )
  }
  
  public func getAllGames(
    _ completion: @escaping (_ error: Error?, _ gameIds: [String]?) -> Void
    )
  {
    request(
      url: GameEndpoints.list,
      method: .get,
      completionWithDecodableResult: completion
    )
  }
  
  public func getGame(
    gameId: String,
    atKey key: String? = nil,
    _ completion: @escaping (_ error: Error?, _ game: PlayPortalGame?) -> Void
    ) -> Void
  {
    let params: [String: Any?] = [
      "gameId": gameId,
      "key": key
    ]
    
    let handleSuccess: HandleSuccess<PlayPortalGame> = { response, data in
      guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
        let game = PlayPortalGame(json)
        else {
          throw PlayPortalError.API.unableToDeserializeResult(message: "Couldn't deserialize `PlayPortalGame` instance.")
      }
      return game
    }

    request(
      url: GameEndpoints.get,
      method: .get,
      queryParameters: params,
      handleSuccess: handleSuccess,
      completionWithResult: completion
    )
  }
  
  public func joinGame(
    gameId: String,
    _ completion: ((_ error: Error?, _ game: PlayPortalGame?) -> Void)?
    ) -> Void
  {
    let body: [String: Any] = [
      "gameId": gameId
    ]
    
    let handleSuccess: HandleSuccess<PlayPortalGame> = { response, data in
      guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
        let game = PlayPortalGame(json)
        else {
          throw PlayPortalError.API.unableToDeserializeResult(message: "Couldn't deserialize `PlayPortalGame` instance.")
      }
      return game
    }
    
    request(
      url: GameEndpoints.join,
      method: .post,
      body: body,
      handleSuccess: handleSuccess,
      completionWithResult: completion
    )
  }
  
  public func leaveGame(
    gameId: String,
    remove: Bool,
    _ completion: ((_ error: Error?, _ game: PlayPortalGame?) -> Void)?
    ) -> Void
  {
    let body: [String: Any] = [
      "gameId": gameId,
      "remove": remove
    ]
    
    let handleSuccess: HandleSuccess<PlayPortalGame> = { response, data in
      guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
        let game = PlayPortalGame(json)
        else {
          throw PlayPortalError.API.unableToDeserializeResult(message: "Couldn't deserialize `PlayPortalGame` instance.")
      }
      return game
    }
    
    request(
      url: GameEndpoints.leave,
      method: .post,
      body: body,
      handleSuccess: handleSuccess,
      completionWithResult: completion
    )
  }
}

