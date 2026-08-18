import SwiftUI
import MapKit

struct MapScreen: View {
    @ObservedObject var model: DriveViewModel
    @Binding var mapView: MKMapView?
    @Binding var showMapOptions: Bool
    let goHome: () -> Void

    var body: some View {
        ZStack {
            DriveMapView(model: model, mapView: $mapView)
                .ignoresSafeArea()

            if model.showArrival {
                ArrivalView(
                    model: model,
                    onHome: goHome
                )
                .transition(.opacity)
            } else if model.isNavigating {
                NavigationOverlay(
                    model: model,
                    mapView: mapView,
                    showMapOptions: $showMapOptions
                )
                .transition(.opacity)
            } else {
                IdleMapOverlay(
                    model: model,
                    mapView: mapView,
                    showMapOptions: $showMapOptions
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.isNavigating)
        .animation(.easeInOut(duration: 0.25), value: model.showArrival)
    }
}

private struct IdleMapOverlay: View {
    @ObservedObject var model: DriveViewModel
    let mapView: MKMapView?
    @Binding var showMapOptions: Bool

    private var speedText: String {
        guard let speed = model.currentLocation?.speed, speed >= 0 else { return "0" }
        return "\(max(0, Int(speed * 3.6)))"
    }

    private var connectionLabel: String {
        model.hudConnected ? "HUD Connected" : "HUD Not Connected"
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("HOHI DRIVE")
                            .font(.hohi(19, weight: .heavy))
                            .tracking(0.4)
                            .foregroundStyle(HOHITheme.ink)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(model.hudConnected ? HOHITheme.purple : HOHITheme.pink)
                                .frame(width: 7, height: 7)
                            Text(connectionLabel)
                                .font(.hohi(11.5, weight: .semibold))
                                .foregroundStyle(model.hudConnected ? HOHITheme.purple : HOHITheme.muted)
                        }
                    }

                    Spacer()

                    VStack(spacing: 0) {
                        Text(speedText)
                            .font(.hohi(28, weight: .heavy))
                            .foregroundStyle(HOHITheme.ink)
                        Text("km/h")
                            .font(.hohi(10, weight: .semibold))
                            .foregroundStyle(HOHITheme.muted)
                    }
                    .frame(width: 76, height: 76)
                    .background(.white.opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                    .shadow(color: .black.opacity(0.10), radius: 14, y: 6)
                }
                .padding(.horizontal, 18)
                .padding(.top, 52)

                Spacer()
            }

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    Spacer()

                    VStack(spacing: 10) {
                        IdleCompassButton(model: model)
                        LightZoomControls(model: model, mapView: mapView)
                        RecenterButton(action: model.centerOnUser, dark: false)
                        LightExtraControls(model: model, showMapOptions: $showMapOptions)
                    }
                }
                .padding(.trailing, 18)
                .padding(.bottom, 116)
            }

            if model.isCalculating {
                VStack {
                    Spacer()
                    HStack(spacing: 9) {
                        ProgressView()
                        Text("Building route…")
                            .font(.hohi(12.5, weight: .semibold))
                            .foregroundStyle(HOHITheme.ink)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(.white.opacity(0.93))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.11), radius: 12, y: 5)
                    .padding(.bottom, 142)
                }
            }
        }
    }
}

private struct IdleCompassButton: View {
    @ObservedObject var model: DriveViewModel

    var body: some View {
        Button {
            model.toggleHeading()
        } label: {
            VStack(spacing: 0) {
                Image(systemName: "location.north.fill")
                    .font(.hohi(15, weight: .bold))
                    .foregroundStyle(HOHITheme.pink)
                Text("N")
                    .font(.hohi(9, weight: .black))
                    .foregroundStyle(HOHITheme.ink)
            }
            .frame(width: 52, height: 52)
            .background(.white.opacity(0.92))
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
    }
}

private struct LightZoomControls: View {
    @ObservedObject var model: DriveViewModel
    let mapView: MKMapView?

    var body: some View {
        VStack(spacing: 0) {
            Button { model.zoomMap(0.62, mapView: mapView) } label: {
                Image(systemName: "plus")
                    .frame(width: 52, height: 46)
            }
            Divider().opacity(0.35)
            Button { model.zoomMap(1.62, mapView: mapView) } label: {
                Image(systemName: "minus")
                    .frame(width: 52, height: 46)
            }
        }
        .frame(width: 52)
        .font(.hohi(18, weight: .bold))
        .foregroundStyle(HOHITheme.ink)
        .background(.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
    }
}

private struct LightExtraControls: View {
    @ObservedObject var model: DriveViewModel
    @Binding var showMapOptions: Bool

    var body: some View {
        Button { showMapOptions = true } label: {
            Image(systemName: "square.2.layers.3d.top.filled")
                .font(.hohi(15, weight: .bold))
                .foregroundStyle(HOHITheme.ink)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.92))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .confirmationDialog("Map Options", isPresented: $showMapOptions) {
            Button("Standard") { model.mapType = .standard }
            Button("Satellite") { model.mapType = .satellite }
            Button("Hybrid") { model.mapType = .hybrid }
            if model.isNavigating {
                Button("Simulate Arrival") { model.simulateArrival() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct RecenterButton: View {
    let action: () -> Void
    let dark: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: "location.north.line.fill")
                .font(.hohi(15, weight: .bold))
                .foregroundStyle(dark ? Color.white : HOHITheme.purple)
                .frame(width: 52, height: 52)
                .background((dark ? HOHITheme.navCard.opacity(0.95) : Color.white.opacity(0.92)))
                .clipShape(Circle())
                .shadow(color: .black.opacity(dark ? 0.30 : 0.10), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
    }
}
