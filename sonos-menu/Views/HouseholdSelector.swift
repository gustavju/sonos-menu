//
//  HouseholdSelector.swift
//  sonos-menu
//

import SwiftUI

struct HouseholdSelector: View {
    let households: [Household]
    @Binding var selectedHouseholdID: String?
    let onSelect: (Household?) -> Void

    var body: some View {
        if households.count > 1 {
            Picker("Household", selection: Binding(
                get: { selectedHouseholdID ?? households.first?.id },
                set: { newValue in
                    selectedHouseholdID = newValue
                    onSelect(households.first { $0.id == newValue })
                }
            )) {
                ForEach(households) { household in
                    Text(household.id.prefix(8))
                        .tag(household.id as String?)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

#Preview {
    HouseholdSelector(
        households: [
            Household(id: "household-a", groups: []),
            Household(id: "household-b", groups: [])
        ],
        selectedHouseholdID: .constant(nil),
        onSelect: { _ in }
    )
    .padding()
}
