//
//  EditDonationViewModel.swift
//  DonorTrack
//
//  Created by Hunter Dobbelmann on 1/18/23.
//

import CoreData
import SwiftUI

extension EditDonationView {
    @MainActor
    class ViewModel: ObservableObject {
        @Published var donation: DonationEntity
        @Published var donationDay: Date
        var isNew: Bool

        enum SaveError: Error {
            case notFilledIn, invalidDateRange
        }

        private var tempContext: NSManagedObjectContext? = nil
        var dataController: DataController

        @Published var proteinText = ""
        @Published var compensationText = ""
        @Published var amountText = ""
        @Published var cycleCountText = ""
        @Published var notes = ""
		@Published var showDeleteConfirmation = false

//        @Published var showingAlert = false
//        let alertTitle = "Fill out all the info before saving"

		init(dataController: DataController, donation: DonationEntity? = nil) {
            self.dataController = dataController
			self.isNew = donation == nil

			if let donation {
				self.donation = donation
				donationDay = donation.donationStartTime
				populateFields()
			} else {
				print("NEW")
				let tempContext = NSManagedObjectContext(.mainQueue)
				tempContext.parent = dataController.container.viewContext
				self.tempContext = tempContext
				if let context = self.tempContext {
					self.donation = DonationEntity(context: context)
				} else {
					print("ERROR")
					self.donation = DonationEntity(context: dataController.container.viewContext)
				}

				donationDay = .now
			}

        }

		func deleteDonationTapped() {
			showDeleteConfirmation = true
		}

		func deleteCurrentDonation() {
			dataController.delete(donation)
		}

		/// Updates the start and end times date when the user changes the date of a donation
		/// - Parameter newValue: The new date the user selected
        func updateDay(using newDate: Date) {
            let calendar = Calendar.current
            let newComponents = calendar.dateComponents([.month, .day, .year], from: newDate)

			let existingStartComponents = calendar.dateComponents(
				[.hour,	.minute, .second],
				from: donation.donationStartTime
			)

            var newStartTime = DateComponents()
            newStartTime.month = newComponents.month
            newStartTime.day = newComponents.day
            newStartTime.year = newComponents.year
            newStartTime.hour = existingStartComponents.hour
            newStartTime.minute = existingStartComponents.minute
            newStartTime.second = existingStartComponents.second

            let existingEndComponents = calendar.dateComponents([.hour, .minute, .second], from: donation.donationEndTime)
            var newEndTime = DateComponents()
            newEndTime.month = newComponents.month
            newEndTime.day = newComponents.day
            newEndTime.year = newComponents.year
            newEndTime.hour = existingEndComponents.hour
            newEndTime.minute = existingEndComponents.minute
            newEndTime.second = existingEndComponents.second

            donation.startTime = calendar.date(from: newStartTime)!
            donation.endTime = calendar.date(from: newEndTime)!
        }

        private func fieldsValidated() -> Bool {
            !(amountText.isEmpty) &&
            !(proteinText.isEmpty) &&
            !(compensationText.isEmpty) &&
            !(cycleCountText.isEmpty)
        }

        private func populateFields() {
//            proteinText = String(donation.protein.rounded())
//            compensationText = String(donation.compensation)
//            amountText = String(donation.amountDonated)
//            cycleCountText = String(donation.cycleCount)
            notes = donation.donationNotes
        }

        // Used when creating manual donation
        private func setData() {
            if let protein = Double(proteinText),
               let compensation = Int16(compensationText),
               let amountDonated = Int16(amountText),
               let cycleCount = Int16(cycleCountText) 
			{
                donation.protein = protein
                donation.compensation = compensation
                donation.amountDonated = amountDonated
                donation.cycleCount = cycleCount
            }
        }

        // Used when updating existing donation
        func updateData() {
            if !proteinText.isEmpty {
                if let protein = Double(proteinText) {
                    donation.protein = protein
                }
            }

            if !compensationText.isEmpty {
                if let compensation = Int16(compensationText) {
                    donation.compensation = compensation
                }
            }

            if !amountText.isEmpty {
                if let amountDonated = Int16(amountText) {
                    donation.amountDonated = amountDonated
                }
            }

            if !cycleCountText.isEmpty {
                if let cycleCount = Int16(cycleCountText) {
                    donation.cycleCount = cycleCount
                }
            }
        }

		func save() throws {
            if isNew {
                if fieldsValidated() {
                    if donation.donationStartTime < donation.donationEndTime {
                        setData()

						if let context = tempContext {
							do {
								try context.save()
								dataController.save()
								tempContext = nil
							} catch {
								print(error.localizedDescription)
							}
						}
                    } else {
                        throw SaveError.invalidDateRange
                    }
                } else {
                    throw SaveError.notFilledIn
                }
            } else {
                updateData()
                dataController.save()
            }
        }
    }
}
