//
//  NewDonationView.swift
//  DonorTrack
//
//  Created by Hunter Dobbelmann on 1/13/23.
//

import Combine
import SwiftUI

struct NewDonationView: View {
  @StateObject var vm: ViewModel

  @FocusState private var focusedField: FocusedField?
  @State private var tmp = Date()
  @State private var shouldShowSuccess = false
  let maxWidth: CGFloat = 700

  enum FocusedField {
    case donationAmount, protein, compensation, notes
  }

  init(dataController: DataController) {
    let viewModel = ViewModel(dataController: dataController)
    self._vm = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .center) {
            donatingNowInfo
              .frame(maxWidth: maxWidth)
              .padding(.bottom, 8)
              .padding(.top, -8)

            valueFields
              .frame(maxWidth: maxWidth)

            if vm.donationState != .idle {
              cycleCountView
                .frame(maxWidth: maxWidth)
            }

            notesField.padding(.top)
              .frame(maxWidth: maxWidth)

            if focusedField == nil { scrollSpacer }
          }
          .onChange(of: vm.isSaved) { isSaved in
            if isSaved {
              withAnimation(.spring()) {
                shouldShowSuccess.toggle()
                hapticNotification(.success)
              }
            }
          }
          // This fixes a bug where the check mark after saving would stay on the
          // screen if the user quickly changed tabs.
          .onAppear { shouldShowSuccess = false }
          .overlay(content: successCheckmark)
          .onChange(of: vm.donationState) { state in
            // This is a temporary fix to make the timer start updating
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
              if state == .started {
                tmp = .now
              }
            }
          }
          .id("top")  // Used for scrolling to the keyboard
          .padding()
          .onChange(of: focusedField) { _ in
            if focusedField == .notes {
              withAnimation {
                proxy.scrollTo("notes", anchor: .center)
              }
            }

            if focusedField == nil {
              withAnimation {
                proxy.scrollTo("top", anchor: .top)
              }
            }
          }
          .onChange(of: vm.notes) { _ in
            withAnimation {
              proxy.scrollTo("notes", anchor: .bottom)
            }
          }
        }
      }
      .overlay(alignment: .bottom) {
        if focusedField == nil {
          actionButton
        }
      }
      .navigationTitle("New Donation")
      .scrollDismissesKeyboard(.interactively)
      .alert(vm.alertTitle, isPresented: $vm.showingNotFilledInAlert) {
      } message: {
        Text(vm.alertMessage)
      }
      .alert(vm.alertTitle, isPresented: $vm.showingFinishConfirmationAlert) {
        Button("Finish") {
          vm.finishDonation()
        }

        Button("Cancel", role: .cancel) {}
      }
      .alert(vm.alertTitle, isPresented: $vm.showingResetConfirmationAlert) {
        Button("Reset", role: .destructive) {
          vm.resetView()
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(vm.alertMessage)
      }
      .toolbar(content: toolbarContent)
    }
  }
}

struct NewDonationView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      NewDonationView(dataController: .preview)
    }
  }
}

