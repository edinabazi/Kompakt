//
//  KompaktApp.swift
//  Kompakt
//
//  Created by edin on 16/05/2026.
//

import SwiftUI

@main
struct KompaktApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel.shared

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appModel)
        }
    }
}
