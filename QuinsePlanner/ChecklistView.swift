//
//  ChecklistView.swift
//  QuinsePlanner
//

import SwiftUI
import SwiftData

// A single to-do item on the planning checklist. Each item carries an SF
// Symbol name and a color so the row can render as a little colorful card.
// This is a SwiftData model so completion state and notes survive app
// restarts.
@Model
final class ChecklistItem {
    var id: UUID
    // The built-in starter items' copy needs to stay localizable, but
    // SwiftData can't persist LocalizedStringKey directly — it's stored as
    // a plain String and re-wrapped as LocalizedStringKey at display time
    // (see ChecklistRow), which still resolves through the string catalog
    // as long as the stored text matches a catalog key.
    var title: String
    var icon: String
    // Stored as a name rather than a Color, same reasoning as
    // BudgetCategory.colorName in BudgetView.swift.
    var colorName: String
    // Preserves the intended planning order — a @Query sorted by title
    // would scramble it, since this isn't an alphabetical list.
    var sortIndex: Int
    var isDone: Bool

    // Cascade so deleting an item takes its notes with it.
    @Relationship(deleteRule: .cascade, inverse: \ChecklistNote.item)
    var notes: [ChecklistNote] = []

    init(id: UUID = UUID(), title: String, icon: String, colorName: String, sortIndex: Int, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.icon = icon
        self.colorName = colorName
        self.sortIndex = sortIndex
        self.isDone = isDone
    }

    var color: Color {
        checklistColorOptions.first { $0.name == colorName }?.color ?? .quinceMagenta
    }

    // The starter checklist so the screen isn't empty on first launch —
    // inserted once, in order, if the store is empty.
    static let sampleSeed: [(title: String, icon: String, colorName: String)] = [
        ("Book the venue", "building.2.fill", "magenta"),
        ("Choose the theme", "paintpalette.fill", "pink"),
        ("Order the dress", "tshirt.fill", "gold"),
        ("Confirm the court of honor", "person.3.fill", "magenta"),
        ("Book catering", "fork.knife", "pink"),
        ("Send invitations", "envelope.fill", "gold"),
        ("Book photographer/videographer", "camera.fill", "magenta"),
    ]
}

private let checklistColorOptions: [(name: String, color: Color)] = [
    ("magenta", .quinceMagenta), ("pink", .quincePink), ("gold", .quinceGold),
]

// A single free-form note on a checklist item (e.g. "Call 'Best Venue' to
// ask about pricing"). Items can have any number of these, each removable
// on its own.
@Model
final class ChecklistNote {
    var id: UUID
    // User-typed, so plain String rather than LocalizedStringKey — it isn't
    // meant to be looked up in a translation table.
    var text: String
    var createdAt: Date
    var item: ChecklistItem?

    init(id: UUID = UUID(), text: String, createdAt: Date = .now, item: ChecklistItem? = nil) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.item = item
    }
}

struct ChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChecklistItem.sortIndex) private var items: [ChecklistItem]

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
                    ForEach(items) { item in
                        ChecklistRow(item: item)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Planning Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            seedIfNeeded()
        }
    }

    private func seedIfNeeded() {
        guard items.isEmpty else { return }
        for (index, seed) in ChecklistItem.sampleSeed.enumerated() {
            modelContext.insert(
                ChecklistItem(title: seed.title, icon: seed.icon, colorName: seed.colorName, sortIndex: index)
            )
        }
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
    let item: ChecklistItem
    @State private var showingNoteSheet = false

    var body: some View {
        HStack(spacing: 10) {
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

                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(item.title))
                            .strikethrough(item.isDone)
                            .foregroundStyle(item.isDone ? .secondary : .primary)
                            .multilineTextAlignment(.leading)

                        if let notePreview = item.notePreview {
                            Text(notePreview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isDone ? .green : .secondary.opacity(0.5))
                        .font(.title3)
                }
            }
            .buttonStyle(.plain)

            Button {
                showingNoteSheet = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.title3)
                    .foregroundStyle(item.notes.isEmpty ? .secondary : item.color)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .sheet(isPresented: $showingNoteSheet) {
            ChecklistNotesSheet(item: item)
        }
    }
}

private extension ChecklistItem {
    // What shows as the row's secondary line: the note itself when there's
    // just one, otherwise a count, so the card doesn't grow with the list.
    var notePreview: String? {
        if notes.count == 1 {
            return notes.first?.text
        } else if notes.count > 1 {
            return "\(notes.count) notes"
        }
        return nil
    }
}

// Lists every note on a checklist item, oldest first, with a field at the
// top to add another and swipe-to-delete on each — items can carry any
// number of notes rather than just one.
private struct ChecklistNotesSheet: View {
    let item: ChecklistItem

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var newNoteText = ""

    private var sortedNotes: [ChecklistNote] {
        item.notes.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .top) {
                        TextField("Add a note, e.g. Call \"Best Venue\" to ask about pricing", text: $newNoteText, axis: .vertical)
                            .lineLimit(1...4)
                        Button {
                            addNote()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if !sortedNotes.isEmpty {
                    Section("Notes") {
                        ForEach(sortedNotes) { note in
                            Text(note.text)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                modelContext.delete(sortedNotes[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle(Text(LocalizedStringKey(item.title)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func addNote() {
        let trimmed = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(ChecklistNote(text: trimmed, item: item))
        newNoteText = ""
    }
}
