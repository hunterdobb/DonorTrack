//
//  ContentView.swift
//  DonorTrack
//
//  Created by Hunter Dobbelmann on 1/13/23.
//

import SwiftUI

struct ContentView: View {
  @EnvironmentObject var dataController: DataController

  var body: some View {
    TabView {
      NewDonationView(dataController: dataController)
        .tabItem {
          Symbols.plusCircle
          Text("New Donation")
        }

      DonationsListView(dataController: dataController)
        .tabItem {
          Symbols.listBullet
          Text("Donations")
        }

      SettingsView()
        .tabItem {
          Symbols.gearShape
          Text("Settings")
        }
    }
    .dynamicTypeSize(.xSmall ... .xxxLarge)
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .environmentObject(DataController.preview)
    //            .environment(\.managedObjectContext, preview.viewContext)
    //            .onAppear { DonationEntity.makePreview(count: 10, in: preview.viewContext) }
  }
}
