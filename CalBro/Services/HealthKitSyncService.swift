import Foundation
import HealthKit

protocol HealthKitSyncService: Sendable {
    func setConnected(_ isConnected: Bool) async -> HealthSyncStatus
}

final class MockHealthKitSyncService: HealthKitSyncService {
    func setConnected(_ isConnected: Bool) async -> HealthSyncStatus {
        HealthSyncStatus(isConnected: isConnected, statusText: isConnected ? "Connected" : "Mock disconnected")
    }
}

// MARK: - Real HealthKit integration

final class RealHealthKitSyncService: HealthKitSyncService, @unchecked Sendable {
    private let store = HKHealthStore()
    private let appStateStore: AppStateStore

    init(appStateStore: AppStateStore = UserDefaultsAppStateStore()) {
        self.appStateStore = appStateStore
    }

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let active = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(active) }
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }
        if let mass = HKObjectType.quantityType(forIdentifier: .bodyMass) { types.insert(mass) }
        if let height = HKObjectType.quantityType(forIdentifier: .height) { types.insert(height) }
        if let dob = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) { types.insert(dob) }
        if let sex = HKObjectType.characteristicType(forIdentifier: .biologicalSex) { types.insert(sex) }
        types.insert(HKObjectType.workoutType())
        return types
    }

    func setConnected(_ isConnected: Bool) async -> HealthSyncStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            return HealthSyncStatus(isConnected: false, statusText: "Health data unavailable on this device")
        }
        // HealthKit has no programmatic "disconnect"; toggling off just stops reads locally.
        guard isConnected else {
            return HealthSyncStatus(isConnected: false, statusText: "Not syncing")
        }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
        } catch {
            return HealthSyncStatus(isConnected: false, statusText: "Authorization failed")
        }

        // Replace manually-entered profile values with the unified Health source.
        let imported = await importProfileFromHealth()

        let active = await todayActiveEnergyKcal()
        if imported {
            return HealthSyncStatus(isConnected: true, statusText: "Connected · profile synced from Health")
        }
        if let kcal = active {
            return HealthSyncStatus(isConnected: true, statusText: "Connected · \(kcal) kcal burned today")
        }
        return HealthSyncStatus(isConnected: true, statusText: "Connected")
    }

    /// Reads body metrics from the unified Health store and backfills the saved profile.
    /// Returns true if at least one field was updated.
    @discardableResult
    func importProfileFromHealth() async -> Bool {
        var snapshot = appStateStore.load() ?? AppStateSnapshot(onboardingComplete: false, profile: UserProfile())
        var profile = snapshot.profile
        var changed = false

        if let kg = await mostRecentQuantity(.bodyMass, unit: .gramUnit(with: .kilo)) {
            profile.weightKilograms = Int(kg.rounded()); changed = true
        }
        if let cm = await mostRecentQuantity(.height, unit: .meterUnit(with: .centi)) {
            profile.heightCentimeters = Int(cm.rounded()); changed = true
        }
        if let comps = try? store.dateOfBirthComponents(),
           let birthDate = Calendar.current.date(from: comps) {
            let years = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
            if let y = years, y > 0, y < 120 { profile.age = y; changed = true }
        }
        if let hkSex = try? store.biologicalSex().biologicalSex {
            switch hkSex {
            case .male:   profile.sex = .male;   changed = true
            case .female: profile.sex = .female; changed = true
            case .other:  profile.sex = .other;  changed = true
            default: break
            }
        }

        guard changed else { return false }
        profile.recalculateTargets()
        snapshot.profile = profile
        appStateStore.save(snapshot)
        return true
    }

    private func mostRecentQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return nil }
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Reads today's active energy burned (kcal). Returns nil if unauthorized/unavailable.
    func todayActiveEnergyKcal() async -> Int? {
        guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, stats, _ in
                let kcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie())
                continuation.resume(returning: kcal.map { Int($0.rounded()) })
            }
            store.execute(query)
        }
    }
}
