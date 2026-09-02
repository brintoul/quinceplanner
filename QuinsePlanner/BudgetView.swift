//
//  BudgetView.swift
//  QuinsePlanner
//

import SwiftUI
import SwiftData
import Charts

// One line item in the budget — a category like "Venue" or "Dress" with how
// much was planned for it and how much has actually been spent so far.
// Unlike the fixed ProductCategory enum in the Boutique, budget categories
// are fully user-editable since every family's budget breaks down
// differently. This is a SwiftData model so categories survive app restarts.
@Model
final class BudgetCategory {
    var id: UUID
    var name: String
    var icon: String
    // Stored as a name rather than a Color, since Color isn't a type
    // SwiftData can persist directly — `color` below maps it back.
    var colorName: String
    var plannedAmount: Decimal
    var actualAmount: Decimal

    init(id: UUID = UUID(), name: String, icon: String, colorName: String, plannedAmount: Decimal, actualAmount: Decimal) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorName = colorName
        self.plannedAmount = plannedAmount
        self.actualAmount = actualAmount
    }

    var color: Color {
        budgetCategoryColorOptions.first { $0.name == colorName }?.color ?? .quinceMagenta
    }

    // A few starter categories so the screen isn't empty on first launch —
    // inserted once if the store is empty, then the user can rename, delete,
    // or add to them freely.
    static let sampleSeed: [(name: String, icon: String, colorName: String, planned: Decimal, actual: Decimal)] = [
        ("Venue", "building.2.fill", "magenta", 4500, 2000),
        ("Dress", "tshirt.fill", "pink", 600, 600),
        ("Catering", "fork.knife", "gold", 3000, 0),
        ("Photography", "camera.fill", "magenta", 1200, 500),
    ]
}

