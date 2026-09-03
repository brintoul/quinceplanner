//
//  BudgetView.swift
//  QuinsePlanner
//

import SwiftUI
import SwiftData
import Charts
import PhotosUI
import UIKit

// One line item in the budget — a category like "Venue" or "Dress" with a
// planned amount and a list of the individual expenses charged against it.
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

    // Cascade so deleting a category takes its expenses (and any receipt
    // photos attached to them) with it.
    @Relationship(deleteRule: .cascade, inverse: \BudgetExpense.category)
    var expenses: [BudgetExpense] = []

    init(id: UUID = UUID(), name: String, icon: String, colorName: String, plannedAmount: Decimal) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorName = colorName
        self.plannedAmount = plannedAmount
    }

    var color: Color {
        budgetCategoryColorOptions.first { $0.name == colorName }?.color ?? .quinceMagenta
    }

    // Spend is derived from actual expenses rather than typed in manually,
    // so it can never drift from what's actually been logged.
    var totalSpent: Decimal {
        expenses.reduce(0) { $0 + $1.amount }
    }

    // A few starter categories so the screen isn't empty on first launch —
    // inserted once if the store is empty, then the user can rename, delete,
    // or add to them freely. A couple come with one starter expense so the
    // demo shows a mix of spent and unspent categories.
    static let sampleSeed: [(name: String, icon: String, colorName: String, planned: Decimal, starterExpense: (note: String, amount: Decimal)?)] = [
        ("Venue", "building.2.fill", "magenta", 4500, ("Deposit", 2000)),
        ("Dress", "tshirt.fill", "pink", 600, ("Full payment", 600)),
        ("Catering", "fork.knife", "gold", 3000, nil),
        ("Photography", "camera.fill", "magenta", 1200, ("Booking deposit", 500)),
    ]
}

// A single payment charged against a category — the thing a receipt photo
// actually belongs to (a category like "Catering" might have a deposit and
// a final payment, each with its own receipt).
@Model
final class BudgetExpense {
    var id: UUID
    var note: String
    var amount: Decimal
    var date: Date
    // externalStorage keeps large photo data out of the main SQLite row.
    @Attribute(.externalStorage) var receiptImageData: Data?
    var category: BudgetCategory?

