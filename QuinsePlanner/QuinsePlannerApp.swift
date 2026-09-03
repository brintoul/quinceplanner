//
//  QuinsePlannerApp.swift
//  QuinsePlanner
//
//  Created by Bradley Rintoul on 8/28/26.
//

import SwiftUI
import SwiftData

@main
struct QuinsePlannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [BudgetCategory.self, BudgetExpense.self, ChecklistItem.self, ChecklistNote.self, Guest.self])
    }
}
