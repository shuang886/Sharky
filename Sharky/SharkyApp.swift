//
//  SharkyApp.swift
//  Sharky
//
//  Created by Steven Huang on 9/14/23.
//

import SwiftUI

@main
struct SharkyApp: App {
    var body: some Scene {
        Window("", id: "main") {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
