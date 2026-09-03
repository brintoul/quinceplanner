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
            RootView()
        }
        .modelContainer(for: [BudgetCategory.self, BudgetExpense.self, ChecklistItem.self, ChecklistNote.self])
    }
}

// Shows a branded splash screen over ContentView for a moment on launch,
// then fades it out — a lightweight, code-only alternative to a static
// system launch screen, since this needs real text/branding rather than
// just a launch image.
private struct RootView: View {
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            ContentView()
            if isShowingSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.4)) {
                isShowingSplash = false
            }
        }
    }
}

// The splash content itself — the Boutique's branding gets top billing
// here since advertising it is as much the point of this app as the
// planning tools are.
private struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.quinceMagenta, .quinceGold], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // Standing in for real Lily's Creations artwork/logo, same
                // as the SF Symbol placeholders used for Boutique products.
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.25))
                        .frame(width: 96, height: 96)
                    Image(systemName: "bag.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 4) {
                    Text("Lily's Creations")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("Quinceañera dresses, crowns & more")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
    }
}
