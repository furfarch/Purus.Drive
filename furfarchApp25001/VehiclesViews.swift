import SwiftUI
import SwiftData

struct VehiclesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]
    @Query(sort: \Trailer.lastEdited, order: .reverse) private var trailers: [Trailer]
    @State private var showingAdd = false

    var body: some View {
        List {
            // Flat list: no sections/grouping
            ForEach(trailers) { t in
                HStack(spacing: 12) {
                    Image("TRAILER_CAR")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .padding(4)
                        .background(Color(.tertiarySystemBackground).opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading) {
                        Text(t.brandModel.isEmpty ? "Trailer" : t.brandModel)
                            .font(.headline)
                        Text(t.plate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(t.lastEdited, style: .time)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        modelContext.delete(t)
                        do { try modelContext.save() } catch { print("Error deleting trailer from list: \(error)") }
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }

            ForEach(vehicles) { v in
                NavigationLink {
                    VehicleFormView(vehicle: v).environment(\.modelContext, modelContext)
                } label: {
                    HStack(spacing: 12) {
                        vehicleIconView(for: v)
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading) {
                            Text(v.brandModel.isEmpty ? v.type.displayName : v.brandModel)
                                .font(.headline)
                            Text(v.plate)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
            }
        }
        .listStyle(.plain)
        .navigationTitle("Vehicles")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add Vehicle")
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                AddVehicleFlowView()
            }
            .environment(\.modelContext, modelContext)
        }
    }

    // New: a View that returns a composed icon (base + optional trailer overlay). Uses adaptive background for dark mode.
    private func vehicleIconView(for v: Vehicle) -> some View {
        // choose base image (either system or asset)
        let base: Image
        switch v.type {
        case .car:
            base = Image(systemName: "car")
        case .van:
            base = Image("VAN")
        case .truck:
            base = Image(systemName: "truck.box")
        case .trailer:
            base = Image("TRAILER_CAR")
        case .camper:
            base = Image("CAMPER")
        case .boat:
            base = Image(systemName: "sailboat")
        case .motorbike:
            // prefer asset if present, else fallback to bicycle symbol
            base = Image("MOTORBIKE")
        case .other:
            base = Image(systemName: "questionmark.circle")
        }

        return GeometryReader { geo in
            ZStack {
                // subtle rounded rect background to improve contrast in dark mode for asset images
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.tertiarySystemBackground))
                    .opacity(0.85)
                base
                    .resizable()
                    .scaledToFit()
                    .padding(4)
                    .foregroundStyle(.primary)

                if v.trailer != nil {
                    // overlay a small trailer icon at bottom-right
                    Image("TRAILER_CAR")
                        .resizable()
                        .scaledToFit()
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
    @State private var showingNewChecklist = false

    // Show last items for this vehicle
    @Query(sort: \DriveLog.date, order: .reverse) private var allDriveLogs: [DriveLog]
    @Query(sort: \Checklist.lastEdited, order: .reverse) private var allChecklists: [Checklist]

    var vehicle: Vehicle?

    init(vehicle: Vehicle?) {
        self.vehicle = vehicle
        _type = State(initialValue: vehicle?.type ?? .car)
        _brandModel = State(initialValue: vehicle?.brandModel ?? "")
        _color = State(initialValue: vehicle?.color ?? "")
        _plate = State(initialValue: vehicle?.plate ?? "")
        _notes = State(initialValue: vehicle?.notes ?? "")
        _trailer = State(initialValue: vehicle?.trailer)

        // preload photo if present
        if let data = vehicle?.photoData, let img = UIImage(data: data) {
            _carPhoto = State(initialValue: img)
        }
    }

    @Query private var trailers: [Trailer]

    // MARK: - Helpers (must be at struct scope)
    private var currentVehicle: Vehicle? { vehicle }

    private var logsForCurrentVehicle: [DriveLog] {
        guard let v = currentVehicle else { return [] }
        return allDriveLogs.filter { $0.vehicle.id == v.id }
    }

    private var checklistsForCurrentVehicle: [Checklist] {
        guard let v = currentVehicle else { return [] }
        // Checklist currently stores vehicleType only.
        return allChecklists.filter { $0.vehicleType == v.type }
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
                                Text(log.date, style: .date)
                                if !log.reason.isEmpty {
                                    Text(log.reason).font(.footnote).foregroundStyle(.secondary)
                                }
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
                                Text(cl.lastEdited, style: .date)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Button { showingNewChecklist = true } label: {
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
                        // Scooter shares the motorbike type in the current data model
                        typeButton(.motorbike, label: "Scooter", systemName: "scooter", systemNameFallback: "bicycle")
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
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            if let vehicle = vehicle {
                ToolbarItem { Button(role: .destructive) { modelContext.delete(vehicle); try? modelContext.save(); dismiss() } label: { Label("Delete", systemImage: "trash") } }
            }
        }
        .alert("Save error", isPresented: Binding(get: { saveErrorMessage != nil }, set: { if !$0 { saveErrorMessage = nil } })) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "Unknown error")
        }
        .sheet(isPresented: $showingNewDriveLog) {
            if let vehicle {
                NavigationStack {
                    DriveLogEditorView(log: DriveLog(vehicle: vehicle), isNew: true, lockVehicle: true)
                }
                .environment(\.modelContext, modelContext)
            }
        }
        .sheet(isPresented: $showingNewChecklist) {
            if let vehicle {
                NavigationStack {
                    CreateChecklistView(onCreate: { new in
                        modelContext.insert(new)
                        try? modelContext.save()
                        showingNewChecklist = false
                    }, preselectedVehicle: vehicle)
                }
                .environment(\.modelContext, modelContext)
            }
        }
    }

    private func save() {
        let now = Date()
        do {
            if let vehicle {
                vehicle.type = type
                vehicle.brandModel = brandModel
                vehicle.color = color
                vehicle.plate = plate
                vehicle.notes = notes
                vehicle.trailer = trailer
                vehicle.lastEdited = now
                if let img = carPhoto, let data = img.jpegData(compressionQuality: 0.8) {
                    vehicle.photoData = data
                }
                try modelContext.save()
            } else {
                let new = Vehicle(type: type, brandModel: brandModel, color: color, plate: plate, notes: notes, trailer: trailer, lastEdited: now)
                if let img = carPhoto, let data = img.jpegData(compressionQuality: 0.8) {
                    new.photoData = data
                }
                modelContext.insert(new)
                try modelContext.save()
            }
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
    @Query(sort: \Trailer.lastEdited, order: .reverse) private var trailers: [Trailer]
    @State private var showingNewTrailer = false
    @State private var refreshID = UUID() // Force view refresh

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Existing", selection: $selection) {
                Text("None").tag(Trailer?.none)
                ForEach(trailers) { t in
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
            .sheet(isPresented: $showingNewTrailer) {
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
    }
}

struct AddVehicleFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var step: Int = 1
    @State private var type: VehicleType? = nil
    @State private var brandModel: String = ""
    @State private var color: String = ""
    @State private var plate: String = ""
    @State private var notes: String = ""
    @State private var trailer: Trailer? = nil

    // add photo + scanner states here as well
    @State private var carPhoto: UIImage? = nil
    @State private var showingPlateScanner = false
    @State private var showingCarPhotoPicker = false
    @State private var saveErrorMessage: String? = nil
    @State private var justSaved = false
    @State private var savedAt: Date? = nil

    // Break out the type selection row to keep the compiler happy.
    private var typeSelectionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                typeButton(.car, label: "Car", systemName: "car")
                typeButton(.van, label: "Van", assetName: "VAN")
                typeButton(.truck, label: "Truck", systemName: "truck.box")
                typeButton(.trailer, label: "Trailer", assetName: "TRAILER_CAR")
                typeButton(.camper, label: "Camper", assetName: "CAMPER")
                typeButton(.boat, label: "Boat", systemName: "sailboat")
                // Scooter shares the motorbike type in the current data model
                typeButton(.motorbike, label: "Scooter", systemName: "scooter")
                typeButton(.motorbike, label: "Motorbike", assetName: "MOTORBIKE")
                typeButton(.other, label: "Other", systemName: "questionmark.circle")
            }
            .padding(.vertical, 4)
            .frame(minHeight: 56)
        }
    }

    var body: some View {
        Group {
            if step == 1 {
                Form {
                    Section("Select Type") {
                        typeSelectionRow
                    }
                }
                .navigationTitle("New Vehicle")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Next") { step = 2 }.disabled(type == nil) }
                }
            } else {
                Form {
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

                    if justSaved {
                        Section {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Saved")
                                Spacer()
                                if let savedAt {
                                    Text(savedAt, style: .time)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    // Car Photo area
                    Section(header: Text("Car Photo")) {
                        if let carPhoto {
                            Image(uiImage: carPhoto)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 160)
                                .clipped()
                                .cornerRadius(12)
                        }
                        CarPhotoPickerView { img in
                            DispatchQueue.main.async {
                                if let img = img {
                                    self.carPhoto = img
                                    let t = type?.rawValue ?? "?"
                                    print("DEBUG: AddVehicleFlowView carPhoto set (type=\(t))")
                                } else {
                                    print("DEBUG: AddVehicleFlowView CarPhotoPicker returned nil")
                                }
                            }
                        }
                    }

                    // Trailer linking rules apply here too.
                    if type == .car || type == .van || type == .truck || type == .camper || type == .other {
                        Section("Trailer (Optional)") { TrailerPickerInline(selection: $trailer) }
                    }
                     Section(footer: Text("Last edited: \(Date(), style: .date) \(Date(), style: .time)")) { EmptyView() }
                 }
                 .navigationTitle("Vehicle Details")
                 .toolbar {
                     ToolbarItem(placement: .cancellationAction) { Button("Back") { step = 1 } }
                     ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(type == nil) }
                 }
             }
         }
         .alert("Save error", isPresented: Binding(get: { saveErrorMessage != nil }, set: { if !$0 { saveErrorMessage = nil } })) {
             Button("OK", role: .cancel) { saveErrorMessage = nil }
         } message: { Text(saveErrorMessage ?? "Unknown error") }
    }

    private func save() {
        guard let type else { return }
        // Enforce invalid trailer links defensively.
        let finalTrailer: Trailer? = (type == .car || type == .van || type == .truck || type == .camper || type == .other) ? trailer : nil
        let now = Date()
        let new = Vehicle(type: type, brandModel: brandModel, color: color, plate: plate, notes: notes, trailer: finalTrailer, lastEdited: now)
        // attach photo data if available
        if let img = carPhoto, let data = img.jpegData(compressionQuality: 0.8) {
            new.photoData = data
        }
        modelContext.insert(new)
        do {
            try modelContext.save()
            print("DEBUG: saved new vehicle id=\(new.id) type=\(new.type) brandModel=\(new.brandModel)")
            justSaved = true
            savedAt = .now
        } catch {
            saveErrorMessage = "Failed to save new vehicle: \(error)"
            print(saveErrorMessage!)
        }
    }

    private func typeButton(_ t: VehicleType, label: String, assetName: String? = nil, systemName: String? = nil) -> some View {
        Button {
            type = t
            print("DEBUG: selected type=\(t)")
        } label: {
            VStack(spacing: 6) {
                if let assetName { Image(assetName).resizable().scaledToFit().frame(width: 28, height: 28) }
                else if let systemName { Image(systemName: systemName).resizable().scaledToFit().frame(width: 28, height: 28) }
                Text(label).font(.caption)
            }
            .padding(8)
            .background(type == t ? Color.accentColor.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct NewTrailerFormView: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (Trailer) -> Void

    @State private var brandModel = ""
    @State private var color = ""
    @State private var plate = ""
    @State private var notes = ""
    @State private var showingPlateScanner = false
    @State private var trailerPhoto: UIImage? = nil

    var body: some View {
        Form {
            Section("Details") {
                TextField("Brand / Model", text: $brandModel)
                TextField("Color", text: $color)

                // Plate field with scan button
                HStack {
                    TextField("Plate", text: $plate)
                    Button {
                        showingPlateScanner = true
                    } label: {
                        Image(systemName: "camera.viewfinder")
                    }
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
                    DispatchQueue.main.async {
                        trailerPhoto = img
                    }
                }
            }
        }
        .navigationTitle("New Trailer")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let t = Trailer(brandModel: brandModel, color: color, plate: plate, notes: notes, lastEdited: .now)
                    if let img = trailerPhoto, let data = img.jpegData(compressionQuality: 0.8) {
                        t.photoData = data
                    }
                    onCreate(t)
                    dismiss()
                }
            }
        }
    }
}
