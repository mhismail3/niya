import SwiftUI

struct TajweedGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(TajweedRule.allCases.filter(\.isEnabled)) { rule in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(rule.color)
                                .frame(width: 14, height: 14)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Text(rule.arabicName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(rule.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tajweed Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
