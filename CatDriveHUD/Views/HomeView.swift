import SwiftUI
import UIKit

struct HomeView: View {
    @ObservedObject var model: DriveViewModel
    let onStart: () -> Void

    private var canAddStop: Bool {
        guard model.stops.count < model.maxStops, let last = model.stops.last else { return false }
        return !last.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canStart: Bool {
        model.stops.contains { !$0.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        ZStack(alignment: .top) {
            HOHITheme.background.ignoresSafeArea()

            HomeMapHero(model: model)
                .frame(height: 350)
                .ignoresSafeArea(edges: .top)

            routeCard
                .padding(.horizontal, 16)
                .padding(.top, 275)
                .padding(.bottom, 102)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Where are you going?")
                .font(.hohi(24, weight: .heavy))
                .foregroundStyle(HOHITheme.ink)

            Divider().opacity(0.40)

            currentLocationRow

            destinationList

            addLocationButton

            if model.isCalculating {
                HStack(spacing: 9) {
                    ProgressView().scaleEffect(0.82)
                    Text(model.statusText.isEmpty ? "Building route…" : model.statusText)
                        .font(.hohi(11.5, weight: .medium))
                        .foregroundStyle(HOHITheme.muted)
                        .lineLimit(2)
                    Spacer()
                }
            } else if !model.statusText.isEmpty && model.statusText != "Ready for a new trip" && model.statusText != "Sẵn sàng cho chuyến mới" {
                Text(model.statusText)
                    .font(.hohi(11.5, weight: .medium))
                    .foregroundStyle(HOHITheme.muted)
                    .lineLimit(2)
            }

            startRouteButton

            Text("You can add up to \(model.maxStops) destinations")
                .font(.hohi(11, weight: .medium))
                .foregroundStyle(HOHITheme.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
        .background(Color.white.opacity(0.965))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.075), radius: 24, y: 10)
    }

    private var destinationList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(model.stops.enumerated()), id: \.element.id) { index, stop in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 52)
                            .opacity(0.32)
                    }

