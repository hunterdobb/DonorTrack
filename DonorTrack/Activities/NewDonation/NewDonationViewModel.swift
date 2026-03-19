//
//  NewDonationViewModel.swift
//  DonorTrack
//
//  Created by Hunter Dobbelmann on 1/15/23.
//

import ActivityKit
import CoreData
import SwiftUI


@available(iOS 16.2, *)
class NewDonationActivity: ObservableObject {
	// TODO: I need to look up how to do it properly.
	// I put it here to limit it to iOS 16.2

	// Used for live activity and dynamic island
	static let shared = NewDonationActivity()

	@Published var activity: Activity<NewDonationAttributes>? = nil
}

// Extension is used for name-spacing
// Makes vm only available to be used in NewDonationView
extension NewDonationView {
	@MainActor
    class ViewModel: ObservableObject {
		@AppStorage("startTime") var startTime 		= Date.distantFuture.timeIntervalSince1970
		@AppStorage("endTime") var endTime 			= Date.distantFuture.timeIntervalSince1970
		@AppStorage("amountText") var amountText 	= ""
		@AppStorage("proteinText") var proteinText 	= ""
		@AppStorage("compensationText") var compensationText = ""
		@AppStorage("cycleCount") var cycleCount 	= 0
		@AppStorage("notes") var notes				= ""
		@AppStorage("donationState") var donationState: NewDonationState = .idle

		// Used for the saved checkmark animation
		@Published var isSaved = false

		// Alerts
		@Published var showingNotFilledInAlert = false
		@Published var showingFinishConfirmationAlert = false
		@Published var showingResetConfirmationAlert = false

		// Should be set before showing each alert
		var alertTitle = ""
		var alertMessage = ""

        private var donation: DonationEntity
        private var context: NSManagedObjectContext
        private let dataController: DataController

		enum NewDonationState: Int {
			// rawValue of Int so it can be saved in @AppStorage
			case idle = 0, started, finished
		}

		// MARK: - Computed Properties
		var actionButtonText: String {
			switch donationState {
			case .idle: return "Start Donation"
			case .started: return "Finish Donation"
			case .finished: return "Save Donation"
			}
		}

		var actionButtonColor: Color {
			switch donationState {
			case .idle: return .blue
			case .started: return .pink
			case .finished: return .mint
			}
		}

		var donationDurationString: String {
			if endTime >= startTime {
				return (Date(timeIntervalSince1970: startTime)...Date(timeIntervalSince1970: endTime)).asDurationString()
			}

			return "Invalid Range"
		}

		var canUndoCycleCount: Bool { cycleCount > 0 }

		// MARK: - Init
        init(dataController: DataController) {
            self.dataController = dataController
            self.context = dataController.newContext
            self.donation = DonationEntity(context: self.context)
        }

		// MARK: - Intents
        func save() throws {
			donation.startTime 		= Date(timeIntervalSince1970: startTime)
			donation.endTime 		= Date(timeIntervalSince1970: endTime)
			donation.notes 			= notes
			donation.amountDonated 	= Int16(amountText)!
			donation.protein 		= Double(proteinText)!
			donation.compensation 	= Int16(compensationText)!
			donation.cycleCount 	= Int16(cycleCount)

            try context.save()
        }

        func actionButtonTapped() {
			switch donationState {
			case .idle: // start
				startTime = Date.now.timeIntervalSince1970
				startLiveActivity()
				donationState = .started
				hapticImpact(.rigid)
			case .started: // finish
				alertTitle = "Finished?"
				showingFinishConfirmationAlert = true
				// finishDonation() is called from view
			case .finished: // save
				if fieldsValidated() {
					do {
						try save()
						isSaved = true
						resetView()
					} catch {
						print(error)
					}
				} else {
					alertTitle = "Fill out all the info before saving"
					alertMessage = "Enter 0 if you don't want to provide a value for any field."
					showingNotFilledInAlert = true
				}
			}
        }

		// Called from view
		func finishDonation() {
			endTime = Date.now.timeIntervalSince1970
			endLiveActivity()
			donationState = .finished
		}

		func resetView() {
			endLiveActivity()
			donationState = .idle
			amountText = ""
			proteinText = ""
			compensationText = ""
			cycleCount = 0
			notes = ""
			startTime = Date.distantFuture.timeIntervalSince1970
			endTime = Date.distantFuture.timeIntervalSince1970

			// Create new DonationEntity to edit
			// We have to update the context so we have new data to work with
			// If we don't do this, donations that we reset will still exist and get saved when we call context.save()
			// This is bc we were making new DonationEntity's in the same context
			context = dataController.newContext
			donation = DonationEntity(context: context)
		}

		func incrementCycleCount() {
			cycleCount += 1

			if #available(iOS 16.2, *) {
				updateLiveActivity()
			}

			hapticImpact(.rigid)
		}

		func undoCycleCount() {
			if canUndoCycleCount {
				cycleCount -= 1

				if #available(iOS 16.2, *) {
					updateLiveActivity()
				}
			}

			hapticImpact(.rigid)
		}

		// MARK: - Live Activity
		private func startLiveActivity() {
			if #available(iOS 16.2, *) {
				let activityAttributes = NewDonationAttributes()
				let activityContent = NewDonationAttributes.NewDonationStatus(startTime: .now, cycleCount: cycleCount)

				do {
					NewDonationActivity.shared.activity = try Activity.request(attributes: activityAttributes,
																			   contentState: activityContent,
																			   pushType: nil)
				} catch {
					print(error.localizedDescription)
				}
			}
		}

		private func endLiveActivity() {
			if #available(iOS 16.2, *) {
				guard startTime != Date.distantFuture.timeIntervalSince1970 else { return }
				let finishedDonationStatus = NewDonationAttributes.NewDonationStatus(startTime: Date(timeIntervalSince1970: startTime), cycleCount: cycleCount)
				let finalContent = ActivityContent(state: finishedDonationStatus, staleDate: nil)

				Task {
					for activity in Activity<NewDonationAttributes>.activities {
						await activity.end(finalContent, dismissalPolicy: .immediate)
					}
				}
			}
		}

		@available(iOS 16.2, *)
		private func updateLiveActivity() {
			guard startTime != Date.distantFuture.timeIntervalSince1970 else { return }
			let updatedDonationStatus = NewDonationAttributes.NewDonationStatus(startTime: Date(timeIntervalSince1970: startTime), cycleCount: cycleCount)
			let updatedContent = ActivityContent(state: updatedDonationStatus, staleDate: nil)

			Task { await NewDonationActivity.shared.activity?.update(updatedContent) }
		}

		// MARK: - Private Functions
		private func fieldsValidated() -> Bool {
			!(amountText.isEmpty) && !(proteinText.isEmpty) && !(compensationText.isEmpty)
		}
    }
}
