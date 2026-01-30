import SwiftUI
import SwiftData
import UIKit

struct VehiclesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]
    @Query(sort: \Trailer.lastEdited, order: .reverse) private var trailers: [Trailer]

    // Trailers linked to vehicles should not appear as standalone rows.
    private var linkedTrailerIDs: Set<UUID> {
        Set(vehicles.compactMap { $0.trailer?.id })
    }

    private var unlinkedTrailers: [Trailer] {
        trailers.filter { !linkedTrailerIDs.contains($0.id) }
    }

    var body: some View {
        List {
            // Header row: plain text + icons (NOT a toolbar title)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) { Image(systemName: "car"); Text("Vehicles") }
                HStack(spacing: 6) { Image(systemName: "road.lanes"); Text("Drive Log") }
                HStack(spacing: 6) { Image(systemName: "checklist"); Text("Checklists") }
            }
            .font(.footnote)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)

            // Unlinked trailers (standalone)
            ForEach(unlinkedTrailers) { t in
                NavigationLink {
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
                        modelContext.delete(t)
                        do { try modelContext.save() } catch { print("Error deleting trailer from list: \(error)") }
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }

            // Vehicles + their linked trailer directly underneath
            ForEach(vehicles) { v in
                NavigationLink {
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
                        Text(v.lastEdited, style: .time)
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        modelContext.delete(v)
                        do { try modelContext.save() } catch { print("Error deleting vehicle from list: \(error)") }
                    } label: { Label("Delete", systemImage: "trash") }
                }

                if let t = v.trailer {
                    NavigationLink {
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
        .listStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension VehiclesListView {
    // Vehicle icon helper
    fileprivate func vehicleIconView(for v: Vehicle) -> some View {
        // choose base image (either system or asset)
        let base: Image
        let needsTemplateTint: Bool
        switch v.type {
        case .car:
            base = Image(systemName: "car")
            needsTemplateTint = false
        case .van:
            base = Image("VAN")
            needsTemplateTint = true
        case .truck:
            base = Image(systemName: "truck.box")
            needsTemplateTint = false
        case .trailer:
            base = Image("TRAILER_CAR")
            needsTemplateTint = true
        case .camper:
            base = Image("CAMPER")
            needsTemplateTint = true
        case .boat:
            base = Image(systemName: "sailboat")
            needsTemplateTint = false
        case .motorbike:
            // prefer asset if present
            base = Image("MOTORBIKE")
            needsTemplateTint = true
        case .scooter:
            base = Image("SCOOTER")
            needsTemplateTint = true
        case .other:
            base = Image(systemName: "questionmark.circle")
            needsTemplateTint = false
        }

        return GeometryReader { geo in
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
    @State private var showingPlateScanner = false
    @State private var showingCarPhotoPicker = false
    @State private var saveErrorMessage: String? = nil

    @State private var showingNewDriveLog = false
    @State private var newChecklistToEdit: Checklist? = nil

    @State private var newDriveLogToEdit: DriveLog? = nil

    // Show last items for this vehicle
    @Query(sort: \DriveLog.date, order: .reverse) private var allDriveLogs: [DriveLog]
    @Query(sort: \Checklist.lastEdited, order: .reverse) private var allChecklists: [Checklist]

    var vehicle: Vehicle?

    init(vehicle: Vehicle? = nil) {
        self.vehicle = vehicle
        _type = State(initialValue: vehicle?.type ?? .car)
        _brandModel = State(initialValue: vehicle?.brandModel ?? "")
        _color = State(initialValue: vehicle?.color ?? "")
        _plate = State(initialValue: vehicle?.plate ?? "")
        _notes = State(initialValue: vehicle?.notes ?? "")
        _trailer = State(initialValue: vehicle?.trailer)

        if let data = vehicle?.photoData, let img = UIImage(data: data) {
            _carPhoto = State(initialValue: img)
        }
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
        // Prefer new model: checklists belong to the specific vehicle.
        let direct = allChecklists.filter { $0.vehicle === v }
        if !direct.isEmpty { return direct }
        // Backward compatibility: legacy (type-only) checklists.
        return allChecklists.filter { $0.vehicle == nil && $0.trailer == nil && $0.vehicleType == v.type }
    }

    @ViewBuilder
    private var driveLogsSection: some View {
        if currentVehicle != nil {
            Section("Drive Logs") {
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
                                modelContext.delete(log)
                                do { try modelContext.save() } catch { print("ERROR: failed deleting drive log: \(error)") }
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
    }

    @ViewBuilder
    private var checklistsSection: some View {
        if currentVehicle != nil {
            Section("Checklists") {
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
                                // Clear any log references first.
                                for log in allDriveLogs where log.checklist === cl {
                                    log.checklist = nil
                                }
                                modelContext.delete(cl)
                                do { try modelContext.save() } catch { print("ERROR: failed deleting checklist: \(error)") }
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
                    newChecklistToEdit = new
                } label: {
                    Label("Add Checklist", systemImage: "plus")
                }
            }
        }
    }

    var body: some View {
        Form {
            Section("Type") {
                // All options in the same view (no submenu)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        typeButton(.car, label: "Car", systemName: "car")
                        typeButton(.van, label: "Van", assetName: "VAN")
                        typeButton(.truck, label: "Truck", systemName: "truck.box")
                        typeButton(.trailer, label: "Trailer", assetName: "TRAILER_CAR")
                        typeButton(.camper, label: "Camper", assetName: "CAMPER")
                        typeButton(.boat, label: "Boat", systemName: "sailboat")
                        typeButton(.scooter, label: "Scooter", assetName: "SCOOTER")
                        typeButton(.motorbike, label: "Motorbike", assetName: "MOTORBIKE")
                        typeButton(.other, label: "Other", systemNameFallback: "questionmark.circle")
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
            if type == .car || type == .van || type == .truck || type == .camper || type == .other {
                Section("Trailer (Optional)") {
                    TrailerPickerInline(selection: $trailer)
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
            Section(header: Text("Car Photo")) {
                if let carPhoto {
                    Image(uiImage: carPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(12)
                }
                // keep inline picker as well (set on main thread to avoid race conditions)
                CarPhotoPickerView { img in
                    DispatchQueue.main.async {
                        if let img = img {
                            self.carPhoto = img
                            let vid = vehicle?.id.uuidString ?? "new"
                            print("DEBUG: VehicleFormView carPhoto set (vehicle id=\(vid))")
                        } else {
                            print("DEBUG: VehicleFormView CarPhotoPicker returned nil")
                        }
                    }
                }

                // allow removing an existing photo when editing
                if vehicle != nil && (carPhoto != nil || vehicle?.photoData != nil) {
                    Button(role: .destructive) {
                        if let vehicle = vehicle {
                            vehicle.photoData = nil
                            carPhoto = nil
                            do {
                                try modelContext.save()
                                print("DEBUG: removed photo for vehicle id=\(vehicle.id)")
                            } catch {
                                print("DEBUG: failed to remove photo: \(error)")
                            }
                        }
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                    }
                }
            }

            driveLogsSection

            checklistsSection

            Section(footer: Text("Last edited: \(vehicle?.lastEdited ?? .now, style: .date) \(vehicle?.lastEdited ?? .now, style: .time)")) {
                EmptyView()
            }
        }
        .navigationTitle(vehicle == nil ? "New Vehicle" : "Edit Vehicle")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }

            if let vehicle = vehicle {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        modelContext.delete(vehicle)
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    save()
                } label: {
                    Image(systemName: "internaldrive.fill")
                }
                .accessibilityLabel("Save")
            }
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
            if let vehicle {
                NavigationStack {
                    if newDriveLogToEdit == nil {
                        ProgressView()
                            .onAppear {
                                let new = DriveLog(vehicle: vehicle)
                                modelContext.insert(new)
                                do { try modelContext.save() } catch { print("ERROR: failed inserting new drive log: \(error)") }
                                newDriveLogToEdit = new
                            }
                    } else if let newDriveLogToEdit {
                        DriveLogEditorView(log: newDriveLogToEdit, isNew: true, lockVehicle: true)
                    }
                }
                .environment(\.modelContext, modelContext)
                .onDisappear { newDriveLogToEdit = nil }
            }
        }
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
                    if let img = carPhoto, let data = img.jpegData(compressionQuality: 0.8) {
                        newTrailer.photoData = data
                    }

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

                    // Delete associated drive logs (trailers don't have drive logs)
                    if let driveLogs = vehicle.driveLogs {
                        for log in driveLogs {
                            modelContext.delete(log)
                        }
                    }

                    modelContext.insert(newTrailer)
                    modelContext.delete(vehicle)
                    try modelContext.save()
                    dismiss()
                    return
                }

                // Resolve the selected trailer to a managed instance in this context.
                var managedTrailer: Trailer? = nil
                if let sel = trailer {
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

                if let img = carPhoto, let data = img.jpegData(compressionQuality: 0.8) {
                    vehicle.photoData = data
                }
                try modelContext.save()
            } else {
                // When type is .trailer, create a Trailer entity instead of a Vehicle
                // so it can be linked to other vehicles later.
                if type == .trailer {
                    let newTrailer = Trailer(brandModel: brandModel, color: color, plate: plate, notes: notes, lastEdited: now)
                    if let img = carPhoto, let data = img.jpegData(compressionQuality: 0.8) {
                        newTrailer.photoData = data
                    }
                    modelContext.insert(newTrailer)
                    try modelContext.save()
                } else {
                    // Resolve selected trailer to managed instance for the new vehicle
                    var managedTrailer: Trailer? = nil
                    if let sel = trailer {
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

                    if let img = carPhoto, let data = img.jpegData(compressionQuality: 0.8) {
                        new.photoData = data
                    }
                    modelContext.insert(new)
                    try modelContext.save()
                }
            }

            // Trigger CloudKit sync after save
            Task { await CloudKitSyncService.shared.pushAllToCloud() }

            dismiss()
        } catch {
            saveErrorMessage = "Failed to save vehicle: \(error)"
            print(saveErrorMessage!)
        }
    }

    private func typeButton(_ t: VehicleType, label: String, assetName: String? = nil, systemName: String? = nil, systemNameFallback: String? = nil) -> some View {
        Button {
            type = t
            print("DEBUG: selected type=\(t)")
        } label: {
            VStack(spacing: 6) {
                if let assetName { Image(assetName).resizable().scaledToFit().frame(width: 28, height: 28) }
                else if let systemName { Image(systemName: systemName).resizable().scaledToFit().frame(width: 28, height: 28) }
                else if let fallback = systemNameFallback { Image(systemName: fallback).resizable().scaledToFit().frame(width: 28, height: 28) }
                Text(label).font(.caption)
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

    @State private var brandModel: String
    @State private var color: String
    @State private var plate: String
    @State private var notes: String
    @State private var showingPlateScanner = false
    @State private var trailerPhoto: UIImage? = nil

    @Query(sort: \Checklist.lastEdited, order: .reverse) private var allChecklists: [Checklist]
    @State private var newChecklistToEdit: Checklist? = nil

    init(existing: Trailer? = nil, onCreate: ((Trailer) -> Void)? = nil) {
        self.existing = existing
        self.onCreate = onCreate
        _brandModel = State(initialValue: existing?.brandModel ?? "")
        _color = State(initialValue: existing?.color ?? "")
        _plate = State(initialValue: existing?.plate ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
        if let data = existing?.photoData, let img = UIImage(data: data) {
            _trailerPhoto = State(initialValue: img)
        }
    }

    private var checklistsForTrailer: [Checklist] {
        guard let existing else { return [] }
        return allChecklists.filter { $0.trailer === existing }
    }

    var body: some View {
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

            Section(header: Text("Photo")) {
                if let trailerPhoto {
                    Image(uiImage: trailerPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(12)
                }

                CarPhotoPickerView { img in
                    DispatchQueue.main.async { trailerPhoto = img }
                }
            }

            if existing != nil {
                Section("Checklists") {
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
                        newChecklistToEdit = new
                    } label: {
                        Label("Add Checklist", systemImage: "plus")
                    }
                }
            }
        }
        .navigationTitle(existing == nil ? "New Trailer" : "Edit Trailer")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }

            if let existing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        modelContext.delete(existing)
                        try? modelContext.save()
                        dismiss()
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
                        if let img = trailerPhoto, let data = img.jpegData(compressionQuality: 0.8) {
                            existing.photoData = data
                        }
                        try? modelContext.save()
                        // Trigger CloudKit sync after save
                        Task { await CloudKitSyncService.shared.pushAllToCloud() }
                        dismiss()
                    } else {
                        let t = Trailer(brandModel: brandModel, color: color, plate: plate, notes: notes, lastEdited: .now)
                        if let img = trailerPhoto, let data = img.jpegData(compressionQuality: 0.8) {
                            t.photoData = data
                        }
                        onCreate?(t)
                        // Trigger CloudKit sync after save
                        Task { await CloudKitSyncService.shared.pushAllToCloud() }
                        dismiss()
                    }
                } label: {
                    Image(systemName: "internaldrive.fill")
                }
                .accessibilityLabel("Save")
            }
        }
        .fullScreenCover(item: $newChecklistToEdit) { cl in
            NavigationStack {
                ChecklistEditorView(checklist: cl)
            }
            .environment(\.modelContext, modelContext)
        }
    }
}

private enum VehicleDriveLogTitleFormatter {
    static func title(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd HH:mm"
        return "Drive Log \(df.string(from: date))"
    }
}
