//
//  PlayPortalGameClient.swift
//  PPSDK-Swift
//
//  Created by Lincoln Fraley on 7/9/19.
//

import Foundation
import AnyCodable

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
  static let turn = GameEndpoints.base + "/turn"
  static let complete = GameEndpoints.base + "/complete"
}


//  Represents a game's metadata and state
public class PlayPortalGame: NSObject, Codable {
  public let id: String
  public let `public`: Bool
  public let users: [PlayPortalProfile]
  private let _data: [String: AnyCodable]
  public let complete: Bool
  public let turn: PlayPortalProfile?
  public private(set) lazy var data: [String: Any] = {
    let d = try! JSONEncoder().encode(_data)
    return try! JSONSerialization.jsonObject(with: d, options: []) as! [String: Any]
  }()
  
  enum CodingKeys: String, CodingKey {
    case id = "id"
    case `public` = "public"
    case users = "users"
    case _data = "data"
    case complete = "complete"
    case turn = "turn"
  }
  
  public static func == (lhs: PlayPortalGame, rhs: PlayPortalGame) -> Bool {
    return lhs.id == rhs.id
      && lhs.users == rhs.users
      && lhs.complete == rhs.complete
      && lhs._data == rhs._data
      && lhs.turn == rhs.turn
  }
}


@objc public protocol PlayPortalGameEventSubscriber: class {
  
  @objc optional func onGameStarted(game: PlayPortalGame)
  @objc optional func onGameUpdated(game: PlayPortalGame)
  @objc optional func onPlayerJoined(game: PlayPortalGame)
  @objc optional func onPlayerLeft(game: PlayPortalGame)
  @objc optional func onTurn(game: PlayPortalGame)
  @objc optional func onError(error: Error)
  
}

enum GameAction: String, Codable {
  
  case start = "start"
  case update = "update"
  case leave = "leave"
  case join = "join"
  case turn = "turn"
}

struct PlayPortalGameEvent: Codable {
  
  let action: GameAction
  let game: PlayPortalGame
}


//  Responsible for making requests to playPORTAL game api
public final class PlayPortalGameClient: PlayPortalHTTPClient {
  
  public static let shared = PlayPortalGameClient()
  let socketClient: SocketClient = StreamSocketClient()
  
  var subscribers = [UInt: PlayPortalGameEventSubscriber]()
  
  deinit {
    EventHandler.shared.unsubscribe(self)
  }
}

//  Methods
extension PlayPortalGameClient {
  
  public func subscribe(_ subscriber: PlayPortalGameEventSubscriber) {
    let id = UInt(bitPattern: ObjectIdentifier(subscriber as AnyObject))
    subscribers[id] = subscriber
  }
  
  public func unsubscribe(_ subscriber: PlayPortalGameEventSubscriber) {
    let id = UInt(bitPattern: ObjectIdentifier(subscriber as AnyObject))
    subscribers[id] = nil
  }
  
