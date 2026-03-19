//
//  DataController.swift
//  DonorTrack
//
//  Created by Hunter Dobbelmann on 1/13/23.
//

import CoreData
import SwiftUI

// provider.viewContext is the main context

enum Filter {
	case all, lowProtein
}

final class DataController: ObservableObject {
	// iCloud sync disabled — will re-enable with SQLiteData in a future version
//    let container: NSPersistentCloudKitContainer
    let container: NSPersistentContainer

	@Published var selectedDonation: DonationEntity?

	@Published var searchText = ""
	@Published var sortNewestFirst = true
	@Published var filter = Filter.all

	// TODO: Remove this
    var newContext: NSManagedObjectContext {
        container.newBackgroundContext()
    }

	static var preview: DataController = {
		let dataController = DataController(inMemory: true)
		dataController.createSampleData()
		return dataController
	}()

	static var emptyPreview: DataController = {
		let dataController = DataController(inMemory: true)
		return dataController
	}()

	// We use this in the init when initializing the container. While this isn't required,
	// it is used to fix and issue and make testing more reliable.
	static private let model: NSManagedObjectModel = {
		guard let url = Bundle.main.url(forResource: "DonationsDataModel", withExtension: "momd") else {
			fatalError("Failed to locate model file.")
		}

		guard let managedObjectModel = NSManagedObjectModel(contentsOf: url) else {
			fatalError("Failed to load model file.")
		}

		return managedObjectModel
	}()

    init(inMemory: Bool = false) {
		// iCloud sync disabled — will re-enable with SQLiteData in a future version
//		container = NSPersistentCloudKitContainer(name: "DonationsDataModel", managedObjectModel: Self.model)
		container = NSPersistentContainer(name: "DonationsDataModel", managedObjectModel: Self.model)

        if EnvironmentValues.isPreview || Thread.current.isRunningXCTest || inMemory {
            container.persistentStoreDescriptions.first?.url = .init(fileURLWithPath: "/dev/null")
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
		container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
		// Required: store was previously opened with history tracking enabled.
		// Removing this forces the store into read-only mode.
		container.persistentStoreDescriptions.first?.setOption(
			true as NSNumber,
			forKey: NSPersistentHistoryTrackingKey
		)

		// iCloud sync disabled — will re-enable with SQLiteData in a future version
//		container.persistentStoreDescriptions.first?.setOption(
//			true as NSNumber,
//			forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
//		)
//		NotificationCenter.default.addObserver(
//			forName: .NSPersistentStoreRemoteChange,
//			object: container.persistentStoreCoordinator,
//			queue: .main,
//			using: remoteStoreChanged
//		)

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Unable to load store with error: \(error)")
            }
        }

		// Used to make Core Data Entities show up in CloudKit without having to add them in the UI first.
//	  	do {
//			try container.initializeCloudKitSchema()
//	  	} catch {
//		 	 print("Failed to Initialize CloudKit Schema: \(error.localizedDescription)")
//	  	}
    }

	func sectionedDonationsForSelectedFilters() -> [String: [DonationEntity]] {
		let request = DonationEntity.fetchRequest()
		var predicates = [NSPredicate]()

		let trimmedSearchText = searchText.trimmingCharacters(in: .whitespaces)
		if trimmedSearchText.isEmpty == false {
			let searchPredicate = NSPredicate(format: "notes CONTAINS[c] %@", trimmedSearchText)
			predicates.append(searchPredicate)
		}

		request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
		request.sortDescriptors = [NSSortDescriptor(keyPath: \DonationEntity.startTime, ascending: !sortNewestFirst)]

		let allDonations = (try? container.viewContext.fetch(request)) ?? []

		let sectionedDonations = Dictionary(grouping: allDonations) { donation in
			donation.donationMonth
		}
		return sectionedDonations
	}

	func recentDonations() -> NSFetchRequest<DonationEntity> {
		let request = DonationEntity.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(keyPath: \DonationEntity.startTime, ascending: false)]
		request.fetchLimit = 11

		let donations = results(for: request)
		if donations.count > 10 {
			if donations[9].donationStartOfWeek == donations[10].donationStartOfWeek {
				// Include the 11th donation since it's in the same week as the 10th
				return request
			} else {
				request.fetchLimit = 10
				return request
			}
		}

		return request
	}

	func currentYearDonations() -> NSFetchRequest<DonationEntity> {
		let request = DonationEntity.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(keyPath: \DonationEntity.startTime, ascending: false)]

		let thisYear = Calendar.current.dateInterval(of: .year, for: .now)!
		request.predicate = NSPredicate(format: "startTime >= %@ AND startTime < %@", argumentArray: [thisYear.start, thisYear.end])

		return request
	}

	func previousYearDonations() -> NSFetchRequest<DonationEntity> {
		let request = DonationEntity.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(keyPath: \DonationEntity.startTime, ascending: false)]

		let thisYear = Calendar.current.dateInterval(of: .year, for: .now)!
		let beforeCurrentYearPredicate = NSPredicate(format: "startTime < %@", thisYear.start as NSDate)

		request.predicate = beforeCurrentYearPredicate

		return request
	}

	func selectedYearDonations(for yearString: String) -> NSFetchRequest<DonationEntity> {
		let request = DonationEntity.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(keyPath: \DonationEntity.startTime, ascending: false)]

		let formatter = DateFormatter()
		formatter.dateFormat = "y"
		let selectedYearAsDate = formatter.date(from: yearString)!
		let yearInterval = Calendar.current.dateInterval(of: .year, for: selectedYearAsDate)!

		request.predicate = NSPredicate(format: "startTime >= %@ AND startTime < %@", argumentArray: [yearInterval.start, yearInterval.end])

		return request
	}



