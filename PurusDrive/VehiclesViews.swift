import SwiftUI
import SwiftData
import UIKit

struct VehiclesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]
    @Query(sort: \Trailer.lastEdited, order: .reverse) private var trailers: [Trailer]
    @Query(sort: \DriveLog.date, order: .reverse) private var allDriveLogs: [DriveLog]
    @Query(sort: \Checklist.lastEdited, order: .reverse) private var allChecklists: [Checklist]

    @State private var syncStatusText: String = ""
    /// set on wide screens: rows select into the right column instead of pushing
    var selection: Binding<VehicleSelection?>? = nil

    // Trailers linked to vehicles should not appear as standalone rows.
    private var linkedTrailerIDs: Set<UUID> {
        Set(vehicles.compactMap { $0.trailer?.id })
    }

    private var unlinkedTrailers: [Trailer] {
        trailers.filter { !linkedTrailerIDs.contains($0.id) }
    }

    var body: some View {
        List {
            if !syncStatusText.isEmpty {
                HStack(spacing: 8) {
                    if syncStatusText.hasPrefix("Syncing") { ProgressView().scaleEffect(0.8) }
                    Text(syncStatusText).font(.footnote).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
            }

            if vehicles.isEmpty && unlinkedTrailers.isEmpty {
                Text("No vehicles yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // Unlinked trailers (standalone)
            ForEach(unlinkedTrailers.filter { $0.modelContext != nil }) { t in
                row(.trailer(t.id)) {
                    NewTrailerFormView(existing: t)
                        .environment(\.modelContext, modelContext)
                } label: {
                    HStack(spacing: 12) {
                        Image("TRAILER_CAR")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.primary)
                            .frame(width: 28, height: 28)
                            .padding(4)
                            .background(Color(.tertiarySystemBackground).opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.brandModel.isEmpty ? "Trailer" : t.brandModel)
                                .font(.headline)
                            if !t.plate.isEmpty {
                                Text(t.plate)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(t.lastEdited, style: .time)
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        deleteTrailerCascade(t, in: modelContext)
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }

            // Vehicles + their linked trailer directly underneath
            ForEach(vehicles.filter { $0.modelContext != nil }) { v in
                row(.vehicle(v.id)) {
                    VehicleFormView(vehicle: v)
                } label: {
                    HStack(spacing: 12) {
                        vehicleIconView(for: v)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(v.brandModel.isEmpty ? v.type.displayName : v.brandModel)
                                .font(.headline)
                            Text(v.plate)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            // New: show linked trailer (subtle/indented)
                            if let t = v.trailer {
                                HStack(spacing: 6) {
                                    Image(systemName: "link")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    Text(t.brandModel.isEmpty ? (t.plate.isEmpty ? "Trailer" : t.plate) : t.brandModel)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 16)
                            }
                        }

                        Spacer()
                        HStack(spacing: 6) {
                            // mini icons: checklists and logs
                            if allChecklists.contains(where: { $0.vehicle === v }) || (v.trailer != nil && allChecklists.contains(where: { $0.trailer === v.trailer })) {
                                Image(systemName: "checklist").font(.caption2).foregroundStyle(.secondary)
                            }
                            if allDriveLogs.contains(where: { $0.vehicle === v }) {
                                Image(systemName: "road.lanes").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Text(v.lastEdited, style: .time)
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        deleteVehicleCascade(v, in: modelContext)
                    } label: { Label("Delete", systemImage: "trash") }
                }

                if let t = v.trailer, t.modelContext != nil {
                    row(.trailer(t.id)) {
                        NewTrailerFormView(existing: t)
                            .environment(\.modelContext, modelContext)
                    } label: {
                        HStack(spacing: 12) {
                            Image("TRAILER_CAR")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.primary)
                                .frame(width: 22, height: 22)
                                .padding(4)
                                .background(Color(.tertiarySystemBackground).opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.brandModel.isEmpty ? "Trailer" : t.brandModel)
                                    .font(.subheadline)
                                if !t.plate.isEmpty {
                                    Text(t.plate)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .padding(.leading, 40)
                    }
                    .listRowSeparator(.hidden)
                }
            }
        }
        .refreshable {
            // Trigger an on-demand sync when in iCloud mode
            let raw = UserDefaults.standard.string(forKey: "storageLocation") ?? StorageLocation.local.rawValue
            if raw == StorageLocation.icloud.rawValue {
                // Post notifications so the overlay shows progress
                NotificationCenter.default.post(name: Notification.Name("SyncStartedNotification"), object: nil)
                await CloudKitSyncService.shared.performFullSync()
                NotificationCenter.default.post(name: Notification.Name("SyncCompletedNotification"), object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncStartedNotification"))) { _ in
            syncStatusText = "Syncing with iCloud…"
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncFetchedCountNotification"))) { output in
            if let info = output.userInfo as? [String: Any], let type = info["type"] as? String, let count = info["count"] as? Int {
                syncStatusText = "Fetched \(count) \(type)"
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncPushedCountNotification"))) { output in
            if let info = output.userInfo as? [String: Any], let type = info["type"] as? String, let count = info["count"] as? Int {
                syncStatusText = "Uploaded \(count) \(type)"
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncImportedCountNotification"))) { output in
            if let info = output.userInfo as? [String: Any], let type = info["type"] as? String, let count = info["count"] as? Int {
                syncStatusText = "Imported \(count) \(type)"
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncCompletedNotification"))) { _ in
            syncStatusText = "Sync complete"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { syncStatusText = "" }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncErrorNotification"))) { output in
            if let info = output.userInfo as? [String: Any], let message = info["message"] as? String {
                syncStatusText = message
            }
        }
    }

    /// Narrow: push the form. Wide: select it into the right column.
    @ViewBuilder
    private func row<Destination: View, RowLabel: View>(_ sel: VehicleSelection,
                                                       @ViewBuilder destination: @escaping () -> Destination,
                                                       @ViewBuilder label: () -> RowLabel) -> some View {
        if let selection {
            Button { selection.wrappedValue = sel } label: { label().contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .listRowBackground(selection.wrappedValue == sel ? Color.accentColor.opacity(0.15) : nil)
        } else {
            NavigationLink(destination: destination, label: label)
        }
    }
}

enum VehicleSelection: Hashable {
    case vehicle(UUID)
    case trailer(UUID)
}

/// Right column on wide screens.
struct VehicleDetailColumn: View {
    @Binding var selection: VehicleSelection?
    @Query private var vehicles: [Vehicle]
    @Query private var trailers: [Trailer]

    var body: some View {
        switch selection {
        case .vehicle(let id):
            if let v = vehicles.first(where: { $0.id == id && $0.modelContext != nil }) {
                NavigationStack { VehicleFormView(vehicle: v, onClose: { selection = nil }) }.id(selection)
            } else { empty }
        case .trailer(let id):
            if let t = trailers.first(where: { $0.id == id && $0.modelContext != nil }) {
                NavigationStack { NewTrailerFormView(existing: t, onClose: { selection = nil }) }.id(selection)
            } else { empty }
        case nil:
            empty
        }
    }

    private var empty: some View { ContentUnavailableView("Select a vehicle", systemImage: "car") }
}

extension VehiclesListView {
    // Vehicle icon helper
    @ViewBuilder
    fileprivate func vehicleIconView(for v: Vehicle) -> some View {
        // Safety check: if vehicle was deleted, return placeholder
        if v.modelContext == nil {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.tertiarySystemBackground))
                .opacity(0.85)
        } else {
            // choose base image (either system or asset)
            let (base, needsTemplateTint) = v.type.icon

            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.tertiarySystemBackground))
                        .opacity(0.85)

                    if needsTemplateTint {
                        base
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                            .foregroundStyle(.primary)
                    } else {
                        base
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                            .foregroundStyle(.primary)
                    }

                    if v.trailer != nil {
                        Image("TRAILER_CAR")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.primary)
                            .frame(width: geo.size.width * 0.45, height: geo.size.height * 0.45)
                            .offset(x: geo.size.width * 0.22, y: geo.size.height * 0.22)
                    }
                }
            }
        }
    }

}

extension VehicleType {
    /// base image and whether it is an asset that needs template tinting
    fileprivate var icon: (Image, Bool) {
        switch self {
        case .car: return (Image(systemName: "car"), false)
        case .van: return (Image("VAN"), true)
        case .truck: return (Image(systemName: "truck.box"), false)
        case .trailer: return (Image("TRAILER_CAR"), true)
        case .camper: return (Image("CAMPER"), true)
        case .boat: return (Image(systemName: "sailboat"), false)
        case .motorbike: return (Image("MOTORBIKE"), true)
        case .scooter: return (Image("SCOOTER"), true)
        case .other: return (Image(systemName: "questionmark.circle"), false)
        }
    }
}

/// Deletes a vehicle with its drive logs, checklists and items, unlinks its trailer and tombstones it for iCloud.
@MainActor
private func deleteVehicleCascade(_ v: Vehicle, in context: ModelContext) {
    CloudKitSyncService.shared.markDeleted(entityType: "Vehicle", id: v.id)
    for l in v.driveLogs ?? [] { context.delete(l) }
    for c in v.checklists ?? [] {
        for i in c.items ?? [] { context.delete(i) }
        context.delete(c)
    }
    if let tr = v.trailer { tr.linkedVehicle = nil; v.trailer = nil }
    context.delete(v)
    do { try context.save() } catch { print("ERROR: failed deleting vehicle: \(error)") }
    Task { await CloudKitSyncService.shared.pushDeletions() }
    NotificationCenter.default.post(name: Notification.Name("RequestFullSyncNotification"), object: nil)
}

/// Deletes a trailer with its checklists and items, unlinks it from its vehicle and tombstones it for iCloud.
@MainActor
private func deleteTrailerCascade(_ t: Trailer, in context: ModelContext) {
    CloudKitSyncService.shared.markDeleted(entityType: "Trailer", id: t.id)
    for c in t.checklists ?? [] {
        for i in c.items ?? [] { context.delete(i) }
        context.delete(c)
    }
    t.linkedVehicle?.trailer = nil
    context.delete(t)
    do { try context.save() } catch { print("ERROR: failed deleting trailer: \(error)") }
    Task { await CloudKitSyncService.shared.pushDeletions() }
    NotificationCenter.default.post(name: Notification.Name("RequestFullSyncNotification"), object: nil)
}

struct VehicleFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var type: VehicleType
    @State private var brandModel: String
    @State private var color: String
    @State private var plate: String
    @State private var notes: String
    @State private var trailer: Trailer?

    // photo + scanner state
    @State private var carPhoto: UIImage? = nil
    /// downscaled JPEG of a newly picked photo; written only on Save
    @State private var newPhotoData: Data? = nil
    /// Remove Photo is applied on Save so Cancel can undo it
    @State private var photoRemoved = false
    @State private var showingPlateScanner = false
    @State private var saveErrorMessage: String? = nil

    @State private var showingNewDriveLog = false
    @State private var newChecklistToEdit: Checklist? = nil

    @State private var newDriveLogToEdit: DriveLog? = nil

    // Show last items for this vehicle
    @Query(sort: \DriveLog.date, order: .reverse) private var allDriveLogs: [DriveLog]
    @Query(sort: \Checklist.lastEdited, order: .reverse) private var allChecklists: [Checklist]

    var vehicle: Vehicle?
    /// set in the right column on wide screens (there is no screen to go back from)
    var onClose: (() -> Void)? = nil
    @State private var showingDeleteConfirm = false

    init(vehicle: Vehicle? = nil, onClose: (() -> Void)? = nil) {
        self.vehicle = vehicle
        self.onClose = onClose
        // Safety check: if vehicle was deleted, its modelContext becomes nil
        // Accessing properties of a deleted SwiftData object can crash
        guard let vehicle, vehicle.modelContext != nil else {
            _type = State(initialValue: .car)
            _brandModel = State(initialValue: "")
            _color = State(initialValue: "")
            _plate = State(initialValue: "")
            _notes = State(initialValue: "")
            _trailer = State(initialValue: nil)
            return
        }
        _type = State(initialValue: vehicle.type)
        _brandModel = State(initialValue: vehicle.brandModel)
        _color = State(initialValue: vehicle.color)
        _plate = State(initialValue: vehicle.plate)
        _notes = State(initialValue: vehicle.notes)
        _trailer = State(initialValue: vehicle.trailer)
        // the photo is decoded in .task: list rows build this view eagerly
    }

    /// Always edit the context-attached instance.
    /// Passing model objects through navigation can sometimes result in a detached copy;
    /// refetching by id guarantees we're editing the persisted row and prevents duplicates.
    private var editableVehicle: Vehicle? {
        guard let vehicle else { return nil }
        do {
            let id = vehicle.id
            let descriptor = FetchDescriptor<Vehicle>(predicate: #Predicate { $0.id == id })
            return try modelContext.fetch(descriptor).first
        } catch {
            print("ERROR: failed to refetch vehicle for editing: \(error)")
            return vehicle
        }
    }

    // MARK: - Helpers
    private var currentVehicle: Vehicle? { editableVehicle }

    private var logsForCurrentVehicle: [DriveLog] {
        guard let v = currentVehicle else { return [] }
        // Avoid reading v.id here (can crash on device/TestFlight due to SwiftData invalid backing data).
        return allDriveLogs.filter { $0.vehicle === v }
    }

    private var checklistsForCurrentVehicle: [Checklist] {
        guard let v = currentVehicle else { return [] }
        // Show only checklists directly attached to this vehicle; do not include legacy type-only lists.
        return allChecklists.filter { $0.vehicle === v }
    }

    @ViewBuilder
    private var driveLogsSection: some View {
        if currentVehicle != nil {
            Section {
              Fold(title: "Drive logs", summary: listSummary(logsForCurrentVehicle.map(\.date))) {
                if logsForCurrentVehicle.isEmpty {
                    Text("No drive logs yet").foregroundStyle(.secondary)
                } else {
                    ForEach(logsForCurrentVehicle.prefix(3)) { log in
                        NavigationLink {
                            DriveLogEditorView(log: log, isNew: false, lockVehicle: true)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(VehicleDriveLogTitleFormatter.title(for: log.date))
                                if !log.reason.isEmpty {
                                    Text(log.reason).font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                CloudKitSyncService.shared.markDeleted(entityType: "DriveLog", id: log.id)
                                modelContext.delete(log)
                                do { try modelContext.save() } catch { print("ERROR: failed deleting drive log: \(error)") }
                                Task { await CloudKitSyncService.shared.pushDeletions() }
                                NotificationCenter.default.post(name: Notification.Name("RequestFullSyncNotification"), object: nil)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                Button { showingNewDriveLog = true } label: {
                    Label("Add Drive Log", systemImage: "plus")
                }
              }
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var checklistsSection: some View {
        if currentVehicle != nil {
            Section {
              Fold(title: "Checklists", summary: listSummary(checklistsForCurrentVehicle.map(\.lastEdited))) {
                if checklistsForCurrentVehicle.isEmpty {
                    Text("No checklists yet").foregroundStyle(.secondary)
                } else {
                    ForEach(checklistsForCurrentVehicle.prefix(3)) { cl in
                        NavigationLink {
                            ChecklistEditorView(checklist: cl)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cl.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(cl.lastEdited, style: .date)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                deleteChecklistLocally(cl, in: modelContext)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                Button {
                    guard let vehicle else { return }
                    // Create checklist immediately from template and open editor.
                    let title = ChecklistTitle.make(for: vehicle.type, date: .now)
                    let items = ChecklistTemplates.items(for: vehicle.type)
                    let new = Checklist(vehicleType: vehicle.type,
                                        title: title,
                                        items: items,
                                        lastEdited: .now,
                                        vehicle: vehicle)

                    modelContext.insert(new)
                    do { try modelContext.save() } catch { print("ERROR: failed saving new checklist: \(error)") }
                    Task { await CloudKitSyncService.shared.pushAllToCloud() }
                    NotificationCenter.default.post(name: Notification.Name("RequestFullSyncNotification"), object: nil)
                    newChecklistToEdit = new
                } label: {
                    Label("Add Checklist", systemImage: "plus")
                }
              }
            }
        } else {
            EmptyView()
        }
    }

    var body: some View {
        // after Delete the object is gone while the screen is still closing; reading it would crash
        if let vehicle, vehicle.modelContext == nil { Color.clear } else { content }
    }

    private var content: some View {
        Form {
            Section("Type") {
                // All options in the same view (no submenu)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach([VehicleType.car, .van, .truck, .trailer, .camper, .boat, .scooter, .motorbike, .other]) { typeButton($0) }
                    }
                    .padding(.vertical, 4)
                    .frame(minHeight: 56)
                }
            }

            Section("Details") {
                TextField("Brand / Model", text: $brandModel)
                TextField("Color", text: $color)

                // Plate field with scan button
                HStack {
                    TextField("Plate", text: $plate)
                    Button {
                        showingPlateScanner = true
                    } label: { Image(systemName: "camera.viewfinder") }
                    .buttonStyle(.bordered)
                }
                .sheet(isPresented: $showingPlateScanner) {
                    PlateScannerView { recognized in
                        self.plate = recognized
                        showingPlateScanner = false
                    }
                }

                TextField("Notes", text: $notes, axis: .vertical)
            }

            // Trailer linking rules:
            // - Never allow: Trailer, Boat, Motorbike/Scooter
            // - Allow: Car, Van, Truck, Camper, Other
            if allowsTrailer {
                Section {
                    Fold(title: "Trailer", summary: trailer.map { $0.brandModel.isEmpty ? ($0.plate.isEmpty ? "Trailer" : $0.plate) : $0.brandModel } ?? "None") {
                        TrailerPickerInline(selection: $trailer)
                    }
                }
            } else {
                // Ensure we don't keep an invalid trailer link when switching types.
                if trailer != nil {
                    Section("Trailer") {
                        Text("This vehicle type can’t be linked to a trailer.")
                            .foregroundStyle(.secondary)
                        Button("Remove linked trailer", role: .destructive) {
                            trailer = nil
                        }
                    }
                }
            }

            // Car photo area
            Section {
              Fold(title: "Photo", summary: carPhoto == nil ? "No photo" : "Photo added") {
                if let carPhoto {
                    Image(uiImage: carPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(12)
                }
                // keep inline picker as well (set on main thread to avoid race conditions)
                CarPhotoPickerView { data in
                    guard let data else { return }
                    newPhotoData = data
                    carPhoto = UIImage(data: data)
                    photoRemoved = false
                }

                // allow removing an existing photo when editing
                if vehicle != nil && carPhoto != nil {
                    Button(role: .destructive) {
                        carPhoto = nil
                        newPhotoData = nil
                        photoRemoved = true
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                    }
                }
              }
            }

            driveLogsSection

            checklistsSection

            Section(footer: Text("Last edited: \(vehicle?.lastEdited ?? .now, style: .date) \(vehicle?.lastEdited ?? .now, style: .time)")) {
                // Add a zero-height spacer row to satisfy Section's content requirement
                Color.clear.frame(height: 0.0001)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(vehicle == nil ? "New Vehicle" : "Edit Vehicle")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { close() } }

            if vehicle != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
        .confirmationDialog("Delete this vehicle?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                close()
                if let vehicle { deleteVehicleCascade(vehicle, in: modelContext) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its drive logs and checklists are deleted too. This can't be undone.")
        }
        .alert("Save error", isPresented: Binding(get: { saveErrorMessage != nil }, set: { if !$0 { saveErrorMessage = nil } })) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "Unknown error")
        }
        .fullScreenCover(item: $newChecklistToEdit) { cl in
            NavigationStack {
                ChecklistEditorView(checklist: cl)
            }
            .environment(\.modelContext, modelContext)
        }
        .fullScreenCover(isPresented: $showingNewDriveLog) {
            Group {
                if let vehicle {
                    NavigationStack {
                        if newDriveLogToEdit == nil {
                            ProgressView()
                                .onAppear {
                                    // saved and synced only when the user taps Save in the editor
                                    let new = DriveLog(vehicle: vehicle)
                                    modelContext.insert(new)
                                    newDriveLogToEdit = new
                                }
                        } else if let newDriveLogToEdit {
                            DriveLogEditorView(log: newDriveLogToEdit, isNew: true, lockVehicle: true)
                        } else {
                            EmptyView()
                        }
                    }
                    .environment(\.modelContext, modelContext)
                    .onDisappear { newDriveLogToEdit = nil }
                } else {
                    EmptyView()
                }
            }
        }
        .task {
            if carPhoto == nil, !photoRemoved, newPhotoData == nil, let data = vehicle?.photoData {
                carPhoto = UIImage(data: data)
            }
        }
    }

    private var allowsTrailer: Bool { [.car, .van, .truck, .camper, .other].contains(type) }

    private func close() { if let onClose { onClose() } else { dismiss() } }

    /// "3 · latest 28 Oct 2026" or "None yet"
    private func listSummary(_ dates: [Date]) -> String {
        guard let last = dates.max() else { return "None yet" }
        return "\(dates.count) · latest \(last.formatted(date: .abbreviated, time: .omitted))"
    }

    private func save() {
        let now = Date()
        do {
            if let vehicle = editableVehicle {
                // If type changed to .trailer, convert the Vehicle to a Trailer entity
                if type == .trailer && vehicle.type != .trailer {
                    // Create a new Trailer with the vehicle's data
                    let newTrailer = Trailer(
                        brandModel: brandModel,
                        color: color,
                        plate: plate,
                        notes: notes,
                        lastEdited: now
                    )
                    newTrailer.photoData = photoRemoved ? nil : (newPhotoData ?? vehicle.photoData)
                    modelContext.insert(newTrailer)

                    // Unlink any trailer that was attached to this vehicle
                    if let previousTrailer = vehicle.trailer {
                        previousTrailer.linkedVehicle = nil
                    }

                    // Move checklists from vehicle to the new trailer
                    if let vehicleChecklists = vehicle.checklists {
                        for checklist in vehicleChecklists {
                            checklist.vehicle = nil
                            checklist.trailer = newTrailer
                            checklist.vehicleType = .trailer
                        }
                    }

                    // Tombstone the vehicle without cascade (its checklists just moved to the trailer),
                    // then tombstone + delete its drive logs (trailers don't have drive logs).
                    CloudKitSyncService.shared.markDeleted(entityType: "Vehicle", id: vehicle.id, cascade: false, autoSync: false)
                    for log in vehicle.driveLogs ?? [] {
                        CloudKitSyncService.shared.markDeleted(entityType: "DriveLog", id: log.id, autoSync: false)
                        modelContext.delete(log)
                    }

                    modelContext.delete(vehicle)
                    try modelContext.save()
                    // Request immediate sync after converting vehicle to trailer
                    Task { await CloudKitSyncService.shared.pushDeletions() }
                    NotificationCenter.default.post(name: Notification.Name("RequestFullSyncNotification"), object: nil)
                    close()
                    return
                }

                // Resolve the selected trailer to a managed instance in this context.
                var managedTrailer: Trailer? = nil
                if allowsTrailer, let sel = trailer {
                    let selId = sel.id
                    if let fetched = try? modelContext.fetch(FetchDescriptor<Trailer>(predicate: #Predicate { $0.id == selId })).first {
                        managedTrailer = fetched
                    } else {
                        // Insert the instance so it becomes managed in this context
                        modelContext.insert(sel)
                        managedTrailer = sel
                    }
                }

                let previousTrailer = vehicle.trailer

                vehicle.type = type
                vehicle.brandModel = brandModel
                vehicle.color = color
                vehicle.plate = plate
                vehicle.notes = notes
                vehicle.trailer = managedTrailer
                vehicle.lastEdited = now

                if previousTrailer !== managedTrailer {
                    previousTrailer?.linkedVehicle = nil
                }
                managedTrailer?.linkedVehicle = vehicle

                if let newPhotoData { vehicle.photoData = newPhotoData } else if photoRemoved { vehicle.photoData = nil }
                try modelContext.save()
                NotificationCenter.default.post(name: Notification.Name("RequestFullSyncNotification"), object: nil)
            } else {
                // When type is .trailer, create a Trailer entity instead of a Vehicle
                // so it can be linked to other vehicles later.
                if type == .trailer {
                    let newTrailer = Trailer(brandModel: brandModel, color: color, plate: plate, notes: notes, lastEdited: now)
                    newTrailer.photoData = newPhotoData
                    modelContext.insert(newTrailer)
                    try modelContext.save()
                    NotificationCenter.default.post(name: Notification.Name("RequestFullSyncNotification"), object: nil)
                } else {
                    // Resolve selected trailer to managed instance for the new vehicle
                    var managedTrailer: Trailer? = nil
                    if allowsTrailer, let sel = trailer {
                        let selId = sel.id
                        if let fetched = try? modelContext.fetch(FetchDescriptor<Trailer>(predicate: #Predicate { $0.id == selId })).first {
                            managedTrailer = fetched
                        } else {
                            modelContext.insert(sel)
                            managedTrailer = sel
                        }
                    }

                    let new = Vehicle(type: type, brandModel: brandModel, color: color, plate: plate, notes: notes, trailer: managedTrailer, lastEdited: now)

                    managedTrailer?.linkedVehicle = new

                    new.photoData = newPhotoData
                    modelContext.insert(new)
                    try modelContext.save()
                    NotificationCenter.default.post(name: Notification.Name("RequestFullSyncNotification"), object: nil)
                }
            }

            // Trigger CloudKit sync after save
            Task { await CloudKitSyncService.shared.pushAllToCloud() }

            close()
        } catch {
            saveErrorMessage = "Failed to save vehicle: \(error)"
            print(saveErrorMessage!)
        }
    }

    private func typeButton(_ t: VehicleType) -> some View {
        Button {
            type = t
        } label: {
            VStack(spacing: 6) {
                t.icon.0.resizable().scaledToFit().frame(width: 28, height: 28)
                Text(t.displayName).font(.caption)
            }
            .padding(8)
            .background(type == t ? Color.accentColor.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .frame(width: 78)
     }
}

struct TrailerPickerInline: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selection: Trailer?

    // Existing trailers
    @Query(sort: \Trailer.lastEdited, order: .reverse) private var trailers: [Trailer]

    // Needed to enforce uniqueness: find which trailers are already linked.
    @Query private var vehicles: [Vehicle]

    @State private var showingNewTrailer = false
    @State private var refreshID = UUID() // Force view refresh

    private var trailersAlreadyLinked: Set<UUID> {
        Set(vehicles.compactMap { $0.trailer?.id })
    }

    private var availableTrailers: [Trailer] {
        // Allow selecting unlinked trailers + the currently selected one.
        trailers.filter { t in
            if selection?.id == t.id { return true }
            return !trailersAlreadyLinked.contains(t.id)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Existing", selection: $selection) {
                Text("None").tag(Trailer?.none)
                ForEach(availableTrailers) { t in
                    Text(t.brandModel.isEmpty ? (t.plate.isEmpty ? "Trailer" : t.plate) : t.brandModel)
                        .tag(Trailer?.some(t))
                }
            }
            .pickerStyle(.menu)

            Button {
                showingNewTrailer = true
            } label: {
                Label("Add New Trailer", systemImage: "plus.circle")
            }
            .fullScreenCover(isPresented: $showingNewTrailer) {
                NavigationStack {
                    NewTrailerFormView { newTrailer in
                        modelContext.insert(newTrailer)
                        selection = newTrailer
                        do { try modelContext.save() } catch { print("ERROR: failed saving new trailer: \(error)") }
                        NotificationCenter.default.post(name: Notification.Name("RequestFullSyncNotification"), object: nil)
                        // Force view refresh so the Picker shows the newly inserted trailer immediately.
                        refreshID = UUID()
                        showingNewTrailer = false
                    }
                }
            }
        }
        .id(refreshID)
    }
}

private struct NewTrailerFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existing: Trailer? = nil
    var onCreate: ((Trailer) -> Void)? = nil
    /// set in the right column on wide screens
    var onClose: (() -> Void)? = nil
    @State private var showingDeleteConfirm = false

    @State private var brandModel: String
    @State private var color: String
    @State private var plate: String
    @State private var notes: String
    @State private var showingPlateScanner = false
    @State private var trailerPhoto: UIImage? = nil
    /// downscaled JPEG of a newly picked photo; written only on Save
    @State private var newPhotoData: Data? = nil

    @Query(sort: \Checklist.lastEdited, order: .reverse) private var allChecklists: [Checklist]
    @State private var newChecklistToEdit: Checklist? = nil

    init(existing: Trailer? = nil, onCreate: ((Trailer) -> Void)? = nil, onClose: (() -> Void)? = nil) {
        self.existing = existing
        self.onCreate = onCreate
        self.onClose = onClose
        // Safety check: if trailer was deleted, its modelContext becomes nil
        guard let existing, existing.modelContext != nil else {
            _brandModel = State(initialValue: "")
            _color = State(initialValue: "")
            _plate = State(initialValue: "")
            _notes = State(initialValue: "")
            return
        }
        _brandModel = State(initialValue: existing.brandModel)
        _color = State(initialValue: existing.color)
        _plate = State(initialValue: existing.plate)
        _notes = State(initialValue: existing.notes)
        // the photo is decoded in .task: list rows build this view eagerly
    }

    private func close() { if let onClose { onClose() } else { dismiss() } }

    private var checklistsForTrailer: [Checklist] {
        guard let existing else { return [] }
        return allChecklists.filter { $0.trailer === existing }
    }

    var body: some View {
        // after Delete the object is gone while the screen is still closing; reading it would crash
        if let existing, existing.modelContext == nil { Color.clear } else { content }
    }

    private var content: some View {
        Form {
            Section("Details") {
                TextField("Brand / Model", text: $brandModel)
                TextField("Color", text: $color)

                HStack {
                    TextField("Plate", text: $plate)
                    Button { showingPlateScanner = true } label: { Image(systemName: "camera.viewfinder") }
                        .buttonStyle(.bordered)
                }
                .sheet(isPresented: $showingPlateScanner) {
                    PlateScannerView { recognized in
                        self.plate = recognized
                        showingPlateScanner = false
                    }
                }

                TextField("Notes", text: $notes, axis: .vertical)
            }

            Section {
              Fold(title: "Photo", summary: trailerPhoto == nil ? "No photo" : "Photo added") {
                if let trailerPhoto {
                    Image(uiImage: trailerPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(12)
                }

                CarPhotoPickerView { data in
                    guard let data else { return }
                    newPhotoData = data
                    trailerPhoto = UIImage(data: data)
                }
              }
            }

            if existing != nil {
                Section {
                  Fold(title: "Checklists", summary: checklistsForTrailer.isEmpty ? "None yet" : "\(checklistsForTrailer.count) · latest \(checklistsForTrailer[0].lastEdited.formatted(date: .abbreviated, time: .omitted))") {
                    if checklistsForTrailer.isEmpty {
                        Text("No checklists yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(checklistsForTrailer.prefix(3)) { cl in
                            NavigationLink {
                                ChecklistEditorView(checklist: cl)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cl.title)
                                    Text(cl.lastEdited, style: .date)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Button {
                        guard let existing else { return }
                        let title = ChecklistTitle.make(for: .trailer, date: .now)
                        let items = ChecklistTemplates.items(for: .trailer)
                        let new = Checklist(vehicleType: .trailer,
                                            title: title,
                                            items: items,
                                            lastEdited: .now,
                                            trailer: existing)
                        modelContext.insert(new)
                        try? modelContext.save()
                        Task { await CloudKitSyncService.shared.pushAllToCloud() }
                        NotificationCenter.default.post(name: Notification.Name("RequestFullSyncNotification"), object: nil)
                        newChecklistToEdit = new
                    } label: {
                        Label("Add Checklist", systemImage: "plus")
                    }
                  }
                }
            }
        }
        .navigationTitle(existing == nil ? "New Trailer" : "Edit Trailer")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { close() } }

            if existing != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let existing {
                        existing.brandModel = brandModel
                        existing.color = color
                        existing.plate = plate
                        existing.notes = notes
                        existing.lastEdited = .now
                        if let newPhotoData { existing.photoData = newPhotoData }
                        try? modelContext.save()
                        // Trigger CloudKit sync after save
                        Task { await CloudKitSyncService.shared.pushAllToCloud() }
                        NotificationCenter.default.post(name: Notification.Name("RequestFullSyncNotification"), object: nil)
                        close()
                    } else {
                        let t = Trailer(brandModel: brandModel, color: color, plate: plate, notes: notes, lastEdited: .now)
                        t.photoData = newPhotoData
                        onCreate?(t)
                        // Trigger CloudKit sync after save
                        Task { await CloudKitSyncService.shared.pushAllToCloud() }
                        NotificationCenter.default.post(name: Notification.Name("RequestFullSyncNotification"), object: nil)
                        close()
                    }
                } label: {
                    Text("Save").fontWeight(.semibold)
                }
            }
        }
        .confirmationDialog("Delete this trailer?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                close()
                if let existing { deleteTrailerCascade(existing, in: modelContext) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its checklists are deleted too. This can't be undone.")
        }
        .fullScreenCover(item: $newChecklistToEdit) { cl in
            NavigationStack {
                ChecklistEditorView(checklist: cl)
            }
            .environment(\.modelContext, modelContext)
        }
        .task {
            if trailerPhoto == nil, newPhotoData == nil, let data = existing?.photoData {
                trailerPhoto = UIImage(data: data)
            }
        }
    }
}

private enum VehicleDriveLogTitleFormatter {
    static func title(for date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