    init(id: UUID = UUID(), note: String, amount: Decimal, date: Date = .now, receiptImageData: Data? = nil, category: BudgetCategory? = nil) {
        self.id = id
        self.note = note
        self.amount = amount
        self.date = date
        self.receiptImageData = receiptImageData
        self.category = category
    }
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

// Receipt photos are downscaled before being persisted so we're not storing
// multi-megabyte camera originals for what only needs to be legible later.
private func downscaledJPEGData(from data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.8) -> Data? {
    guard let image = UIImage(data: data) else { return nil }
    let scale = min(1, maxDimension / max(image.size.width, image.size.height))
    guard scale < 1 else { return image.jpegData(compressionQuality: quality) }
    let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    return resized.jpegData(compressionQuality: quality)
}

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetCategory.name) private var categories: [BudgetCategory]

    // A single scalar like the overall budget target doesn't need its own
    // SwiftData model — UserDefaults via @AppStorage is enough. Stored as
    // Double since AppStorage has no native Decimal support.
    @AppStorage("budgetTotalAmount") private var totalBudgetValue: Double = 15000

    @State private var showingAddSheet = false

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
        categories.reduce(0) { $0 + $1.totalSpent }
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
                        NavigationLink {
                            BudgetCategoryDetailView(category: category)
                        } label: {
                            BudgetCategoryRow(category: category)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                modelContext.delete(category)
                            } label: {
                                Label("Delete Category", systemImage: "trash")
                            }
                        }
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
            BudgetCategorySheet(category: nil, onSave: { name, icon, colorName, planned in
                modelContext.insert(
                    BudgetCategory(name: name, icon: icon, colorName: colorName, plannedAmount: planned)
                )
            })
        }
    }

    private func seedIfNeeded() {
        guard categories.isEmpty else { return }
        for seed in BudgetCategory.sampleSeed {
            let category = BudgetCategory(name: seed.name, icon: seed.icon, colorName: seed.colorName, plannedAmount: seed.planned)
            modelContext.insert(category)
            if let starterExpense = seed.starterExpense {
                modelContext.insert(
                    BudgetExpense(note: starterExpense.note, amount: starterExpense.amount, category: category)
                )
            }
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

    // A donut chart standing in for the old linear progress bar — one
    // sector per category (in that category's own color) so it doubles as
    // a spend breakdown, plus a remaining sector, with the percentage
    // spent overall in the middle.
    private var spendDonut: some View {
        ZStack {
            Chart {
                ForEach(categoriesWithSpend) { category in
                    SectorMark(
                        angle: .value(category.name, NSDecimalNumber(decimal: category.totalSpent).doubleValue),
                        innerRadius: .ratio(0.7),
                        angularInset: 1.5
                    )
                    .foregroundStyle(category.color)
                    .cornerRadius(3)
                }

                if remainingBudget > 0 {
                    SectorMark(
                        angle: .value("Remaining", NSDecimalNumber(decimal: remainingBudget).doubleValue),
                        innerRadius: .ratio(0.7),
                        angularInset: 1.5
                    )
                    .foregroundStyle(.white.opacity(0.25))
                    .cornerRadius(3)
                }
            }
            .chartLegend(.hidden)
            .animation(.spring, value: spentFraction)

            Text(spentPercentageLabel)
                .font(.caption.bold())
                .foregroundStyle(isOverBudget ? .red : .white)
        }
    }

    // Zero-spend categories are left out so the chart doesn't render
    // degenerate slivers for money that hasn't been spent yet.
    private var categoriesWithSpend: [BudgetCategory] {
        categories.filter { $0.totalSpent > 0 }
    }

    private var remainingBudget: Decimal {
        max(0, totalBudget - totalSpent)
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
        let fraction = NSDecimalNumber(decimal: category.totalSpent / category.plannedAmount).doubleValue
        return CGFloat(min(max(fraction, 0), 1))
    }

    private var isOverPlanned: Bool {
        category.totalSpent > category.plannedAmount
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
                    Text(category.totalSpent, format: .currency(code: "USD"))
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

// A category's own screen: its planned/spent/remaining totals up top, and
// the list of individual expenses (each optionally carrying a receipt
// photo) that make up its spend below.
private struct BudgetCategoryDetailView: View {
    let category: BudgetCategory

    @Environment(\.modelContext) private var modelContext
    @State private var showingEditSheet = false
    @State private var showingAddExpenseSheet = false
    @State private var editingExpense: BudgetExpense?

    private var sortedExpenses: [BudgetExpense] {
        category.expenses.sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [category.color.opacity(0.25), Color.quinceGold.opacity(0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            List {
                Section {
                    categorySummary
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                Section("Expenses") {
                    if sortedExpenses.isEmpty {
                        Text("No expenses yet.")
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.white.opacity(0.7))
                    } else {
                        ForEach(sortedExpenses) { expense in
                            Button {
                                editingExpense = expense
                            } label: {
                                BudgetExpenseRow(expense: expense)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.white.opacity(0.7))
                            .swipeActions {
                                Button(role: .destructive) {
                                    modelContext.delete(expense)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit Category", systemImage: "pencil")
                    }
                    Button {
                        showingAddExpenseSheet = true
                    } label: {
                        Label("Add Expense", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            BudgetCategorySheet(category: category, onSave: { name, icon, colorName, planned in
                category.name = name
                category.icon = icon
                category.colorName = colorName
                category.plannedAmount = planned
            })
        }
        .sheet(isPresented: $showingAddExpenseSheet) {
            BudgetExpenseSheet(expense: nil, onSave: { note, amount, date, receiptImageData in
                modelContext.insert(
                    BudgetExpense(note: note, amount: amount, date: date, receiptImageData: receiptImageData, category: category)
                )
            })
        }
        .sheet(item: $editingExpense) { expense in
            BudgetExpenseSheet(
                expense: expense,
                onSave: { note, amount, date, receiptImageData in
                    expense.note = note
                    expense.amount = amount
                    expense.date = date
                    expense.receiptImageData = receiptImageData
                },
                onDelete: {
                    modelContext.delete(expense)
                }
            )
        }
    }

    private var categorySummary: some View {
        HStack {
            summaryStat(title: "Planned", amount: category.plannedAmount)
            Spacer()
            summaryStat(title: "Spent", amount: category.totalSpent)
            Spacer()
            summaryStat(title: "Remaining", amount: category.plannedAmount - category.totalSpent)
        }
        .padding(20)
        .background(
            LinearGradient(colors: [category.color, .quinceGold], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: category.color.opacity(0.35), radius: 10, y: 5)
        .padding(.horizontal)
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

// One expense row, showing its receipt thumbnail (or a placeholder if none
// was attached), note, date, and amount.
private struct BudgetExpenseRow: View {
    let expense: BudgetExpense

    var body: some View {
        HStack(spacing: 12) {
            if let data = expense.receiptImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "receipt")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.note)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(expense.date, format: .dateTime.month().day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(expense.amount, format: .currency(code: "USD"))
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }
}

// The add/edit form for a single budget category. The same sheet handles
// both cases: `category` is nil when adding, or pre-filled when editing an
// existing one. `onSave` hands back plain values rather than a whole model
// instance, since the caller decides whether that means inserting a new
// persisted category or updating an existing one. Deleting a category
// happens from its row in the list (long-press), not from this sheet.
private struct BudgetCategorySheet: View {
    let category: BudgetCategory?
    let onSave: (_ name: String, _ icon: String, _ colorName: String, _ plannedAmount: Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var icon: String
    @State private var colorName: String
    @State private var plannedAmount: Decimal

    init(
        category: BudgetCategory?,
        onSave: @escaping (_ name: String, _ icon: String, _ colorName: String, _ plannedAmount: Decimal) -> Void
    ) {
        self.category = category
        self.onSave = onSave
        _name = State(initialValue: category?.name ?? "")
        _icon = State(initialValue: category?.icon ?? budgetCategoryIcons[0])
        _colorName = State(initialValue: category?.colorName ?? budgetCategoryColorOptions[0].name)
        _plannedAmount = State(initialValue: category?.plannedAmount ?? 0)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        Text("Planned")
                        Spacer()
                        TextField("Planned", value: $plannedAmount, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section("Category") {
                    TextField("Name", text: $name)
                    iconPicker
                    colorPicker
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
                            plannedAmount
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

// The add/edit form for a single expense within a category — an amount,
// a note, a date, and an optional receipt photo picked from the library.
private struct BudgetExpenseSheet: View {
    let expense: BudgetExpense?
    let onSave: (_ note: String, _ amount: Decimal, _ date: Date, _ receiptImageData: Data?) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var note: String
    @State private var amount: Decimal
    @State private var date: Date
    @State private var receiptImageData: Data?
    @State private var selectedPhoto: PhotosPickerItem?

    init(
        expense: BudgetExpense?,
        onSave: @escaping (_ note: String, _ amount: Decimal, _ date: Date, _ receiptImageData: Data?) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.expense = expense
        self.onSave = onSave
        self.onDelete = onDelete
        _note = State(initialValue: expense?.note ?? "")
        _amount = State(initialValue: expense?.amount ?? 0)
        _date = State(initialValue: expense?.date ?? .now)
        _receiptImageData = State(initialValue: expense?.receiptImageData)
    }

    private var isValid: Bool {
        !note.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense") {
                    TextField("Note", text: $note)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("Amount", value: $amount, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Receipt") {
                    receiptPicker
                }

                if let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("Delete Expense")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(expense == nil ? "Add Expense" : "Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            note.trimmingCharacters(in: .whitespaces),
                            amount,
                            date,
                            receiptImageData
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    receiptImageData = downscaledJPEGData(from: data)
                }
            }
        }
    }

    private var receiptPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let receiptImageData, let uiImage = UIImage(data: receiptImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button(role: .destructive) {
                    self.receiptImageData = nil
                    selectedPhoto = nil
                } label: {
                    Text("Remove Receipt")
                }
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(
                    receiptImageData == nil ? "Add Receipt Photo" : "Replace Receipt Photo",
                    systemImage: "photo.on.rectangle"
                )
            }
        }
    }
}
