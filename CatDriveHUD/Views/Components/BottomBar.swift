import SwiftUI

struct BottomBar: View {
    @Binding var tab: MainTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MainTab.allCases, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        tab = item
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.hohi(17, weight: .bold))
                        Text(item.rawValue)
                            .font(.hohi(10.5, weight: .bold))
                    }
                    .foregroundStyle(tab == item ? HOHITheme.purple : HOHITheme.muted.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background {
                        if tab == item {
                            Capsule().fill(HOHITheme.purple.opacity(0.085))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.11), radius: 22, y: 9)
    }
}
