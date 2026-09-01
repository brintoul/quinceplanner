//
//  ContentView.swift
//  QuinsePlanner
//
//  Created by Bradley Rintoul on 8/28/26.
//

import SwiftUI

// A reusable color palette. Keeping named colors in one place means every
// screen we add later can share the same pink/magenta/gold theme.
extension Color {
    static let quinceMagenta = Color(red: 0.80, green: 0.16, blue: 0.48)
    static let quincePink = Color(red: 0.98, green: 0.55, blue: 0.73)
    static let quinceGold = Color(red: 0.86, green: 0.67, blue: 0.20)
}

// SwiftUI resolves shorthand like `.foregroundStyle(.quinceMagenta)` against
// the ShapeStyle protocol, not against Color directly — that's why built-in
// colors like `.red` work that way. This extension makes our custom colors
// work the same way, anywhere a ShapeStyle is expected.
extension ShapeStyle where Self == Color {
    static var quinceMagenta: Color { .quinceMagenta }
    static var quincePink: Color { .quincePink }
    static var quinceGold: Color { .quinceGold }
}

// The home screen: a title header plus a grid of colorful cards, one per
// section of the app. Each card is a NavigationLink, so tapping it pushes
// that section onto the NavigationStack declared here.
struct ContentView: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.quincePink.opacity(0.25), Color.quinceGold.opacity(0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        homeHeader

                        FeaturedCard(
                            title: "The Boutique",
                            subtitle: "by Lily's Creations",
                            icon: "bag.fill"
                        ) {
                            BoutiqueView()
                        }

                        LazyVGrid(columns: columns, spacing: 16) {
                            MenuCard(title: "Checklist", icon: "checklist", color: .quinceMagenta) {
                                ChecklistView()
                            }
                            MenuCard(title: "Guest List", icon: "person.3.fill", color: .quincePink) {
                                GuestListView()
                            }
                            MenuCard(title: "Budget", icon: "dollarsign.circle.fill", color: .quinceGold) {
                                BudgetView()
                            }
                            MenuCard(title: "Vendors", icon: "storefront.fill", color: .quinceMagenta) {
                                VendorsView()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Quince Planner")
            .navigationBarTitleDisplayMode(.inline)
        }
        // .tint sets the app's accent color via the environment, so it
        // cascades to every pushed screen too — back buttons, links, etc.
        // all use quinceMagenta instead of the default system blue.
        .tint(.quinceMagenta)
    }

    private var homeHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.quinceMagenta, .quinceGold], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                    .shadow(color: .quinceMagenta.opacity(0.4), radius: 8, y: 4)
                Image(systemName: "birthday.cake.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            Text("Let's plan your celebration")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }
}

// One tappable card on the home screen. Generic over `Destination` so any
// section's view can be plugged in as the thing it navigates to.
private struct MenuCard<Destination: View>: View {
    let title: LocalizedStringKey
    let icon: String
    let color: Color
    let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// A full-width, larger card for spotlighting one section above the regular
// grid — used to give the Boutique top billing on the home screen.
private struct FeaturedCard<Destination: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let icon: String
    let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.25))
                        .frame(width: 64, height: 64)
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [.quinceMagenta, .quinceGold], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .quinceMagenta.opacity(0.35), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Checklist section

// A single to-do item on the planning checklist. Each item carries an SF
// Symbol name and a color so the row can render as a little colorful card.
struct ChecklistItem: Identifiable {
    let id = UUID()
    let title: LocalizedStringKey
    let icon: String
    let color: Color
    var isDone: Bool = false
}

struct ChecklistView: View {
    @State private var items: [ChecklistItem] = [
        ChecklistItem(title: "Book the venue", icon: "building.2.fill", color: .quinceMagenta),
        ChecklistItem(title: "Choose the theme", icon: "paintpalette.fill", color: .quincePink),
        ChecklistItem(title: "Order the dress", icon: "tshirt.fill", color: .quinceGold),
        ChecklistItem(title: "Confirm the court of honor", icon: "person.3.fill", color: .quinceMagenta),
        ChecklistItem(title: "Book catering", icon: "fork.knife", color: .quincePink),
        ChecklistItem(title: "Send invitations", icon: "envelope.fill", color: .quinceGold),
        ChecklistItem(title: "Book photographer/videographer", icon: "camera.fill", color: .quinceMagenta),
    ]

