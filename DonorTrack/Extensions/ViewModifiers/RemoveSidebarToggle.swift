//
//  RemoveSidebarToggle.swift
//  DonorTrack
//
//  Created by Hunter Dobbelmann on 4/13/24.
//

import SwiftUI

struct RemoveSidebarToggle: ViewModifier {
	func body(content: Content) -> some View {
		if #available(iOS 17.0, *) {
			content.toolbar(removing: .sidebarToggle)
		} else {
			content
		}
	}
}

extension View {
	var sidebarToggleRemoved: some View {
		modifier(RemoveSidebarToggle())
	}
}
