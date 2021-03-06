//
//  PlayPortalProfile.swift
//
//  Created by Lincoln Fraley on 10/24/18.
//

import Foundation

//  Struct representing a playPORTAL user's profile.
public struct PlayPortalProfile: Codable {
  
  public let userId: String
  public let userType: UserType
  public let accountType: AccountType
  public let handle: String
  public var firstName: String?
  public var lastName: String?
  public var profilePic: String?
  public var coverPhoto: String?
  public let country: String
  private var _anonymous: Bool?
  public var anonymous: Bool {
    return _anonymous ?? false
  }
  
  private enum CodingKeys: String, CodingKey {
    case userId
    case userType
    case accountType
    case handle
    case firstName
    case lastName
    case profilePic
    case coverPhoto
    case country
    case _anonymous = "anonymous"
  }
  
  private init() {
    fatalError("`PlayPortalProfile` instances should only be initialized by decoding.")
  }
  
  //  Represents possible playPORTAL user types
  public enum UserType: String, Codable {
    case adult = "adult"
    case child = "child"
    case teenMinor = "teen-minor"
  }
  
  //  Represents possible playPORTAL account types
  public enum AccountType: String, Codable {
    case parent = "Parent"
    case kid = "Kid"
    case adult = "Adult"
    case character = "Character"
    case community = "Community"
  }
}

extension PlayPortalProfile: Equatable {
  
  public static func ==(lhs: PlayPortalProfile, rhs: PlayPortalProfile) -> Bool {
    return lhs.userId == rhs.userId
  }
}
