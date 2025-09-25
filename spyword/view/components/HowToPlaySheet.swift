import SwiftUI

struct HowToPlaySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("how_intro")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                    Group {
                        Text("how_step_1").font(.body)
                        Text("how_step_2").font(.body)
                        Text("how_step_3").font(.body)
                        Text("how_step_4").font(.body)
                        Text("how_step_5").font(.body)
                        Text("how_step_6").font(.body)
                        Text("how_step_7").font(.body)
                        Text("how_step_8").font(.body)
                        Text("how_tips").font(.footnote).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
            }
            .navigationTitle(Text("how_to_play_title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
