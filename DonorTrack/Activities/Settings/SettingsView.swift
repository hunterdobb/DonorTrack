//
//  SettingsView.swift
//  DonorTrack
//
//  Created by Hunter Dobbelmann on 2/4/23.
//

import SwiftUI

struct SettingsView: View {
	@EnvironmentObject private var reviewsManager: ReviewRequestManager
	@AppStorage(UDKeys.hapticsEnabled) private var isHapticsEnabled = true
	@Environment(\.openURL) var openURL

	var body: some View {
		NavigationSplitView {
			Form {
				Section {
					hapticsToggle
				} footer: {
					Text("Haptics are the small vibrations you feel when tapping on certain buttons.")
				}

				Section {
					tipJar
					rate
				} footer: {
					VStack(alignment: .leading) {
						Text("If you're enjoying Donor Track, please consider rating the app on the App Store.")
						currentVersion
					}
				}
			}
			.sidebarToggleRemoved
			.navigationTitle("Settings")
			
		} detail: {
			Text("Make Selection")
		}
    }

	func getCurrentVersion() -> String {
		// Get the current bundle version for the app. (Similar to Apple sample app)
		if let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
			return "Current Version: \(currentVersion)"
		} else {
			return "error"
		}
	}
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
			.environmentObject(TipStore())
    }
}

private extension SettingsView {
	var hapticsToggle: some View {
		Toggle("Enable Haptics", isOn: $isHapticsEnabled)
	}

	var tipJar: some View {
		NavigationLink {
			TipJarView()
		} label: {
			HStack(alignment: .lastTextBaseline) {
				Image(systemName: "bag.fill")
					.foregroundStyle(.indigo.gradient)
					.imageScale(.large)

				Text("Tip Jar")
					.font(.system(.body, design: .rounded))
			}
		}
	}

	var rate: some View {
		Button {
			if let url = reviewsManager.reviewLink {
				openURL(url)
			}
		} label: {
			HStack(alignment: .lastTextBaseline) {
				Image(systemName: "heart.circle.fill")
					.foregroundStyle(.red.gradient)
					.imageScale(.large)

				Text("Rate Donor Track")
					.font(.system(.body, design: .rounded))
					.foregroundColor(.primary)

				Spacer()

				Image(systemName: "arrow.up.right")
					.fontWeight(.medium)
					.imageScale(.small)
					.foregroundColor(.secondary.opacity(0.6))

			}
		}
	}

	var currentVersion: some View {
		Text(getCurrentVersion())
			.frame(maxWidth: .infinity, alignment: .center)
			.padding(.top)
	}
}
