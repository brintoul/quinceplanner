//
//  OnboardingView.swift
//  QuincePlanner
//

import SwiftUI

// A curated set of party color choices — this is the quinceañera's own
// color scheme (like a wedding's colors), not the app's fixed pink/magenta/
// gold branding. Stored as a name string rather than a Color, same reason
// BudgetCategory.colorName is a string: Color isn't AppStorage-storable.
private let partyThemeColorOptions: [(name: String, color: Color)] = [
    ("Pink", .quincePink),
    ("Magenta", .quinceMagenta),
    ("Gold", .quinceGold),
    ("Turquoise", Color(red: 0.20, green: 0.70, blue: 0.70)),
    ("Purple", Color(red: 0.55, green: 0.35, blue: 0.75)),
    ("Coral", Color(red: 0.95, green: 0.45, blue: 0.40)),
    ("Silver", Color(red: 0.75, green: 0.75, blue: 0.78)),
]

// A one-time, skippable wizard shown on first launch (see RootView in
// QuincePlannerApp.swift) to collect the basics: party date, budget, the
// quinceañera's name, an estimated guest count, and a party color. Every
// field is a live @AppStorage binding, so partial answers stick even if the
// user skips out partway through — nothing is buffered until a final save.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSetPartyDate") private var hasSetPartyDate = false
    @AppStorage("partyDateValue") private var partyDateValue: Double = Date().timeIntervalSinceReferenceDate

    // Reuses BudgetView's own key so the amount entered here is exactly the
    // Budget section's target amount — not a separate value to keep in sync.
    @AppStorage("budgetTotalAmount") private var totalBudgetValue: Double = 15000

    @AppStorage("quinceaneraName") private var quinceaneraName: String = ""
    @AppStorage("guestCountEstimate") private var guestCountEstimate: Int = 0
    @AppStorage("partyThemeColorName") private var partyThemeColorName: String = ""

    @State private var step = 0

    private let totalSteps = 7

    private var partyDateBinding: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: partyDateValue) },
            set: { partyDateValue = $0.timeIntervalSinceReferenceDate; hasSetPartyDate = true }
        )
    }

    private var totalBudget: Decimal { Decimal(totalBudgetValue) }

    private var totalBudgetBinding: Binding<Decimal> {
        Binding(
            get: { totalBudget },
            set: { totalBudgetValue = NSDecimalNumber(decimal: $0).doubleValue }
        )
    }

    private var actionTitle: LocalizedStringKey {
        step == totalSteps - 1 ? "Get Started" : "Continue"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.quincePink.opacity(0.3), Color.quinceGold.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    if step > 0 {
                        Button("Back") { withAnimation { step -= 1 } }
                            .foregroundStyle(.quinceMagenta)
                    }
                    Spacer()
                    if step < totalSteps - 1 {
                        Button("Skip") { finish() }
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .frame(height: 32)

                progressDots
                    .padding(.top, 12)

                ScrollView {
                    stepContent
                        .padding()
                        .frame(maxWidth: .infinity)
                }

                Button(actionTitle) {
                    if step < totalSteps - 1 {
                        withAnimation { step += 1 }
                    } else {
                        finish()
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(colors: [.quinceMagenta, .quinceGold], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .padding()
            }
        }
    }

    private func finish() {
        hasCompletedOnboarding = true
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == step ? Color.quinceMagenta : Color.quinceMagenta.opacity(0.2))
                    .frame(width: index == step ? 20 : 8, height: 8)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: welcomeStep
        case 1: partyDateStep
        case 2: budgetStep
        case 3: nameStep
        case 4: guestCountStep
        case 5: themeStep
        default: summaryStep
        }
    }

    private func stepIcon(_ systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.quinceMagenta, .quinceGold], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 84, height: 84)
                .shadow(color: .quinceMagenta.opacity(0.4), radius: 8, y: 4)
            Image(systemName: systemName)
                .font(.system(size: 36))
                .foregroundStyle(.white)
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            stepIcon("birthday.cake.fill")
            Text("Welcome to Quince Planner!")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Let's get a few details about the celebration so we can help you plan. You can skip any step and fill it in later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var partyDateStep: some View {
        VStack(spacing: 20) {
            stepIcon("calendar")
            Text("When's the big day?")
                .font(.title2.bold())
            DatePicker("Party Date", selection: partyDateBinding, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(.quinceMagenta)
        }
    }

    private var budgetStep: some View {
        VStack(spacing: 20) {
            stepIcon("dollarsign.circle.fill")
            Text("What's your budget?")
                .font(.title2.bold())
            Text("You can always adjust this later in the Budget section.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            TextField("Total Budget", value: totalBudgetBinding, format: .currency(code: "USD"))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.title.bold())
                .padding()
                .background(.white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var nameStep: some View {
        VStack(spacing: 20) {
            stepIcon("crown.fill")
            Text("Who's the guest of honor?")
                .font(.title2.bold())
            TextField("Quinceañera's Name", text: $quinceaneraName)
                .textInputAutocapitalization(.words)
                .multilineTextAlignment(.center)
                .font(.title3)
                .padding()
                .background(.white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var guestCountStep: some View {
        VStack(spacing: 20) {
            stepIcon("person.3.fill")
            Text("About how many guests?")
                .font(.title2.bold())
            Text("\(guestCountEstimate)")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.quinceMagenta)
            Stepper("Guests", value: $guestCountEstimate, in: 0...500, step: 5)
                .labelsHidden()
                .padding(.horizontal, 40)
        }
    }

    private var themeStep: some View {
        VStack(spacing: 20) {
            stepIcon("paintpalette.fill")
            Text("Pick a party color")
                .font(.title2.bold())
            Text("This helps tailor suggestions later on.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 16) {
                ForEach(partyThemeColorOptions, id: \.name) { option in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(option.color)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle().stroke(Color.primary, lineWidth: partyThemeColorName == option.name ? 3 : 0)
                            )
                        Text(LocalizedStringKey(option.name))
                            .font(.caption)
                    }
                    .onTapGesture {
                        partyThemeColorName = option.name
                    }
                }
            }
        }
    }

    private var summaryStep: some View {
        VStack(spacing: 20) {
            stepIcon("sparkles")
            Text("You're all set!")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 12) {
                if !quinceaneraName.isEmpty {
                    summaryRow(icon: "crown.fill", text: quinceaneraName)
                }
                if hasSetPartyDate {
                    summaryRow(
                        icon: "calendar",
                        text: Date(timeIntervalSinceReferenceDate: partyDateValue).formatted(date: .long, time: .omitted)
                    )
                }
                summaryRow(icon: "dollarsign.circle.fill", text: totalBudget.formatted(.currency(code: "USD")))
                if guestCountEstimate > 0 {
                    summaryRow(icon: "person.3.fill", text: "About \(guestCountEstimate) guests")
                }
                if !partyThemeColorName.isEmpty {
                    summaryRow(icon: "paintpalette.fill", text: partyThemeColorName)
                }
            }
            .padding()
            .background(.white.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("You can change any of this later in the app.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func summaryRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.quinceMagenta)
                .frame(width: 24)
            Text(text)
        }
    }
}