  /**
   Request authentication token to open socket connection.
   - Parameter completion: The closure called when the request finishes.
   - Parameter error: The error returned for an unsuccessful request.
   - Parameter token: The token returned for a successful request that allows a socket connection to be opened.
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
    completion: @escaping (_ error: Error?) -> Void)
    -> Void
  {
    guard !socketClient.isConnected else {
      //  todo: handle socket already opened
      return
    }
    
    getToken { error, token in
      guard error == nil,
        let token = token else {
          return completion(error ?? PlayPortalError.Socket.failedToConnect(reason: "Socket authentication failed."))
      }
      
      self.socketClient.subscribe { error, data in
        if let error = error {
          for (_, subscriber) in self.subscribers {
            subscriber.onError?(error: error)
          }
        } else if let data = data,
          JSONSerialization.isValidJSONObject(data),
          let d = try? JSONSerialization.data(withJSONObject: data, options: []),
          let event = try? JSONDecoder().decode(PlayPortalGameEvent.self, from: d)
        {
          switch event.action {
          case .join:
            self.subscribers.forEach { (arg) in let (_, s) = arg; s.onPlayerJoined?(game: event.game) }
            
          case .leave:
            self.subscribers.forEach { (arg) in let (_, s) = arg; s.onPlayerLeft?(game: event.game) }
            
          case .start:
            self.subscribers.forEach { (arg) in let (_, s) = arg; s.onGameStarted?(game: event.game) }
            
          case .turn:
            self.subscribers.forEach { (arg) in let (_, s) = arg; s.onTurn?(game: event.game) }
            
          case .update:
            self.subscribers.forEach { (arg) in let (_, s) = arg; s.onGameUpdated?(game: event.game) }
            
          }
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
  
  public func disconnect() {
    socketClient.close()
  }
  
  public func startGame(
    withUsers users: [String] = [],
    andInitialState state: [String: Codable]? = nil,
    _ completion: ((_ error: Error?, _ game: PlayPortalGame?) -> Void)?
    ) -> Void
  {
    let body: [String: Any?] = [
      "users": users,
      "state": state
    ]

    request(
      url: GameEndpoints.startGame,
      method: .put,
      body: body,
      completionWithDecodableResult: completion
    )
  }
  
  struct UpdateContainer<V: Codable>: Codable {
    
    let gameId: String
    let key: String
    let value: V
  }
  
  public func update<V: Codable>(
    game gameId: String,
    forKey key: String,
    withValue value: V,
    _ completion: ((_ error: Error?, _ game: PlayPortalGame?) -> Void)?
    ) -> Void
  {

    let requestCreator: CreateRequest = {
      var request = self.standardAuthRequestCreator(accessToken: PlayPortalGameClient.accessToken)($0, $1, $2, $3, $4)
      let container = UpdateContainer(gameId: gameId, key: key, value: value)
      request.httpBody = try? JSONEncoder().encode(container)
      return request
    }
    request(
      url: GameEndpoints.update,
      method: .post,
      body: [:],
      createRequest: requestCreator,
      completionWithDecodableResult: completion
    )
  }
  
  public func getAllGames(
    _ completion: ((_ error: Error?, _ gameIds: [PlayPortalGame]?) -> Void)?
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
    _ completion: ((_ error: Error?, _ game: PlayPortalGame?) -> Void)?
    ) -> Void
  {
    let params: [String: Any?] = [
      "gameId": gameId,
      "key": key
    ]

    request(
      url: GameEndpoints.get,
      method: .get,
      queryParameters: params,
      completionWithDecodableResult: completion
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

    request(
      url: GameEndpoints.join,
      method: .post,
      body: body,
      completionWithDecodableResult: completion
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

    request(
      url: GameEndpoints.leave,
      method: .post,
      body: body,
      completionWithDecodableResult: completion
    )
  }
  
  public func passTurn(
    toUser user: String,
    gameId: String,
    _ completion: ((_ error: Error?, _ game: PlayPortalGame?) -> Void)?
    ) -> Void
  {
    let body: [String: Any] = [
      "user": user,
      "gameId": gameId
    ]
    
    request(
      url: GameEndpoints.turn,
      method: .post,
      body: body,
      completionWithDecodableResult: completion
    )
  }
  
  public func completeGame(
    gameId: String,
    _ completion: ((_ error: Error?, _ game: PlayPortalGame?) -> Void)?
    ) -> Void
  {
    let body: [String: Any] = [
      "gameId": gameId,
      "complete": true
    ]
    
    request(
      url: GameEndpoints.complete,
      method: .post,
      body: body,
      completionWithDecodableResult: completion
    )
  }
}

extension PlayPortalGameClient: EventSubscriber {
  
  func on(event: Event) {
    switch event {
    case .loggedOut(_):
      socketClient.close()
    default:
      break
    }
  }
}
