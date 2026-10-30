import Testing
import Foundation
import CloudKit
import SwiftData
@testable import PurusDrive

@MainActor
@Suite(.serialized)
struct SyncTests {

    private func remoteVehicleRecord(id: UUID, brandModel: String) -> CKRecord {
        let record = CKRecord(recordType: "CD_Vehicle", recordID: CKRecord.ID(recordName: "CD_Vehicle_\(id.uuidString)"))
        record["CD_id"] = id.uuidString
        record["CD_brandModel"] = brandModel
        record["CD_lastEdited"] = Date()
        return record
    }

    @Test func addConflictReplacesOpenEntryForSameRecord() {
        let store = SyncConflictStore.shared
        store.clearAll()
        defer { store.clearAll() }
        let id = UUID()

        let first = SyncConflict(entityType: "Vehicle", entityID: id, localLastEdited: .distantPast, remoteLastEdited: .now, remoteRecord: remoteVehicleRecord(id: id, brandModel: "Old"))
        let second = SyncConflict(entityType: "Vehicle", entityID: id, localLastEdited: .distantPast, remoteLastEdited: .now, remoteRecord: remoteVehicleRecord(id: id, brandModel: "New"))
        store.addConflict(first)
        store.addConflict(second)

        #expect(store.conflicts.count == 1)
        #expect(store.conflicts.first?.id == second.id)
        #expect(store.resolutions[first.id] == nil)
        #expect(store.resolutions[second.id] == .pending)
    }

    @Test func keepRemoteIsSkippedWhenRecordWasEditedSince() async throws {
        let schema = Schema([Vehicle.self, Trailer.self, DriveLog.self, Checklist.self, ChecklistItem.self, DeletedRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let context = container.mainContext
        CloudKitSyncService.shared.setModelContext(context)
        defer { SyncConflictStore.shared.clearAll() }

        let vehicle = Vehicle(brandModel: "Local edit")
        context.insert(vehicle)
        try context.save()

        // conflict was found before the latest local edit
        let conflict = SyncConflict(entityType: "Vehicle", entityID: vehicle.id,
                                    localLastEdited: vehicle.lastEdited.addingTimeInterval(-60),
                                    remoteLastEdited: .now,
                                    remoteRecord: remoteVehicleRecord(id: vehicle.id, brandModel: "Remote"))
        SyncConflictStore.shared.addConflict(conflict)
        await CloudKitSyncService.shared.resolveConflict(conflict, resolution: .keepRemote)

        #expect(vehicle.brandModel == "Local edit")
    }

    @Test func chunkingSplits1000RecordsInto3Batches() {
        let batches = CloudKitSyncService.chunked(Array(0..<1000), size: 400)
        #expect(batches.map(\.count) == [400, 400, 200])
        #expect(batches.flatMap { $0 } == Array(0..<1000))
    }

    @Test func plateScoringKeepsRawPlateOverSubstitutedVariant() {
        // same scoring as PlateRecognizer.recognize: variant score minus 6 per OCR substitution
        let scored = PlateRecognizer.normalizeVariants("AG 1234").map { variant, subs in
            (variant, PlateRecognizer.scorePlateCandidate(variant, baseConfidence: 0.9) - Double(subs) * 6)
        }
        #expect(scored.max(by: { $0.1 < $1.1 })?.0 == "AG1234")
        #expect(!scored.contains { $0.0 == "A61234" })
    }

    @Test func checklistLayoutFollowsTemplateOrder() {
        let items = ChecklistTemplates.items(for: .car)
        let layout = ChecklistTemplates.layout(for: .car)
        let indexes = items.compactMap { layout[ChecklistTemplates.layoutKey($0.section, $0.title)]?.index }
        #expect(!items.isEmpty)
        #expect(indexes.count == items.count)
        #expect(indexes == indexes.sorted())
        #expect(layout[ChecklistTemplates.layoutKey("FRONT UND MOTORRAUM", "Abblendlicht")]!.index < layout[ChecklistTemplates.layoutKey("FRONT UND MOTORRAUM", "Fernlicht")]!.index)
    }
}
