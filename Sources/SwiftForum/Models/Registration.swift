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
    
    public static func isRegistrationOpen() async -> Bool {
        if let registration: Registration = await database.value(forKey: prefix) {
            return registration.isOpen
        }
        return true
    }

    public static func changeRegistration(toOpen: Bool) async {
        try? await database.setValue(Registration(isOpen: toOpen), forKey: Registration.prefix)
    }
}