    private var completedCount: Int {
        items.filter(\.isDone).count
    }

    private var progressFraction: CGFloat {
        items.isEmpty ? 0 : CGFloat(completedCount) / CGFloat(items.count)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.quincePink.opacity(0.25), Color.quinceGold.opacity(0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    progressBar
                    ForEach($items) { $item in
                        ChecklistRow(item: $item)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Planning Checklist")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(completedCount) of \(items.count) done")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.quinceGold.opacity(0.2))
                    Capsule()
                        .fill(LinearGradient(colors: [.quinceMagenta, .quincePink], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progressFraction)
                        .animation(.spring, value: completedCount)
                }
            }
            .frame(height: 10)
        }
    }
}

// One colorful card in the checklist. Pulling this into its own View keeps
// ChecklistView's body readable.
private struct ChecklistRow: View {
    @Binding var item: ChecklistItem

    var body: some View {
        Button {
            withAnimation(.spring) {
                item.isDone.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(item.color.opacity(item.isDone ? 0.3 : 1))
                        .frame(width: 44, height: 44)
                    Image(systemName: item.icon)
                        .foregroundStyle(.white)
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(item.title)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? .green : .secondary.opacity(0.5))
                    .font(.title3)
            }
            .padding(12)
            .background(.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Boutique section

// The kinds of things the boutique sells. Keeping this as an enum (rather
// than a free-text string) means the category filter below can't drift out
// of sync with what a product is actually tagged as.
enum ProductCategory: String, CaseIterable, Identifiable {
    case dress = "Dresses"
    case crown = "Crowns"
    case accessory = "Accessories"

    var id: String { rawValue }

    // rawValue stays plain English (it's just an internal identifier); this
    // is what's actually shown on screen, so it's the one that gets
    // translated via the String Catalog.
    var displayName: LocalizedStringKey { LocalizedStringKey(rawValue) }
}

// A single item the store has for sale. `icon`/`color` stand in for a real
// product photo until we wire up actual images — swapping them for an
// `Image` is a later step, the rest of the screens won't need to change.
// `sizes` is empty for items (crowns, most accessories) that don't come in
// sizes.
struct Product: Identifiable {
    let id = UUID()
    let name: String
    let category: ProductCategory
    let price: Decimal
    let description: String
    let sizes: [String]
    let icon: String
    let color: Color

    // Placeholder inventory — replace with the real catalog when ready.
    static let samples: [Product] = [
        Product(name: "Enchanted Rose", category: .dress, price: 450, description: "Ball gown with a layered tulle skirt and beaded bodice.", sizes: ["4", "6", "8", "10", "12"], icon: "sparkles", color: .quinceMagenta),
        Product(name: "Golden Waltz", category: .dress, price: 520, description: "Champagne satin gown with gold embroidery and off-shoulder sleeves.", sizes: ["2", "4", "6", "8"], icon: "star.fill", color: .quinceGold),
        Product(name: "Blush Garden", category: .dress, price: 395, description: "Soft pink tulle gown with floral lace appliqué.", sizes: ["6", "8", "10", "12", "14"], icon: "leaf.fill", color: .quincePink),
        Product(name: "Midnight Elegance", category: .dress, price: 580, description: "Deep magenta gown with a sweetheart neckline and dramatic train.", sizes: ["4", "6", "8", "10"], icon: "moon.stars.fill", color: .quinceMagenta),
        Product(name: "Golden Tiara", category: .crown, price: 85, description: "Classic gold-tone tiara with crystal accents.", sizes: [], icon: "crown.fill", color: .quinceGold),
        Product(name: "Pearl Crown", category: .crown, price: 95, description: "Delicate crown with freshwater pearl detailing.", sizes: [], icon: "crown.fill", color: .quincePink),
        Product(name: "Crystal Earrings", category: .accessory, price: 40, description: "Sparkling drop earrings to match any gown.", sizes: [], icon: "sparkle", color: .quinceMagenta),
        Product(name: "Satin Gloves", category: .accessory, price: 30, description: "Elbow-length satin gloves, available in multiple colors.", sizes: ["S/M", "L/XL"], icon: "hand.raised.fill", color: .quincePink),
    ]
}

struct BoutiqueView: View {
    private let products = Product.samples
    @State private var selectedCategory: ProductCategory?
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var filteredProducts: [Product] {
        guard let selectedCategory else { return products }
        return products.filter { $0.category == selectedCategory }
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
                    boutiqueHeader
                    categoryPicker
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredProducts) { product in
                            ProductCard(product: product)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("The Boutique")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var boutiqueHeader: some View {
        VStack(spacing: 4) {
            Text("LILY'S CREATIONS")
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(.quinceGold)
            Text("Dresses, crowns & accessories for her quince")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(ProductCategory.allCases) { category in
                    CategoryChip(title: category.displayName, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
        }
    }
}

private struct CategoryChip: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule().fill(LinearGradient(colors: [.quinceMagenta, .quincePink], startPoint: .leading, endPoint: .trailing))
                    } else {
                        Capsule().fill(.white.opacity(0.7))
                    }
                }
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct ProductCard: View {
    let product: Product

    var body: some View {
        NavigationLink {
            ProductDetailView(product: product)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [product.color, product.color.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .aspectRatio(1, contentMode: .fit)
                    Image(systemName: product.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.9))
                }
                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(product.price, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct ProductDetailView: View {
    let product: Product
    @State private var showingInquireSheet = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [product.color.opacity(0.25), Color.quinceGold.opacity(0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(LinearGradient(colors: [product.color, product.color.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(height: 220)
                        Image(systemName: product.icon)
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(product.name)
                            .font(.title2.bold())
                        Text(product.price, format: .currency(code: "USD"))
                            .font(.title3)
                            .foregroundStyle(product.color)
                        Text(product.description)
                            .foregroundStyle(.secondary)

                        if !product.sizes.isEmpty {
                            Text("Available sizes")
                                .font(.headline)
                                .padding(.top, 8)
                            HStack {
                                ForEach(product.sizes, id: \.self) { size in
                                    Text(size)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(product.color.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    Button {
                        showingInquireSheet = true
                    } label: {
                        Text("Inquire About This Item")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient(colors: [product.color, product.color.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingInquireSheet) {
            InquireSheet(product: product)
        }
    }
}

// Tapping "Inquire" shows this as a sheet (a card that slides up over the
// current screen) with ways to contact the store about a specific item.
private struct InquireSheet: View {
    let product: Product
    @Environment(\.dismiss) private var dismiss

    // TODO: replace with the boutique's real phone number and email.
    private let storePhone = "+1-555-0100"
    private let storeEmail = "hello@yourboutique.example"

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(product.color)
                Text("Interested in \(product.name)?")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                Text("Reach out to Lily's Creations and we'll help with sizing, availability, and scheduling a fitting.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Link(destination: URL(string: "tel:\(storePhone)")!) {
                        Label(storePhone, systemImage: "phone.fill")
                    }
                    Link(destination: URL(string: "mailto:\(storeEmail)")!) {
                        Label(storeEmail, systemImage: "envelope.fill")
                    }
                }
                .font(.headline)
                .foregroundStyle(product.color)

                Spacer()
            }
            .padding()
            .navigationTitle("Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Budget section

// One line item in the budget — a category like "Venue" or "Dress" with how
// much was planned for it and how much has actually been spent so far.
// Unlike the fixed ProductCategory enum in the Boutique, budget categories
// are fully user-editable since every family's budget breaks down
// differently.
struct BudgetCategory: Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let color: Color
    let plannedAmount: Decimal
    let actualAmount: Decimal

    init(id: UUID = UUID(), name: String, icon: String, color: Color, plannedAmount: Decimal, actualAmount: Decimal) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.plannedAmount = plannedAmount
        self.actualAmount = actualAmount
    }

    // A few starter categories so the screen isn't empty on first launch —
    // the user can rename, delete, or add to these freely.
    static let samples: [BudgetCategory] = [
        BudgetCategory(name: "Venue", icon: "building.2.fill", color: .quinceMagenta, plannedAmount: 4500, actualAmount: 2000),
        BudgetCategory(name: "Dress", icon: "tshirt.fill", color: .quincePink, plannedAmount: 600, actualAmount: 600),
        BudgetCategory(name: "Catering", icon: "fork.knife", color: .quinceGold, plannedAmount: 3000, actualAmount: 0),
        BudgetCategory(name: "Photography", icon: "camera.fill", color: .quinceMagenta, plannedAmount: 1200, actualAmount: 500),
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
private let budgetCategoryColors: [Color] = [.quinceMagenta, .quincePink, .quinceGold]

struct BudgetView: View {
    @State private var categories: [BudgetCategory] = BudgetCategory.samples
    @State private var totalBudget: Decimal = 15000
    @State private var showingAddSheet = false
    @State private var editingCategory: BudgetCategory?

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
        .sheet(isPresented: $showingAddSheet) {
            BudgetCategorySheet(category: nil, onSave: { categories.append($0) })
        }
        .sheet(item: $editingCategory) { category in
            BudgetCategorySheet(
                category: category,
                onSave: { updated in
                    if let index = categories.firstIndex(where: { $0.id == updated.id }) {
                        categories[index] = updated
                    }
                },
                onDelete: {
                    categories.removeAll { $0.id == category.id }
                }
            )
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Total Budget")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                TextField("Total Budget", value: $totalBudget, format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule()
                        .fill(isOverBudget ? Color.red : Color.white)
                        .frame(width: geo.size.width * spentFraction)
                        .animation(.spring, value: spentFraction)
                }
            }
            .frame(height: 10)

            HStack {
                summaryStat(title: "Planned", amount: totalPlanned)
                Spacer()
                summaryStat(title: "Spent", amount: totalSpent)
                Spacer()
                summaryStat(title: "Remaining", amount: totalBudget - totalSpent)
            }
        }
        .padding(20)
        .background(
            LinearGradient(colors: [.quinceMagenta, .quinceGold], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .quinceMagenta.opacity(0.35), radius: 10, y: 5)
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
// pre-filled when editing an existing one.
private struct BudgetCategorySheet: View {
    let category: BudgetCategory?
    let onSave: (BudgetCategory) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var icon: String
    @State private var color: Color
    @State private var plannedAmount: Decimal
    @State private var actualAmount: Decimal

    init(category: BudgetCategory?, onSave: @escaping (BudgetCategory) -> Void, onDelete: (() -> Void)? = nil) {
        self.category = category
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: category?.name ?? "")
        _icon = State(initialValue: category?.icon ?? budgetCategoryIcons[0])
        _color = State(initialValue: category?.color ?? budgetCategoryColors[0])
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
                            BudgetCategory(
                                id: category?.id ?? UUID(),
                                name: name.trimmingCharacters(in: .whitespaces),
                                icon: icon,
                                color: color,
                                plannedAmount: plannedAmount,
                                actualAmount: actualAmount
                            )
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
                                .fill(icon == symbol ? AnyShapeStyle(color) : AnyShapeStyle(Color.gray.opacity(0.15)))
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
            ForEach(0..<budgetCategoryColors.count, id: \.self) { index in
                let option = budgetCategoryColors[index]
                Button {
                    color = option
                } label: {
                    Circle()
                        .fill(option)
                        .frame(width: 32, height: 32)
                        .overlay {
                            if color == option {
                                Circle().stroke(.primary, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Placeholder sections

// A themed "coming soon" screen, reused by every section we haven't built
// out yet. When we're ready to build, say, the real Guest List, we'll
// replace GuestListView's body with real content — MenuCard on the home
// screen won't need to change at all.
private struct ComingSoonView: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [color.opacity(0.25), Color.quinceGold.opacity(0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 80, height: 80)
                    Image(systemName: icon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("Coming soon!")
                    .font(.title3.bold())
                Text("This is where you'll manage your \(title.lowercased()).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GuestListView: View {
    var body: some View {
        ComingSoonView(title: "Guest List", icon: "person.3.fill", color: .quincePink)
    }
}

struct VendorsView: View {
    var body: some View {
        ComingSoonView(title: "Vendors", icon: "storefront.fill", color: .quinceMagenta)
    }
}

#Preview {
    ContentView()
}