// A small set of icons/colors to choose from when adding or editing a
// category — keeps the pickers simple instead of exposing every SF Symbol
// or a full color wheel.
private let budgetCategoryIcons = [
    "building.2.fill", "tshirt.fill", "fork.knife", "camera.fill",
    "music.note", "envelope.fill", "car.fill", "paintpalette.fill",
    "crown.fill", "gift.fill", "sparkles", "person.3.fill",
]
private let budgetCategoryColorOptions: [(name: String, color: Color)] = [
    ("magenta", .quinceMagenta), ("pink", .quincePink), ("gold", .quinceGold),
]

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetCategory.name) private var categories: [BudgetCategory]

    // A single scalar like the overall budget target doesn't need its own
    // SwiftData model — UserDefaults via @AppStorage is enough. Stored as
    // Double since AppStorage has no native Decimal support.
    @AppStorage("budgetTotalAmount") private var totalBudgetValue: Double = 15000

    @State private var showingAddSheet = false
    @State private var editingCategory: BudgetCategory?

    private var totalBudget: Decimal { Decimal(totalBudgetValue) }

    private var totalBudgetBinding: Binding<Decimal> {
        Binding(
            get: { totalBudget },
            set: { totalBudgetValue = NSDecimalNumber(decimal: $0).doubleValue }
        )
    }

    private var totalPlanned: Decimal {
        categories.reduce(0) { $0 + $1.plannedAmount }
    }

    private var totalSpent: Decimal {
        categories.reduce(0) { $0 + $1.actualAmount }
    }

    private var spentFraction: CGFloat {
        guard totalBudget > 0 else { return 0 }
        let fraction = NSDecimalNumber(decimal: totalSpent / totalBudget).doubleValue
        return CGFloat(min(max(fraction, 0), 1))
    }

    private var isOverBudget: Bool {
        totalSpent > totalBudget
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.quinceGold.opacity(0.25), Color.quincePink.opacity(0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    ForEach(categories) { category in
                        Button {
                            editingCategory = category
                        } label: {
                            BudgetCategoryRow(category: category)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Budget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .task {
            seedIfNeeded()
        }
        .sheet(isPresented: $showingAddSheet) {
            BudgetCategorySheet(category: nil, onSave: { name, icon, colorName, planned, actual in
                modelContext.insert(
                    BudgetCategory(name: name, icon: icon, colorName: colorName, plannedAmount: planned, actualAmount: actual)
                )
            })
        }
        .sheet(item: $editingCategory) { category in
            BudgetCategorySheet(
                category: category,
                onSave: { name, icon, colorName, planned, actual in
                    category.name = name
                    category.icon = icon
                    category.colorName = colorName
                    category.plannedAmount = planned
                    category.actualAmount = actual
                },
                onDelete: {
                    modelContext.delete(category)
                }
            )
        }
    }

    private func seedIfNeeded() {
        guard categories.isEmpty else { return }
        for seed in BudgetCategory.sampleSeed {
            modelContext.insert(
                BudgetCategory(name: seed.name, icon: seed.icon, colorName: seed.colorName, plannedAmount: seed.planned, actualAmount: seed.actual)
            )
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Total Budget")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                TextField("Total Budget", value: totalBudgetBinding, format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }

            HStack(alignment: .center, spacing: 20) {
                spendDonut
                    .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 10) {
                    summaryStat(title: "Planned", amount: totalPlanned)
                    summaryStat(title: "Spent", amount: totalSpent)
                    summaryStat(title: "Remaining", amount: totalBudget - totalSpent)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(colors: [.quinceMagenta, .quinceGold], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .quinceMagenta.opacity(0.35), radius: 10, y: 5)
    }

    // A donut chart standing in for the old linear progress bar — same
    // spent-vs-remaining story, laid out as two sectors around a ring with
    // the percentage spent in the middle.
    private var spendDonut: some View {
        ZStack {
            Chart {
                SectorMark(
                    angle: .value("Spent", NSDecimalNumber(decimal: totalSpent).doubleValue),
                    innerRadius: .ratio(0.7),
                    angularInset: 1.5
                )
                .foregroundStyle(isOverBudget ? Color.red : Color.white)
                .cornerRadius(3)

                SectorMark(
                    angle: .value("Remaining", max(0, NSDecimalNumber(decimal: totalBudget - totalSpent).doubleValue)),
                    innerRadius: .ratio(0.7),
                    angularInset: 1.5
                )
                .foregroundStyle(.white.opacity(0.25))
                .cornerRadius(3)
            }
            .chartLegend(.hidden)
            .animation(.spring, value: spentFraction)

            Text(spentPercentageLabel)
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
    }

    private var spentPercentageLabel: String {
        "\(Int((spentFraction * 100).rounded()))%"
    }

    private func summaryStat(title: LocalizedStringKey, amount: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            Text(amount, format: .currency(code: "USD"))
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
    }
}

// One colorful card in the budget list, showing a category's spend against
// what was planned for it, with its own little progress bar.
private struct BudgetCategoryRow: View {
    let category: BudgetCategory

    private var progressFraction: CGFloat {
        guard category.plannedAmount > 0 else { return 0 }
        let fraction = NSDecimalNumber(decimal: category.actualAmount / category.plannedAmount).doubleValue
        return CGFloat(min(max(fraction, 0), 1))
    }

    private var isOverPlanned: Bool {
        category.actualAmount > category.plannedAmount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(category.color)
                        .frame(width: 44, height: 44)
                    Image(systemName: category.icon)
                        .foregroundStyle(.white)
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(category.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(category.actualAmount, format: .currency(code: "USD"))
                        .font(.subheadline.bold())
                        .foregroundStyle(isOverPlanned ? .red : .primary)
                    Text("of \(category.plannedAmount, format: .currency(code: "USD"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(category.color.opacity(0.15))
                    Capsule()
                        .fill(isOverPlanned ? Color.red : category.color)
                        .frame(width: geo.size.width * progressFraction)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

// The add/edit form for a single budget category. The same sheet handles
// both cases: `category` is nil when adding (no Delete button shows), or
// pre-filled when editing an existing one. `onSave` hands back plain values
// rather than a whole model instance, since the caller decides whether that
// means inserting a new persisted category or updating an existing one.
private struct BudgetCategorySheet: View {
    let category: BudgetCategory?
    let onSave: (_ name: String, _ icon: String, _ colorName: String, _ plannedAmount: Decimal, _ actualAmount: Decimal) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var icon: String
    @State private var colorName: String
    @State private var plannedAmount: Decimal
    @State private var actualAmount: Decimal

    init(
        category: BudgetCategory?,
        onSave: @escaping (_ name: String, _ icon: String, _ colorName: String, _ plannedAmount: Decimal, _ actualAmount: Decimal) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.category = category
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: category?.name ?? "")
        _icon = State(initialValue: category?.icon ?? budgetCategoryIcons[0])
        _colorName = State(initialValue: category?.colorName ?? budgetCategoryColorOptions[0].name)
        _plannedAmount = State(initialValue: category?.plannedAmount ?? 0)
        _actualAmount = State(initialValue: category?.actualAmount ?? 0)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Name", text: $name)
                    iconPicker
                    colorPicker
                }
                Section("Amounts") {
                    HStack {
                        Text("Planned")
                        Spacer()
                        TextField("Planned", value: $plannedAmount, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Spent so far")
                        Spacer()
                        TextField("Spent", value: $actualAmount, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("Delete Category")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(category == nil ? "Add Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            name.trimmingCharacters(in: .whitespaces),
                            icon,
                            colorName,
                            plannedAmount,
                            actualAmount
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var iconPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(budgetCategoryIcons, id: \.self) { symbol in
                    Button {
                        icon = symbol
                    } label: {
                        ZStack {
                            Circle()
                                .fill(icon == symbol ? AnyShapeStyle(colorForCurrentSelection) : AnyShapeStyle(Color.gray.opacity(0.15)))
                                .frame(width: 40, height: 40)
                            Image(systemName: symbol)
                                .foregroundStyle(icon == symbol ? .white : .primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 12) {
            ForEach(budgetCategoryColorOptions, id: \.name) { option in
                Button {
                    colorName = option.name
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 32, height: 32)
                        .overlay {
                            if colorName == option.name {
                                Circle().stroke(.primary, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var colorForCurrentSelection: Color {
        budgetCategoryColorOptions.first { $0.name == colorName }?.color ?? .quinceMagenta
    }
}
