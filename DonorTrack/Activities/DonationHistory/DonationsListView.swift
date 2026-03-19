//
//  DonationsListView.swift
//  DonorTrack
//
//  Created by Hunter Dobbelmann on 1/13/23.
//

import StoreKit
import SwiftUI

struct DonationsListView: View {
	@StateObject var vm: ViewModel
	@EnvironmentObject private var dataController: DataController
	@State private var showEditNewDonation = false

	// Environment value to call as a function to trigger review dialog
	@Environment(\.requestReview) var requestReview: RequestReviewAction
	@EnvironmentObject private var reviewsManager: ReviewRequestManager

	@FetchRequest(fetchRequest: DonationEntity.all()) var donations

	@FetchRequest var recentDonations: FetchedResults<DonationEntity>
	@SectionedFetchRequest var sectionedCurrentYearDonations: SectionedFetchResults<String, DonationEntity>
	@SectionedFetchRequest var sectionedPreviousYearDonations: SectionedFetchResults<String, DonationEntity>

	@State private var searchText = ""

	var searchResults: [DonationEntity] {
		donations.filter { donation in
			donation.donationNotes.contains(searchText)
		}
	}

	init(dataController: DataController) {
		let viewModel = ViewModel(dataController: dataController)
		_vm = StateObject(wrappedValue: viewModel)

		_recentDonations = FetchRequest(fetchRequest: dataController.recentDonations())
		_sectionedCurrentYearDonations = SectionedFetchRequest(
			fetchRequest: dataController.currentYearDonations(),
			sectionIdentifier: \.donationMonth
		)
		_sectionedPreviousYearDonations = SectionedFetchRequest(
			fetchRequest: dataController.previousYearDonations(),
			sectionIdentifier: \.donationYear
		)
	}

	@State private var selectedItem: DonationEntity?

	var body: some View {
		NavigationStack {
			ZStack {
				if donations.isEmpty && searchText.isEmpty {
					emptyStateView.padding(.bottom, 100)

				} else if donations.isEmpty && !searchText.isEmpty {
					Text("No Results")
						.frame(maxHeight: .infinity, alignment: .top)
						.padding(.top)
				} else if !searchText.isEmpty {
					List(selection: $selectedItem) {
						ForEach(searchResults) { donation in
							NavigationLink {
								DonationDetailView(donation: donation)
							} label: {
								DonationRowView(donation: donation, showNotes: !searchText.isEmpty)
							}
						}
					}
				} else {
					VStack {
						List(selection: $selectedItem) {
							if vm.searchText.isEmpty && vm.searchConfig.filter == .all {
								Section {
									HStack {
										totalCompensation
										totalDonations
									}
									.listRowBackground(Color.clear)
									.listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
									.listRowSeparator(.hidden)
								} header: {
									totalHeader
								}
								.textCase(nil)
							}

							Section("Latest Donations") {
								ForEach(recentDonations) { donation in
									NavigationLink {
										DonationDetailView(donation: donation)
									} label: {
										DonationRowView(donation: donation, showNotes: false)
									}
								}
							}

							if sectionedCurrentYearDonations.isEmpty == false {
								Section {
									ForEach(sectionedCurrentYearDonations) { donationsSection in
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
								} header: {
									Text(Date.now.formatted(.dateTime.year()))
										.font(.headline)
								}.textCase(nil)
							}

							if sectionedPreviousYearDonations.isEmpty == false {
								Section {
									ForEach(sectionedPreviousYearDonations) { donationsSection in
										NavigationLink {
											DonationYearListView(dataController: dataController, year: donationsSection.id)
										} label: {
											donationSectionLabel(
												title: "Donations in \(donationsSection.id)",
												donations: Array(donationsSection)
											)
										}
									}
								} header: {
									Text("Previous Years").font(.headline)
								}.textCase(nil)
							}
						}
						.listStyle(.insetGrouped)
						.sheet(isPresented: $vm.showNewDonationSheet) {
							NewDonationView(dataController: dataController)
						}
					}
					.safeAreaInset(edge: .bottom) { filterNotifier }
				}
			}
			.searchable(text: $searchText, prompt: "Search Notes")
			.toolbar(content: optionsMenu)
			.navigationTitle("Donations")
			.sheet(item: $vm.donationToEdit) {
				vm.donationToEdit = nil // onDismiss
			} content: { donation in
				EditDonationView(dataController: dataController, donation: donation)
			}
			.onAppear {
				if reviewsManager.canAskForReview(donationCount: donations.count) {
					requestReview()
				}
			}
			.sheet(isPresented: $showEditNewDonation) {
				EditDonationView(dataController: dataController)
			}
		}
	}
}


// MARK: - Preview
#Preview("List With Data") {
	DonationsListView(dataController: .preview)
		.environmentObject(DataController.preview)
		.environmentObject(ReviewRequestManager())
}