// MARK: - Views Extension
extension NewDonationView {
  @ViewBuilder
  private func successCheckmark() -> some View {
    if shouldShowSuccess {
      CheckmarkView()
        .transition(.scale.combined(with: .opacity))
        .onAppear {
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring()) {
              shouldShowSuccess.toggle()
              vm.isSaved = false
            }
          }
        }
    }
  }

  @ToolbarContentBuilder
  private func toolbarContent() -> some ToolbarContent {
    ToolbarItemGroup(placement: .keyboard) {
      Spacer()
      keyboardToolbarButtons
    }

    ToolbarItem(placement: .destructiveAction) {
      if vm.donationState != .idle {
        Button("Reset") {
          vm.alertTitle = "Are you sure?"
          vm.alertMessage =
            "This will delete all the current info and cannot be undone."
          vm.showingResetConfirmationAlert = true
        }
      }
    }
  }

  private var valueFields: some View {
    VStack(alignment: .leading) {
      Text("Enter Donation Info")
        .padding(.bottom, -2)
        .padding(.leading, 8)
        .foregroundColor(.secondary)
        .font(.headline)

      let amountHint =
        "This is the total amount of plasma you donate this session, measured in milliliters.\n\nThe amount can vary depending on the collection method and your weight."
      let proteinHint =
        "This is the total amount of protein in your blood, measured in grams per deciliter.\n\nYou may have to ask for this measurement during the screening process.\n\nA healthy range is around 6 to 8 g/dL."
      let compensationHint =
        "This is the amount of compensation you earn for this donation."

      ValueField(
        text: $vm.amountText,
        label: "Donation Amount",
        placeholder: "0",
        suffix: "mL",
        color: .cyan,
        hint: amountHint
      )
      .keyboardType(.numberPad)
      .focused($focusedField, equals: .donationAmount)
      .onTapGesture {
        focusedField = .donationAmount
        print("\(String(describing: focusedField))")
      }
      .onChange(of: vm.amountText) { text in
        if Int16(text) == nil {
          vm.amountText = ""
        }
      }

      HStack {
        ValueField(
          text: $vm.proteinText,
          label: "Protein",
          placeholder: "0.0",
          suffix: "g/dL",
          color: .orange,
          hint: proteinHint
        )
        .keyboardType(.decimalPad)
        .focused($focusedField, equals: .protein)
        .onChange(of: vm.proteinText) { text in
          if Double(text) == nil {
            vm.proteinText = ""
          }
        }

        ValueField(
          text: $vm.compensationText,
          label: "Compensation",
          placeholder: "0",
          prefix: "$",
          color: .green,
          hint: compensationHint
        )
        .keyboardType(.numberPad)
        .focused($focusedField, equals: .compensation)
        .onChange(of: vm.compensationText) { text in
          if Int16(text) == nil {
            vm.compensationText = ""
          }
        }
      }
    }
  }

  private var notesField: some View {
    VStack {
      Text("Notes")
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)

      TextField("Add Notes", text: $vm.notes, axis: .vertical)
        .padding(.bottom, 5)
        .focused($focusedField, equals: .notes)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
    .padding(.bottom)
    .id("notes")
  }

  //    private var startDonationTip: some View {
  //        Text("Tap Start Donation below when your donation begins")
  //            .foregroundColor(.secondary)
  //            .font(.headline)
  //            .frame(maxWidth: .infinity)
  //            .padding()
  //            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
  //    }

  private var cycleCountView: some View {
    HStack {
      Text("Cycles: \(vm.cycleCount)")
        .font(.headline)

      Spacer()

      // undo cycle
      Button {
        vm.undoCycleCount()
      } label: {
        Symbols.arrowUTurn
          .frame(width: 50, height: 35)
          .font(.largeTitle)
          .bold()
      }
      .allowsHitTesting(vm.canUndoCycleCount)
      .opacity(vm.canUndoCycleCount ? 1 : 0.3)
      .buttonStyle(.bordered)
      .tint(.orange)
      .buttonBorderShape(.capsule)

      // increment cycle
      Button {
        vm.incrementCycleCount()
      } label: {
        Symbols.plus
          .frame(width: 100, height: 35)
          .font(.largeTitle)
          .bold()
      }
      .buttonStyle(.bordered)
      .tint(.blue)
      .buttonBorderShape(.capsule)

    }
    .padding([.top, .bottom, .trailing], 10)
    .padding(.leading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    .animation(.default, value: vm.donationState)
  }

  private var donatingNowInfo: some View {
    VStack(alignment: .leading) {
      if vm.donationState != .finished {
        HStack {
          Text("Start Time")
          Spacer()
          if vm.donationState == .started {
            Text(Date(timeIntervalSince1970: vm.startTime), style: .time)
              .foregroundColor(.secondary)
          } else {
            Text("Not Started")
              .foregroundColor(.secondary)
          }

        }
      } else if vm.donationState == .finished {
        HStack {
          Text("Time")
          Spacer()
          HStack {
            Text(Date(timeIntervalSince1970: vm.startTime), style: .time)
            Text("-")
            Text(Date(timeIntervalSince1970: vm.endTime), style: .time)
          }
          .foregroundColor(.secondary)
        }
      }

      Divider()

      donationDuration.padding(.top, 5)
    }
    .font(.headline)
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
  }

  @ViewBuilder
  private var donationDuration: some View {
    HStack {
      Text("Duration").font(.headline)
      Spacer()
      if vm.donationState != .finished {  // idle or started
        Text(
          vm.donationState == .idle
            ? "-:--"
            : "\(Date(timeIntervalSince1970: vm.startTime), style: .timer)"
        )
        .monospacedDigit()
        .foregroundColor(.secondary)
      } else {  // finished
        Text(vm.donationDurationString)
          .font(.headline)
          .foregroundColor(.secondary)
      }
    }
  }

  private var actionButton: some View {
    Button {
      vm.actionButtonTapped()
    } label: {
      // This button will switch between Start, Finish, and Save
      Text(vm.actionButtonText)
        .frame(maxWidth: .infinity)
    }
    .frame(maxWidth: maxWidth)
    .font(.system(.largeTitle, design: .rounded))
    .bold()
    .foregroundColor(vm.actionButtonColor)
    .padding(.vertical)
    .background(vm.actionButtonColor.opacity(0.2))
    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
    .padding(.horizontal, 10)
    .padding(.bottom, 8)
  }

  private var keyboardToolbarButtons: some View {
    HStack {
      // Temporary
      Button {
        focusedField = nil
      } label: {
        Symbols.dismissKeyboard
      }
      .font(.headline)
      .frame(maxWidth: .infinity)

      // TODO: keyBoardToolbarButtons
      //            Button {
      //
      //            } label: {
      //                Text("Done")
      //                    .padding(.horizontal, 16)
      //            }
      //            .font(.headline)
      //            .tint(.blue)
      //            .buttonStyle(.bordered)
      //
      //            Spacer()
      //
      //            HStack {
      //                Button {
      //                    print("Clicked")
      //                } label: {
      //                    Text("Previous")
      //                }
      //
      //                Button {
      //                    print("Clicked")
      //                } label: {
      //                    Text("Next")
      //                        .padding(.horizontal, 16)
      //                }
      //            }
      //            .font(.headline)
      //            .buttonStyle(.bordered)
      //            .tint(.blue)
    }
  }

  private var scrollSpacer: some View {
    Text("Scroll Spacer")
      .font(.system(.largeTitle, design: .rounded))
      .hidden()
  }
}
