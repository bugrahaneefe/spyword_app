import SwiftUI

struct DescriptionText: View {
    let inputKey: LocalizedStringKey
    
    var body: some View {
        Text(inputKey)
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 6)
    }
}
