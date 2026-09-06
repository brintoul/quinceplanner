//
//  GuestListView.swift
//  QuinsePlanner
//

import SwiftUI
import SwiftData
import Contacts
import ContactsUI

// Whether a guest has responded to their invitation yet. Stored directly on
// Guest below — SwiftData persists Codable types natively, so (unlike
// Color, which needs the colorName-string workaround) this needs no manual
// mapping to a separate stored field.
enum GuestRSVPStatus: String, Codable, CaseIterable, Identifiable {
    case invited = "Invited"
    case confirmed = "Confirmed"
    case declined = "Declined"

    var id: String { rawValue }
}

// Formats raw digits into a standard US "(XXX) XXX-XXXX" phone number as
// the user types (or as a Contacts import is normalized), stripping any
// non-digit characters, dropping a leading "1" country code if present,
// and capping at 10 digits. Used by both GuestSheet's phone field and
// Guest.fromContact below, so a guest's number looks the same whichever
// way it was entered.
private func formattedPhoneNumber(_ input: String) -> String {
    var digits = input.filter(\.isNumber)
    if digits.count == 11 && digits.first == "1" {
        digits.removeFirst()
    }
    digits = String(digits.prefix(10))
    guard !digits.isEmpty else { return "" }

    var result = "("
    for (index, digit) in digits.enumerated() {
        if index == 3 { result += ") " }
        if index == 6 { result += "-" }
        result.append(digit)
    }
    return result
}

// A single guest on the list, with RSVP tracking and plus-one info. This is
// a SwiftData model so the guest list survives app restarts.
@Model
final class Guest {
    var id: UUID
    var name: String
    var phone: String
    var email: String
    var rsvpStatus: GuestRSVPStatus
    var allowsPlusOne: Bool
    var bringingPlusOne: Bool

    init(
        id: UUID = UUID(),
        name: String,
        phone: String = "",
        email: String = "",
        rsvpStatus: GuestRSVPStatus = .invited,
        allowsPlusOne: Bool = false,
        bringingPlusOne: Bool = false
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.rsvpStatus = rsvpStatus
        self.allowsPlusOne = allowsPlusOne
        self.bringingPlusOne = bringingPlusOne
    }

    var statusColor: Color {
        switch rsvpStatus {
        case .invited: .quinceGold
        case .confirmed: .green
        case .declined: .red
        }
    }

    // How many seats this guest represents — 2 if they're bringing a
    // plus-one, otherwise just themselves.
    var headcount: Int {
        bringingPlusOne ? 2 : 1
    }

    // Maps a picked system Contact into a new, unsaved Guest — used by the
    // "Import from Contacts" flow below.
    static func fromContact(_ contact: CNContact) -> Guest {
        let formattedName = CNContactFormatter.string(from: contact, style: .fullName)
        let name = formattedName?.trimmingCharacters(in: .whitespaces).isEmpty == false
            ? formattedName!
            : "Unnamed Guest"
        let phone = formattedPhoneNumber(contact.phoneNumbers.first?.value.stringValue ?? "")
        let email = (contact.emailAddresses.first?.value).map { $0 as String } ?? ""
        return Guest(name: name, phone: phone, email: email)
    }
}

