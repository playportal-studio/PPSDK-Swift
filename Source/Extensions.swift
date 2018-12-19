//
//  Extensions.swift
//
//  Created by Lincoln Fraley on 11/8/18.
//

import Foundation

//  MARK: - Data
extension Data {
    
    var asJSON: [String: Any]? {
        get {
            guard let json = try? JSONSerialization.jsonObject(with: self, options: []) else { return nil }
            return json as? [String: Any]
        }
    }
    
    var asJSONArray: [[String: Any]]? {
        get {
            guard let json = try? JSONSerialization.jsonObject(with: self, options: [])
                , let array = json as? [Any]
                else {
                    return nil
            }
            return array.compactMap { $0 as? [String: Any] }
        }
    }
    
    func asDecodable<D: Decodable>(type: D.Type) -> D? {
        return try? JSONDecoder().decode(type, from: self)
    }
}

extension Dictionary {
    
    func valueAtNestedKey(_ keyPath: [Key]) -> Any? {
        guard !keyPath.isEmpty else { return nil }
        var result: Any? = self
        for key in keyPath {
            if let element = (result as? [Key: Any])?[key] {
                result = element
            } else {
                return nil
            }
        }
        return result
    }
    
    func asDecodable<D: Decodable>(type: D.Type) -> D? {
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: []) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}


//  MARK: - Encodable
extension Encodable {
    
    var asDictionary: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] }
    }
}

//  MARK: - Sequence
extension Sequence {
    
    func matches<T>(type: T.Type) -> Bool {
        return allSatisfy { $0 is T }
    }
}


//  MARK: - URL
extension URL {
    
    func getParameter(for name: String) -> String? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return nil
        }
        return components.queryItems?.first { $0.name == name }?.value
    }
}


//  MARK: - UIApplication
extension UIApplication {
    
    class func topMostViewController(controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topMostViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topMostViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topMostViewController(controller: presented)
        }
        return controller
    }
}


//  MARK: - UIImageView
public extension UIImageView {
    
    /**
     Get playPORTAL image by id and set as `UIImageView.image`.
     
     - Parameter forImageId: Id corresponding to playPORTAL image.
     - Parameter completion: The closure called when the request finishes.
     - Parameter error: The error returned for an unsuccessful request.
     
     - Returns: Void
     */
    func playPortalImage(forImageId imageId: String?, _ completion: ((_ error: Error?) -> Void)?) -> Void {
        guard let imageId = imageId else {
            completion?(nil)
            return
        }
        PlayPortalImage.shared.getImage(forImageId: imageId) { [weak self] error, data in
            self?.image = data.map { UIImage(data: $0) } ?? nil
            completion?(error)
        }
    }
    
    /**
     Get playPORTAL profile pic by id and set as `UIImageView.image`.
     If profile pic id is nil or the image is unable to be requested, will use a default image.
     
     - Parameter forImageId: Id corresponding to the playPORTAL user's profile pic; if image is nil, use a default image.
     - Parameter completion: The closure called when the request finishes.
     - Parameter error: The error returned for an unsuccessful request.
     
     - Returns: Void
     */
    func playPortalProfilePic(forImageId imageId: String?, _ completion: ((_ error: Error?) -> Void)?) -> Void {
        guard let imageId = imageId else {
            image = Utils.getImageAsset(byName: "anonUser")
            completion?(nil)
            return
        }
        PlayPortalImage.shared.getImage(forImageId: imageId) { [weak self] error, data in
            self?.image = data.map { UIImage(data: $0) } ?? Utils.getImageAsset(byName: "anonUser")
            completion?(error)
        }
    }
    
    /**
     Get playPORTAL cover photo by id and set as `UIImageView.image`.
     If cover photo id is nil or the image is unable to be requested, will use a default image.
     
     - Parameter forImageId: Id corresponding to the playPORTAL user's cover photo; if image is nil, use a default image.
     - Parameter completion: The closure called when the request finishes.
     - Parameter error: The error returned for an unsuccessful request.
     
     - Returns: Void
     */
    func playPortalCoverPhoto(forImageId imageId: String?, _ completion: ((_ error: Error?) -> Void)?) -> Void {
        guard let imageId = imageId else {
            image = Utils.getImageAsset(byName: "anonUserCover")
            completion?(nil)
            return
        }
        PlayPortalImage.shared.getImage(forImageId: imageId) { [weak self] error, data in
            self?.image = data.map { UIImage(data: $0) } ?? Utils.getImageAsset(byName: "anonUserCover")
            completion?(error)
        }
    }
}
