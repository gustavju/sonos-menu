//
//  ErrorBanner.swift
//  sonos-menu
//

import SwiftUI

struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .padding(6)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    ErrorBanner(message: "Something went wrong")
        .padding()
}
