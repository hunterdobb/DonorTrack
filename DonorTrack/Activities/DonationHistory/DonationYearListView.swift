//
//  DonationYearListView.swift
//  DonorTrack
//
//  Created by Hunter Dobbelmann on 4/22/24.
//

import SwiftUI

struct DonationYearListView: View {
	@EnvironmentObject private var dataController: DataController

	@SectionedFetchRequest private var sectionedSelectedYearDonations: SectionedFetchResults<String, DonationEntity>

	let selectedYear: String

	init(dataController: DataController, year: String) {
		_sectionedSelectedYearDonations = SectionedFetchRequest(
			fetchRequest: dataController.selectedYearDonations(for: year),
			sectionIdentifier: \.donationMonth
		)
		selectedYear = year
	}
	
    var body: some View {
		List {
			ForEach(sectionedSelectedYearDonations) { donationsSection in
				NavigationLink {
					List {
						ForEach(donationsSection) { donation in
							NavigationLink {
								DonationDetailView(donation: donation)
							} label: {
								DonationRowView(donation: donation, showNotes: false)
							}
						}
					}
					.navigationBarTitleDisplayMode(.inline)
					.navigationTitle(donationsSection.id)
				} label: {
					donationSectionLabel(
						title: donationsSection.id,
						donations: Array(donationsSection)
					)
				}

			}
		}
		.navigationBarTitleDisplayMode(.inline)
		.navigationTitle(selectedYear)
    }

	private func donationSectionLabel(title: String, donations: [DonationEntity]) -> some View {
		let total = donations.reduce(0) { $0 + Int($1.compensation) }
		let formatted = NumberFormatter.currency.string(from: NSNumber(value: total)) ?? ""

		return VStack(alignment: .leading) {
			Text(title)
				.font(.headline)
			Text("\(donations.count) Donations · \(formatted)")
				.font(.subheadline)
				.foregroundStyle(.secondary)
		}
	}
}