// MARK: - Views
extension DonationsListView {
	private var emptyStateView: some View {
		VStack(spacing: 15) {
			Text("No Donations")
				.frame(maxWidth: .infinity, alignment: .leading)
				.font(.largeTitle.bold())

			Text("Track your donations using the 'New Donation' tab.")
				.frame(maxWidth: .infinity, alignment: .leading)
				.font(.body)

			Text("You can also add donations manually by tapping the button above and selecting 'Add Donation Manually'")
				.frame(maxWidth: .infinity, alignment: .leading)
				.font(.callout)
				.foregroundColor(.primary.opacity(0.6))

			if vm.searchConfig.filter == .lowProtein {
				Divider()
				HStack {
					Symbols.exclamationMarkCircle
					Text("Filtered by Low Protein")
				}
				.foregroundColor(.orange)
				.font(.headline)
			}
		}
		.padding()
		.background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 10))
		.padding()
	}

	private var totalHeader: some View {
		Text("Totals")
			.foregroundColor(.secondary)
			.font(.headline)
			.bold()
	}

	private var totalCompensation: some View {
		GroupBox {
			Text(NumberFormatter.currency.string(from: NSNumber(value: vm.totalEarnedAllTime(donations))) ?? "")
				.font(.system(.title, design: .rounded, weight: .bold))
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(.top, 1)

		} label: {
			Text("Compensation")
				.foregroundStyle(.green)
		}
		.frame(maxWidth: .infinity)
		.groupBoxStyle(WhiteGroupBoxStyle())
	}

	private var totalDonations: some View {
		GroupBox {
			Text("\(donations.count)")
				.font(.system(.title, design: .rounded, weight: .bold))

				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(.top, 1)
		} label: {
			Text("Donations")
				.foregroundStyle(.orange)
		}
		.frame(maxWidth: .infinity)
		.groupBoxStyle(WhiteGroupBoxStyle())
	}

	@ViewBuilder
	private var filterNotifier: some View {
		if vm.searchConfig.filter == .lowProtein {
			HStack {
				Symbols.exclamationMarkCircle
				Text("Filtered by Low Protein")
			}
			.padding(.vertical)
			.foregroundColor(.orange)
			.font(.headline)
			.frame(maxWidth: .infinity)
			.background(.bar)
		}
	}

	@ToolbarContentBuilder
	private func optionsMenu() -> some ToolbarContent {
		ToolbarItem(placement: .primaryAction) {
			Menu {
				Button {
					showEditNewDonation = true
				} label: {
					Label("Add Donation Manually", systemImage: "keyboard")
				}
			} label: {
				Label("Options", systemImage: vm.searchConfig.filter == .lowProtein ?
					  "ellipsis.circle.fill" : "ellipsis.circle")
				.foregroundColor(vm.searchConfig.filter == .lowProtein ? .orange : .blue)
				.font(.title3)
			}
		}

		ToolbarItem {
#if DEBUG
            Button("ADD SAMPLES", systemImage: "flame") {
                dataController.deleteAll()
                dataController.createSampleData(count: 75)
            }
#endif
		}

		ToolbarItem {
#if DEBUG
            Button("DELETE ALL", systemImage: "trash", action: dataController.deleteAll)
#endif
		}
	}

	private func deleteButton(donation: DonationEntity) -> some View {
		Button(role: .destructive) {
			vm.dataController.delete(donation)
		} label: {
			Label("Delete", systemImage: "trash")
		}
	}

	private func editButton(donation: DonationEntity) -> some View {
		Button {
			vm.donationToEdit = donation
		} label: {
			Label("Edit", systemImage: "pencil")
		}
		.tint(.orange)
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

