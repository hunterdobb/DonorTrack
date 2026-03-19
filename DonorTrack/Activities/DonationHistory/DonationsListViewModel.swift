//
//  DonationsListViewModel.swift
//  DonorTrack
//
//  Created by Hunter Dobbelmann on 1/17/23.
//

import CoreData
import SwiftUI

struct SearchConfig: Equatable {
    enum Filter {
        case all, lowProtein
    }

    var query: String = ""
    var filter: Filter = .all
}

enum Sort {
    case newestFirst, oldestFirst
}

extension DonationsListView {
	@dynamicMemberLookup
    @MainActor
    class ViewModel: ObservableObject {
        var dataController: DataController

        @Published var donationToEdit: DonationEntity?
        @Published var searchConfig = SearchConfig()
		@Published var showNewDonationSheet = false

		var showNotes: Bool {
			dataController.searchText.isEmpty == false
		}

        init(dataController: DataController) {
            self.dataController = dataController
        }

		subscript<Value>(dynamicMember keyPath: KeyPath<DataController, Value>) -> Value {
			dataController[keyPath: keyPath]
		}

		subscript<Value>(dynamicMember keyPath: ReferenceWritableKeyPath<DataController, Value>) -> Value {
			get { dataController[keyPath: keyPath] }
			set { dataController[keyPath: keyPath] = newValue }
		}

		func totalEarnedAllTime(_ donations: FetchedResults<DonationEntity>) -> Double {
			let compensations = donations.map { Int($0.compensation) }
			let total = compensations.reduce(0, +)
			return Double(total)
		}

		func delete(_ offsets: IndexSet) {
			let donations = (try? dataController.container.viewContext.fetch(DonationEntity.all())) ?? []

			for offset in offsets {
				let item = donations[offset]
				dataController.delete(item)
			}
		}
    }
}
