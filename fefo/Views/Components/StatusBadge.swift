import SwiftUI
import Inject

struct StatusBadge: View {
    @ObserveInjection var inject
    let isActive: Bool
    
    var body: some View {
        Text(isActive ? "Active" : "Ended")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
            )
            .foregroundColor(isActive ? .green : .gray)
            .enableInjection()
    }
}

#Preview {
    VStack {
        StatusBadge(isActive: true)
        StatusBadge(isActive: false)
    }
} 