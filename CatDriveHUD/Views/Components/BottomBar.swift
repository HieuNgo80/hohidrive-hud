import SwiftUI

struct BottomBar: View {
    @Binding var tab: MainTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        tab = item
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.icon)
                            .font(.hohi(20, weight: .bold))
                        Text(item.rawValue)
                            .font(.hohi(11, weight: .bold))
                    }
                    .foregroundStyle(tab == item ? HOHITheme.purple : Color(red: 0.68, green: 0.69, blue: 0.76))
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.white.opacity(0.965))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 18, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.025), lineWidth: 1)
        )
    }
}
