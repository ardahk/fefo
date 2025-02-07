import SwiftUI
import Inject

struct LeaderboardView: View {
    @ObserveInjection var inject
    @EnvironmentObject private var viewModel: FoodEventsViewModel
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, entry in
                    LeaderboardRow(rank: index + 1, entry: entry)
                }
            }
            .navigationTitle("Top Contributors")
            .listStyle(.insetGrouped)
        }
        .enableInjection()
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let entry: FoodEventsViewModel.LeaderboardEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank Circle
            ZStack {
                Circle()
                    .fill(rankBackgroundColor)
                    .frame(width: 36, height: 36)
                
                Text("\(rank)")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            // User Info
            VStack(alignment: .leading) {
                Text(entry.userName)
                    .font(.headline)
                
                Text("\(entry.points) points")
                    .font(.subheadline)
                    .foregroundColor(ColorTheme.secondaryText)
            }
            
            Spacer()
            
            // Trophy for top 3
            if rank <= 3 {
                Image(systemName: "trophy.fill")
                    .foregroundColor(rankTrophyColor)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var rankBackgroundColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .brown
        default: return ColorTheme.primary
        }
    }
    
    private var rankTrophyColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .brown
        default: return ColorTheme.primary
        }
    }
} 