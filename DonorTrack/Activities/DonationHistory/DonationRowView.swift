//
//  DonationRowView.swift
//  DonorTrack
//
//  Created by Hunter Dobbelmann on 1/13/23.
//

import SwiftUI

// I used this so we don't access 'donation' if it has been deleted
//            if let donation = provider.exists(donation, in: provider.viewContext) {

struct DonationRowView: View {
    // moc is the current context this view is in.
    // It uses the environments managedObjectContext to make sure it saves
    // on the main context within this view
    // 'try provider.persist(in: moc)' is an example of it in use
    @Environment(\.managedObjectContext) private var moc
	@EnvironmentObject var dataController: DataController

    // If we wanted to make changes to the moc from this view,
    // such as tapping a star to mark something as favorite,
    // we would need to mark our donation object as an ObservedObject
    // so the views re-draw
    @ObservedObject var donation: DonationEntity
//    let dataController: DataController

    var showNotes: Bool

    var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack {
				dateAndTimeInfo

				Spacer()

				HStack(spacing: 8) {
					Text("\(donation.protein, specifier: "%.1f")")
				}
			}

			donationNote
		}
	}
}

//struct DonationRowView_Previews: PreviewProvider {
//    static var previews: some View {
//        let previewProvider = DataController.shared
//		DonationRowView(
//			donation: .example,
//			dataController: previewProvider,
//			showNotes: .constant(true)
//		)
//            .padding()
//            .previewLayout(.sizeThatFits)
//    }
//}

extension DonationRowView {
    private var dateAndTimeInfo: some View {
        HStack {
            VStack {
                Text(donation.donationStartTime, format: .dateTime.month())
                Text(donation.donationStartTime, format: .dateTime.day())
            }
            .font(.system(.body, design: .rounded))
            .bold()
            .padding(.trailing, 8)

            VStack(alignment: .leading) {
                // day of week
                Text(donation.donationStartTime, format: .dateTime.weekday(.wide))
                    .font(.system(.title3, design: .rounded))
                    .bold()

                HStack {
                    Text(donation.donationStartTime, style: .time)
                    Text("(\(donation.durationString))")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

	@ViewBuilder
	private var donationNote: some View {
		if showNotes && !donation.donationNotes.isEmpty {
			Text(donation.donationNotes)
				.font(.caption)
				.foregroundColor(.secondary)
				.padding(5)
				.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
		}
	}
}