                    RouteStopRow(
                        model: model,
                        stopID: stop.id,
                        number: index + 1
                    )
                }
            }
            .padding(.bottom, 2)
        }
        // Không dùng .interactively ở đây: nó chính là kiểu hành vi dễ làm keyboard tụt
        // khi danh sách/suggestion thay đổi trong lúc TextField đang focus.
        .scrollDismissesKeyboard(.never)
        .frame(maxHeight: min(CGFloat(max(model.stops.count, 1)) * 86.0, 210.0))
    }

    private var addLocationButton: some View {
        Button {
            guard canAddStop else { return }
            withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                model.addStop()
            }
            // Không tự bật keyboard cho chặng mới. Người dùng chạm vào Destination mới để nhập.
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.hohi(14, weight: .black))

                Text(model.stops.count >= model.maxStops ? "Maximum destinations reached" : "Add Location")
                    .font(.hohi(14, weight: .bold))

                Spacer()

                Text("\(model.stops.count)/\(model.maxStops)")
                    .font(.hohi(11, weight: .black))
                    .foregroundStyle(HOHITheme.muted)
            }
            .foregroundStyle(canAddStop ? HOHITheme.purple : HOHITheme.muted.opacity(0.42))
            .padding(.horizontal, 15)
            .frame(height: 50)
            .background(HOHITheme.purple.opacity(canAddStop ? 0.05 : 0.02))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        HOHITheme.purple.opacity(canAddStop ? 0.22 : 0.07),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canAddStop)
    }

    private var startRouteButton: some View {
        Button {
            guard canStart else { return }
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            model.startOrContinue()
            onStart()
        } label: {
            HStack {
                Text("Get The Route")
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.hohi(20, weight: .semibold))
            }
            .font(.hohi(15.5, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(height: 57)
            .background(HOHITheme.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: HOHITheme.purple.opacity(0.22), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!canStart || model.isCalculating)
        .opacity(canStart ? 1 : 0.40)
    }

    private var currentLocationRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(HOHITheme.purple.opacity(0.10))
                    .frame(width: 40, height: 40)
                Image(systemName: "location.fill")
                    .font(.hohi(14, weight: .black))
                    .foregroundStyle(HOHITheme.purple)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Your Current Location")
                    .font(.hohi(14, weight: .semibold))
                    .foregroundStyle(HOHITheme.ink)
                Text(model.currentLocation == nil ? "Locating…" : "Your current position")
                    .font(.hohi(12, weight: .medium))
                    .foregroundStyle(HOHITheme.muted)
            }

            Spacer()
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Decorative map hero for Home

private struct HomeMapHero: View {
    @ObservedObject var model: DriveViewModel

    private var speedText: String {
        guard let speed = model.currentLocation?.speed, speed >= 0 else { return "0" }
        return "\(max(0, Int(speed * 3.6)))"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.95, blue: 0.985),
                        Color(red: 0.985, green: 0.982, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                homeRoadNetwork(in: geo.size)

                ForEach(0..<15, id: \.self) { index in
                    let x = CGFloat((index * 71) % 360) / 360.0 * geo.size.width
                    let y = 92 + CGFloat((index * 53) % 170)
                    let width = CGFloat(36 + ((index * 17) % 42))
                    let height = CGFloat(24 + ((index * 11) % 30))

                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                        .frame(width: width, height: height)
                        .rotationEffect(.degrees(Double((index % 5) - 2) * 5.0))
                        .position(x: x, y: y)
                        .shadow(color: HOHITheme.purple.opacity(0.035), radius: 4, y: 2)
                }

                homeRoute(in: geo.size)

                Circle()
                    .fill(Color.blue)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(color: Color.blue.opacity(0.30), radius: 10)
                    .position(x: geo.size.width * 0.55, y: geo.size.height * 0.79)

                VStack(spacing: 4) {
                    Text("HOHI DRIVE")
                        .font(.hohi(20, weight: .heavy))
                        .tracking(0.45)
                        .foregroundStyle(HOHITheme.ink)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(model.hudConnected ? HOHITheme.purple : HOHITheme.pink)
                            .frame(width: 7, height: 7)
                        Text(model.hudConnected ? "HUD Connected" : "HUD Not Connected")
                            .font(.hohi(11.5, weight: .semibold))
                            .foregroundStyle(model.hudConnected ? HOHITheme.purple : HOHITheme.muted)
                    }
                }
                .position(x: geo.size.width * 0.50, y: 74)

                VStack(spacing: 0) {
                    Text(speedText)
                        .font(.hohi(27, weight: .heavy))
                        .foregroundStyle(HOHITheme.ink)
                    Text("km/h")
                        .font(.hohi(10, weight: .semibold))
                        .foregroundStyle(HOHITheme.muted)
                }
                .frame(width: 72, height: 72)
                .background(Color.white.opacity(0.86))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
                .position(x: geo.size.width - 55, y: 122)

                LinearGradient(
                    colors: [Color.white.opacity(0.0), HOHITheme.background.opacity(0.96)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 90)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .clipped()
    }

    @ViewBuilder
    private func homeRoadNetwork(in size: CGSize) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: -20, y: 120))
                path.addCurve(
                    to: CGPoint(x: size.width + 20, y: 205),
                    control1: CGPoint(x: size.width * 0.25, y: 65),
                    control2: CGPoint(x: size.width * 0.65, y: 255)
                )
            }
            .stroke(Color.white.opacity(0.88), style: StrokeStyle(lineWidth: 13, lineCap: .round))

            Path { path in
                path.move(to: CGPoint(x: size.width * 0.15, y: 62))
                path.addCurve(
                    to: CGPoint(x: size.width * 0.85, y: 310),
                    control1: CGPoint(x: size.width * 0.45, y: 105),
                    control2: CGPoint(x: size.width * 0.30, y: 255)
                )
            }
            .stroke(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: 10, lineCap: .round))

            Path { path in
                path.move(to: CGPoint(x: -10, y: 285))
                path.addCurve(
                    to: CGPoint(x: size.width + 10, y: 145),
                    control1: CGPoint(x: size.width * 0.30, y: 330),
                    control2: CGPoint(x: size.width * 0.72, y: 95)
                )
            }
            .stroke(Color.white.opacity(0.72), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        }
    }

    @ViewBuilder
    private func homeRoute(in size: CGSize) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.43, y: 115))
                path.addCurve(
                    to: CGPoint(x: size.width * 0.58, y: size.height * 0.79),
                    control1: CGPoint(x: size.width * 0.28, y: 170),
                    control2: CGPoint(x: size.width * 0.74, y: 215)
                )
            }
            .stroke(Color.white.opacity(0.92), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))

            Path { path in
                path.move(to: CGPoint(x: size.width * 0.43, y: 115))
                path.addCurve(
                    to: CGPoint(x: size.width * 0.58, y: size.height * 0.79),
                    control1: CGPoint(x: size.width * 0.28, y: 170),
                    control2: CGPoint(x: size.width * 0.74, y: 215)
                )
            }
            .stroke(HOHITheme.purple.opacity(0.82), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }
    }
}
