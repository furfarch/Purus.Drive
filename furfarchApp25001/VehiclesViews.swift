import SwiftUI
import SwiftData

struct VehiclesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]
    @State private var showingAdd = false

    var body: some View {
        List {
            ForEach(vehicles) { v in
                NavigationLink {
                    VehicleFormView(vehicle: v).environment(\.modelContext, modelContext)
                } label: {
                    HStack(spacing: 12) {
                        vehicleIcon(for: v)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .foregroundStyle(.primary)
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
        .navigationTitle("Vehicles")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Label("Add", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                AddVehicleFlowView()
            }
            .environment(\.modelContext, modelContext)
        }
    }

    private func vehicleIcon(for v: Vehicle) -> Image {
        switch v.type {
        case .car:
            if v.trailer != nil { return Image("car_with_trailer_2") }
            return Image(systemName: "car")
        case .van:
            if v.trailer != nil { return Image("car_with_trailer_2") }
            return Image("icons8-van-100")
        case .truck:
            if v.trailer != nil { return Image("icons8-truck-with-trailer-50") }
            return Image(systemName: "truck.box")
        case .trailer:
            return Image("icons8-utility-trailer-96")
        case .camper:
            return Image("icons8-camper-100")
        case .boat:
            return Image(systemName: "sailboat")
        case .motorbike:
            return Image("icons8-motorbike-100")
        case .other:
            return Image(systemName: "questionmark.circle")
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

    var body: some View {
        Form {
            Section("Type") {
                // All options in the same view (no submenu)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        typeButton(.car, label: "Car", systemName: "car")
                        typeButton(.van, label: "Van", assetName: "icons8-van-100")
                        typeButton(.truck, label: "Truck", systemName: "truck.box")
                        typeButton(.trailer, label: "Trailer", assetName: "icons8-utility-trailer-96")
                        typeButton(.camper, label: "Camper", assetName: "icons8-camper-100")
                        typeButton(.boat, label: "Boat", assetName: "icons8-boat-100", systemNameFallback: "sailboat")
                        typeButton(.motorbike, label: "Motorbike", assetName: "icons8-motorbike-100")
                        typeButton(.other, label: "Other", systemNameFallback: "questionmark.circle")
                    }
                    .padding(.vertical, 4)
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

            Section("Trailer (Optional)") {
                TrailerPickerInline(selection: $trailer)
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
                            print("DEBUG: VehicleFormView carPhoto set (vehicle id=\(vehicle?.id.uuidString ?? "new"))")
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

            if vehicle != nil {
                Section("Actions") {
                    // Add Drive Log and Checklist will be wired in next increment
                    NavigationLink("Add Drive Log") { Text("Drive Log Form (coming next)") }
                    NavigationLink("Add Checklist") { Text("Checklist Form (coming next)") }
                }
            }

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
            // Update the local state for type
            type = t
            print("DEBUG: selected type=\(t)")
        } label: {
            VStack(spacing: 6) {
                if let assetName { Image(assetName).resizable().scaledToFit().frame(width: 28, height: 28) }
                else if let systemName { Image(systemName: systemName).resizable().scaledToFit().frame(width: 28, height: 28) }
                else if let systemNameFallback { Image(systemName: systemNameFallback).resizable().scaledToFit().frame(width: 28, height: 28) }
                Text(label).font(.caption)
            }
            .padding(8)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct TrailerPickerInline: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selection: Trailer?
    @Query(sort: \Trailer.lastEdited, order: .reverse) private var trailers: [Trailer]
    @State private var creating = false
    @State private var newBrandModel = ""
    @State private var newColor = ""
    @State private var newPlate = ""
    @State private var newNotes = ""

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
                creating.toggle()
            } label: {
                Label(creating ? "Cancel New Trailer" : "Create New Trailer", systemImage: creating ? "xmark.circle" : "plus.circle")
            }

            if creating {
                TextField("Brand / Model", text: $newBrandModel)
                TextField("Color", text: $newColor)
                TextField("Plate", text: $newPlate)
                TextField("Notes", text: $newNotes, axis: .vertical)
                Button {
                    let t = Trailer(brandModel: newBrandModel, color: newColor, plate: newPlate, notes: newNotes, lastEdited: .now)
                    modelContext.insert(t)
                    selection = t
                    creating = false
                    newBrandModel = ""; newColor = ""; newPlate = ""; newNotes = ""
                } label: {
                    Label("Save Trailer", systemImage: "checkmark.circle")
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
    @State private var saveSuccessMessage: String? = nil

    var body: some View {
        Group {
            if step == 1 {
                Form {
                    Section("Select Type") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                typeButton(.car, label: "Car", systemName: "car")
                                typeButton(.van, label: "Van", assetName: "icons8-van-100")
                                typeButton(.truck, label: "Truck", systemName: "truck.box")
                                typeButton(.trailer, label: "Trailer", assetName: "icons8-utility-trailer-96")
                                typeButton(.camper, label: "Camper", assetName: "icons8-camper-100")
                                typeButton(.boat, label: "Boat", systemName: "sailboat")
                                typeButton(.motorbike, label: "Motorbike", assetName: "icons8-motorbike-100")
                                typeButton(.other, label: "Other", systemName: "questionmark.circle")
                            }
                            .padding(.vertical, 4)
                        }
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
                                    print("DEBUG: AddVehicleFlowView carPhoto set (type=\(type?.rawValue ?? "?")")
                                } else {
                                    print("DEBUG: AddVehicleFlowView CarPhotoPicker returned nil")
                                }
                            }
                        }
                    }

                    Section("Trailer (Optional)") { TrailerPickerInline(selection: $trailer) }
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
        .alert("Success", isPresented: Binding(get: { saveSuccessMessage != nil }, set: { if !$0 { saveSuccessMessage = nil } })) {
            Button("OK", role: .cancel) {
                // Dismiss sheet when user acknowledges success
                dismiss()
                saveSuccessMessage = nil
            }
        } message: { Text(saveSuccessMessage ?? "Vehicle saved successfully!") }
    }

    private func save() {
        guard let type else { return }
        let now = Date()
        let new = Vehicle(type: type, brandModel: brandModel, color: color, plate: plate, notes: notes, trailer: trailer, lastEdited: now)
        // attach photo data if available
        if let img = carPhoto, let data = img.jpegData(compressionQuality: 0.8) {
            new.photoData = data
        }
        modelContext.insert(new)
        do {
            try modelContext.save()
            print("DEBUG: saved new vehicle id=\(new.id) type=\(new.type) brandModel=\(new.brandModel)")
            // show success alert — user will dismiss the sheet by tapping OK
            saveSuccessMessage = "Vehicle saved"
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
