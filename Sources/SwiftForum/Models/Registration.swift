//
//  Registration.swift
//  SwiftForum
//
//  Created by Amr Aboelela on 2/8/22.
//

import Foundation

public struct Registration: Codable {
    public static let prefix = "registration"
    
    public var isOpen: Bool
    
    public static var isRegistrationOpen: Bool {
        if let registration: Registration = forumDB[prefix] {
            return registration.isOpen
        }
        return true
    }

    public static func changeRegistion(toOpen: Bool) {
        forumDB[Registration.prefix] = Registration(isOpen: toOpen)
    }
}