struct GuestListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.name) private var guests: [Guest]

    @State private var showingAddSheet = false
    @State private var showingContactPicker = false
    @State private var editingGuest: Guest?

    private var invitedCount: Int {
        guests.filter { $0.rsvpStatus == .invited }.count
    }

    private var confirmedCount: Int {
        guests.filter { $0.rsvpStatus == .confirmed }.count
    }

    private var declinedCount: Int {
        guests.filter { $0.rsvpStatus == .declined }.count
    }

    private var confirmedHeadcount: Int {
        guests.filter { $0.rsvpStatus == .confirmed }.reduce(0) { $0 + $1.headcount }
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
                    summaryCard
                    if guests.isEmpty {
                        emptyState
                    } else {
                        ForEach(guests) { guest in
                            Button {
                                editingGuest = guest
                            } label: {
                                GuestRow(guest: guest)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    modelContext.delete(guest)
                                } label: {
                                    Label("Delete Guest", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Guest List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add Guest", systemImage: "person.badge.plus")
                    }
                    Button {
                        showingContactPicker = true
                    } label: {
                        Label("Import from Contacts", systemImage: "person.crop.circle.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            GuestSheet(guest: nil, onSave: { name, phone, email, rsvpStatus, allowsPlusOne, bringingPlusOne in
                modelContext.insert(
                    Guest(name: name, phone: phone, email: email, rsvpStatus: rsvpStatus, allowsPlusOne: allowsPlusOne, bringingPlusOne: bringingPlusOne)
                )
            })
        }
        .sheet(item: $editingGuest) { guest in
            GuestSheet(
                guest: guest,
                onSave: { name, phone, email, rsvpStatus, allowsPlusOne, bringingPlusOne in
                    guest.name = name
                    guest.phone = phone
                    guest.email = email
                    guest.rsvpStatus = rsvpStatus
                    guest.allowsPlusOne = allowsPlusOne
                    guest.bringingPlusOne = bringingPlusOne
                },
                onDelete: {
                    modelContext.delete(guest)
                }
            )
        }
        .sheet(isPresented: $showingContactPicker) {
            ContactPicker { contacts in
                for contact in contacts {
                    modelContext.insert(Guest.fromContact(contact))
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Guests")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))

            HStack {
                summaryStat(title: "Invited", value: "\(invitedCount)")
                Spacer()
                summaryStat(title: "Confirmed", value: "\(confirmedCount)")
                Spacer()
                summaryStat(title: "Declined", value: "\(declinedCount)")
            }

            Text("\(confirmedHeadcount) confirmed headcount, including plus-ones")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(20)
        .background(
            LinearGradient(colors: [.quincePink, .quinceGold], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .quincePink.opacity(0.35), radius: 10, y: 5)
    }

    private func summaryStat(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.quincePink.opacity(0.5))
            Text("No guests yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Add a guest or import from your Contacts to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
}

// One colorful card in the guest list, showing RSVP status and plus-one
// info at a glance.
private struct GuestRow: View {
    let guest: Guest

    private var contactLine: String? {
        let parts = [guest.phone, guest.email].filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(guest.statusColor)
                    .frame(width: 44, height: 44)
                Image(systemName: "person.fill")
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(guest.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let contactLine {
                    Text(contactLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(guest.rsvpStatus.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(guest.statusColor)
                if guest.allowsPlusOne {
                    Text(guest.bringingPlusOne ? "+1 coming" : "+1 allowed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

// The add/edit form for a single guest. Same pattern as BudgetCategorySheet:
// `guest` is nil when adding (no Delete button shows), or pre-filled when
// editing an existing one; `onSave` hands back plain values so the caller
// decides whether that means inserting a new persisted guest or updating
// one.
private struct GuestSheet: View {
    let guest: Guest?
    let onSave: (
        _ name: String,
        _ phone: String,
        _ email: String,
        _ rsvpStatus: GuestRSVPStatus,
        _ allowsPlusOne: Bool,
        _ bringingPlusOne: Bool
    ) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var phone: String
    @State private var email: String
    @State private var rsvpStatus: GuestRSVPStatus
    @State private var allowsPlusOne: Bool
    @State private var bringingPlusOne: Bool

    init(
        guest: Guest?,
        onSave: @escaping (
            _ name: String,
            _ phone: String,
            _ email: String,
            _ rsvpStatus: GuestRSVPStatus,
            _ allowsPlusOne: Bool,
            _ bringingPlusOne: Bool
        ) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.guest = guest
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: guest?.name ?? "")
        _phone = State(initialValue: guest?.phone ?? "")
        _email = State(initialValue: guest?.email ?? "")
        _rsvpStatus = State(initialValue: guest?.rsvpStatus ?? .invited)
        _allowsPlusOne = State(initialValue: guest?.allowsPlusOne ?? false)
        _bringingPlusOne = State(initialValue: guest?.bringingPlusOne ?? false)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // Reformats into "(XXX) XXX-XXXX" on every keystroke rather than only
    // at save time, so the field always shows a properly-formatted number
    // (at the cost of the cursor jumping to the end after each edit, since
    // this is a simple re-render rather than a cursor-aware text field).
    private var phoneBinding: Binding<String> {
        Binding(
            get: { phone },
            set: { phone = formattedPhoneNumber($0) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Guest") {
                    TextField("Name", text: $name)
                    TextField("Phone", text: phoneBinding)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Section("RSVP") {
                    Picker("Status", selection: $rsvpStatus) {
                        ForEach(GuestRSVPStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    Toggle("Allows a plus-one", isOn: $allowsPlusOne)
                    if allowsPlusOne {
                        Toggle("Bringing a plus-one", isOn: $bringingPlusOne)
                    }
                }

                if let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("Delete Guest")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(guest == nil ? "Add Guest" : "Edit Guest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            name.trimmingCharacters(in: .whitespaces),
                            phone.trimmingCharacters(in: .whitespaces),
                            email.trimmingCharacters(in: .whitespaces),
                            rsvpStatus,
                            allowsPlusOne,
                            bringingPlusOne
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// Wraps the system contact picker (no SwiftUI-native equivalent exists) so
// guests can be imported instead of typed in by hand. Presenting this UI
// runs out-of-process and needs no Info.plist privacy key — only calling
// CNContactStore directly to fetch/search contacts would.
private struct ContactPicker: UIViewControllerRepresentable {
    let onSelect: ([CNContact]) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: ([CNContact]) -> Void

        init(onSelect: @escaping ([CNContact]) -> Void) {
            self.onSelect = onSelect
        }

        // Implementing the plural delegate method (rather than the
        // single-contact one) is what puts the picker into multi-select mode.
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            onSelect(contacts)
        }
    }
}
