//
//  EnclosureApp.swift
//  Enclosure
//
//  Created by Ram Lohar on 14/03/25.
//

import SwiftUI

@main
struct EnclosureApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
