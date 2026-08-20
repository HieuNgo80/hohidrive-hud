import SwiftUI
import MapKit
import CoreLocation

struct NavigationOverlay: View {
    @ObservedObject var model: DriveViewModel
    let mapView: MKMapView?
    @Binding var showMapOptions: Bool

    private var step: RouteStep? {
        model.routeSteps.indices.contains(model.currentStepIndex)
            ? model.routeSteps[model.currentStepIndex]
            : nil
    }

    private var distanceText: String {
        guard step != nil else { return "—" }
        return NavigationManager.formatDistance(model.currentManeuverDistance)
    }

    private var roadName: String {
        guard let step else { return "Navigation" }
        return step.roadName.isEmpty ? "Continue on route" : step.roadName
    }

    private var maneuverIcon: String {
        switch step?.maneuver {
        case "left": return "arrow.turn.up.left"
        case "right": return "arrow.turn.up.right"
        case "uturn": return "arrow.uturn.left"
        case "roundabout": return "arrow.triangle.2.circlepath"
        case "slight_left", "keep_left", "sharp_left": return "arrow.turn.up.left"
        case "slight_right", "keep_right", "sharp_right": return "arrow.turn.up.right"
        case "arrive": return "checkmark"
        default: return "arrow.up"
        }
    }

    private var speedText: String {
        guard let speed = model.currentLocation?.speed, speed >= 0 else { return "0" }
        return "\(max(0, Int(speed * 3.6)))"
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                NavigationTopCard(
                    distance: distanceText,
                    roadName: roadName,
                    instruction: model.isRerouting ? "Recalculating route…" : (step?.instruction ?? "Calculating direction…"),
                    maneuverIcon: maneuverIcon
                )
                .padding(.horizontal, 14)
                .padding(.top, 48)

                Spacer()
            }

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(spacing: 10) {
                        SpeedBadge(speed: speedText)

                        Button { model.stopNavigation() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "stop.fill")
                                Text("Stop")
                            }
                            .font(.hohi(12.5, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 42)
                            .background(Color.red.opacity(0.92))
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.28), radius: 12, y: 5)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    VStack(spacing: 10) {
                        NavigationCompassButton(model: model)
                        DarkZoomControls(model: model, mapView: mapView)
                        RecenterButton(action: model.centerOnUser, dark: true)
                        NavigationMapOptions(model: model, showMapOptions: $showMapOptions)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 124)
            }

            VStack {
                Spacer()
                NavigationBottomStats(model: model)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct NavigationTopCard: View {
    let distance: String
    let roadName: String
    let instruction: String
    let maneuverIcon: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: maneuverIcon)
                .font(.hohi(36, weight: .black))
                .foregroundStyle(HOHITheme.pink)
                .frame(width: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text(distance)
                    .font(.hohi(30, weight: .black))
                    .foregroundStyle(.white)

                Text(instruction)
                    .font(.hohi(13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.80))
                    .lineLimit(1)

                Text(roadName)
                    .font(.hohi(14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "speaker.wave.2.fill")
                .font(.hohi(15, weight: .bold))
                .foregroundStyle(.white.opacity(0.90))
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.07))
                .clipShape(Circle())
        }
        .padding(16)
        .background(HOHITheme.navCard.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 22, y: 10)
    }
}

private struct SpeedBadge: View {
    let speed: String

    var body: some View {
        VStack(spacing: 0) {
            Text(speed)
                .font(.hohi(34, weight: .black))
                .foregroundStyle(.white)
            Text("km/h")
                .font(.hohi(11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.70))
        }
        .frame(width: 82, height: 82)
        .background(HOHITheme.navCard.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .shadow(color: .black.opacity(0.30), radius: 18, y: 8)
    }
}

private struct NavigationCompassButton: View {
    @ObservedObject var model: DriveViewModel

    var body: some View {
        Button { model.toggleHeading() } label: {
            VStack(spacing: 0) {
                Image(systemName: "location.north.fill")
                    .font(.hohi(15, weight: .black))
                    .foregroundStyle(HOHITheme.pink)
                Text("N")
                    .font(.hohi(9, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)
            .background(HOHITheme.navCard.opacity(0.95))
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.30), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct DarkZoomControls: View {
    @ObservedObject var model: DriveViewModel
    let mapView: MKMapView?

    var body: some View {
        VStack(spacing: 0) {
            Button { model.zoomMap(0.62, mapView: mapView) } label: {
                Image(systemName: "plus")
                    .frame(width: 48, height: 44)
            }
            Divider().background(.white.opacity(0.12))
            Button { model.zoomMap(1.62, mapView: mapView) } label: {
                Image(systemName: "minus")
                    .frame(width: 48, height: 44)
            }
        }
        .frame(width: 48)
        .font(.hohi(17, weight: .bold))
        .foregroundStyle(.white)
        .background(HOHITheme.navCard.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.30), radius: 14, y: 6)
    }
}

private struct NavigationMapOptions: View {
    @ObservedObject var model: DriveViewModel
    @Binding var showMapOptions: Bool

    var body: some View {
        Button { showMapOptions = true } label: {
            Image(systemName: "ellipsis")
                .font(.hohi(16, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(HOHITheme.navCard.opacity(0.95))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.30), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .confirmationDialog("Map Options", isPresented: $showMapOptions) {
            Button("Standard") { model.mapType = .standard }
            Button("Satellite") { model.mapType = .satellite }
            Button("Hybrid") { model.mapType = .hybrid }
            Button("Simulate Arrival") { model.simulateArrival() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct NavigationBottomStats: View {
    @ObservedObject var model: DriveViewModel

    private var remainingTime: String {
        guard !model.routeSteps.isEmpty else { return "—" }
        let seconds = model.routeSteps
            .dropFirst(model.currentStepIndex)
            .reduce(0) { $0 + $1.durationValue }
        return "\(max(1, seconds / 60)) min"
    }

    private var arrival: String {
        let seconds = model.routeSteps
            .dropFirst(model.currentStepIndex)
            .reduce(0) { $0 + $1.durationValue }
        guard seconds > 0 else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date().addingTimeInterval(TimeInterval(seconds)))
    }

    private var totalDistance: String {
        guard !model.routeSteps.isEmpty,
              model.routeSteps.indices.contains(model.currentStepIndex) else { return "—" }
        let afterCurrent = model.routeSteps
            .dropFirst(model.currentStepIndex + 1)
            .reduce(0.0) { $0 + Double($1.distance) }
        return NavigationManager.formatDistance(model.currentManeuverDistance + afterCurrent)
    }

    var body: some View {
        HStack(spacing: 0) {
            NavigationStat(value: totalDistance, label: "Distance")
            Divider().frame(height: 42).background(.white.opacity(0.12))
            NavigationStat(value: arrival, label: "Arrival")
            Divider().frame(height: 42).background(.white.opacity(0.12))
            NavigationStat(value: remainingTime, label: "Duration")
        }
        .padding(.vertical, 14)
        .background(HOHITheme.navCard.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 22, y: 10)
    }
}

private struct NavigationStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.hohi(16, weight: .black))
                .foregroundStyle(.white)
            Text(label)
                .font(.hohi(9.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }
}