//	func previousYearDonations() -> NSFetchRequest<DonationEntity> {
//		let request = DonationEntity.fetchRequest()
//		request.sortDescriptors = [NSSortDescriptor(keyPath: \DonationEntity.startTime, ascending: false)]
//
//		let recentDonations = results(for: recentDonations())
//		let excludeRecentsPredicate = NSPredicate(format: "NOT (self IN %@)", recentDonations)
//
//		let thisYear = Calendar.current.dateInterval(of: .year, for: .now)!
//		let excludeCurrentYearPredicate = NSPredicate(format: "NOT (startTime >= %@ AND startTime < %@)", argumentArray: [thisYear.start, thisYear.end])
//
//		request.predicate = NSCompoundPredicate(type: .and, subpredicates: [excludeRecentsPredicate, excludeCurrentYearPredicate])
//
//		return request
//	}

	func results<T: NSManagedObject>(for fetchRequest: NSFetchRequest<T>) -> [T] {
		return (try? container.viewContext.fetch(fetchRequest)) ?? []
	}

	// iCloud sync disabled — will re-enable with SQLiteData in a future version
//	func remoteStoreChanged(_ notification: Notification) {
//		// Announce a change so our SwiftUI views will reload
//		objectWillChange.send()
//	}

	/// Used when generating preview data
	func deleteAll() {
		delete(DonationEntity.fetchRequest())
		save()
	}

	func createSampleData(count: Int = 10) {
		var date = Calendar.current.date(byAdding: .day, value: -count * 4, to: .now) ?? .now
		let viewContext = container.viewContext

		for donationCounter in 0..<count {
			let isSecondDonationOfWeek = (donationCounter % 2 == 1)
			let donation = DonationEntity(context: viewContext)

			let secondsInMinute = 60.0

			if donationCounter != 0 {
				if isSecondDonationOfWeek {
					date = Calendar.current.date(byAdding: .day, value: 5, to: date)!
				} else {
					date = Calendar.current.date(byAdding: .day, value: 2, to: date)!
				}
			}

			donation.amountDonated = Int16.random(in: 690...695)
			donation.compensation = isSecondDonationOfWeek ? 80 : 50
			donation.cycleCount = isSecondDonationOfWeek ? 9 : 8
			donation.startTime = date
			donation.endTime = donation.donationStartTime + (Double.random(in: 32...45) * secondsInMinute)
			donation.protein = Double.random(in: 6.0...7.2)
			donation.notes = "This is an example donation for previews \(donationCounter)"
		}

		try? viewContext.save()
	}

	func exists(_ donation: DonationEntity/*, in context: NSManagedObjectContext*/) -> DonationEntity? {
		try? container.viewContext.existingObject(with: donation.objectID) as? DonationEntity
    }

//	func existsInStorage(_ donation: DonationEntity) -> DonationEntity? {
//		let donationsRequest = DonationEntity.fetchRequest()
//		donationsRequest.includesPendingChanges = false
//		let dons = FetchRequest(fetchRequest: donationsRequest)
//		try? container.viewContext.existingObject(with: donation.objectID) as? DonationEntity
//	}

	func newDonation() -> DonationEntity {
		let donation = DonationEntity(context: container.viewContext)
		let now = Date.now
		donation.startTime = now
		donation.endTime = now
		return donation
	}

	func count<T>(for fetchRequest: NSFetchRequest<T>) -> Int {
		(try? container.viewContext.count(for: fetchRequest)) ?? 0
	}

	func delete(_ object: NSManagedObject) {
		objectWillChange.send()
		container.viewContext.delete(object)
		selectedDonation = nil
		if container.viewContext.hasChanges {
			try? container.viewContext.save()
		}
    }

	// Delete using a fetch request:	1. Find all issues or tags or whatever object
	private func delete(_ fetchRequest: NSFetchRequest<NSFetchRequestResult>) {
		// 2. Convert that to be a batch delete for that thing (issue, tag, etc.)
		let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
		// 3. When the things are deleted, send back an array of the unique identifiers for the things that got deleted
		batchDeleteRequest.resultType = .resultTypeObjectIDs

		// 4. Execute the request here
		if let delete = try? container.viewContext.execute(batchDeleteRequest) as? NSBatchDeleteResult {
			// 5. put the array of id's to be deleted into dictionary of type [NSDeletedObjectsKey : [NSManagedObjectID]]
			// Note: 'delete.result' is of type 'Any?' but we know it will be of type '[NSManagedObjectID]'
			// 		because in step 3 we set 'batchDeleteRequest.resultType = .resultTypeObjectIDs'
			//		(This is just an old api so it's not very modern.)
			let changes = [NSDeletedObjectsKey: delete.result as? [NSManagedObjectID] ?? []]
			// 6. Merge the array of changes into our live viewContext, so our live viewContext matches
			// the changes we made in the persistent store
			NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [container.viewContext])
		}
	}

	func save() {
		// Clear any queued saves since we are about to save now
//		saveTask?.cancel()

		if container.viewContext.hasChanges {
			try? container.viewContext.save()
//			WidgetCenter.shared.reloadAllTimelines()
			print("Saved!")
		}
	}

    func persist(in context: NSManagedObjectContext) throws {
        if context.hasChanges {
            try context.save()
        }
    }
}

extension EnvironmentValues {
    static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

extension Thread {
	var isRunningXCTest: Bool {
		for key in threadDictionary.allKeys {
			guard let keyAsString = key as? String else { continue }
			if keyAsString.split(separator: ".").contains("xctest") { return true }
		}
		return false
	}
}
