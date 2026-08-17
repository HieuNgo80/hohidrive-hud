import SwiftUI
import MapKit

private enum DrivePalette {
    static let ink = Color(red: 0.12, green: 0.13, blue: 0.18)
    static let muted = Color(red: 0.43, green: 0.44, blue: 0.50)
    static let lavender = Color(red: 0.39, green: 0.34, blue: 0.92)
    static let lavenderSoft = Color(red: 0.63, green: 0.59, blue: 0.98)
    static let pink = Color(red: 0.94, green: 0.34, blue: 0.61)
    static let navNavy = Color(red: 0.035, green: 0.07, blue: 0.12)
    static let navCard = Color(red: 0.075, green: 0.12, blue: 0.18)
    static let bg = Color(red: 0.94, green: 0.93, blue: 0.99)
}

private extension Font {
    static func hohi(_ size: CGFloat, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct ContentView: View {
    @StateObject private var model = DriveViewModel()
    @State private var tab: MainTab = .map
    @State private var mapView: MKMapView?
    @State private var showMapOptions = false

    var body: some View {
        ZStack {
            if tab == .map {
                MapHome(model: model, mapView: $mapView, showMapOptions: $showMapOptions)
            } else {
                BackgroundView()
                OrdersHome(model: model)
            }

            if tab == .map && !model.isNavigating && !model.showArrival {
                VStack {
                    Spacer()
                    BottomBar(tab: $tab)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
            } else if tab == .orders {
                VStack {
                    Spacer()
                    BottomBar(tab: $tab)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

enum MainTab: String, CaseIterable { case map = "Bản đồ", orders = "Đơn hàng" }

struct BackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [DrivePalette.bg, .white, Color(red: 0.97, green: 0.96, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            Circle().fill(DrivePalette.lavender.opacity(0.08)).frame(width: 300).blur(radius: 35).offset(x: 150, y: -320)
            Circle().fill(DrivePalette.pink.opacity(0.045)).frame(width: 220).blur(radius: 35).offset(x: -170, y: 280)
        }
    }
}

struct MapHome: View {
    @ObservedObject var model: DriveViewModel
    @Binding var mapView: MKMapView?
    @Binding var showMapOptions: Bool
    @State private var routeSheetOffset: CGFloat = 0
    @State private var routeSheetBase: CGFloat = 0
    @State private var sheetCollapsed = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                DriveMapView(model: model, mapView: $mapView)
                    .ignoresSafeArea()

                if !model.isNavigating && !model.showArrival {
                    LinearGradient(
                        colors: [.white.opacity(0.88), .white.opacity(0.20), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 190)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                    VStack(spacing: 0) {
                        TopHeader(model: model)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        Spacer()
                    }

                    RouteSheet(
                        model: model,
                        collapsed: $sheetCollapsed,
                        dragOffset: $routeSheetOffset,
                        baseOffset: $routeSheetBase,
                        maxHeight: min(430, geo.size.height * 0.55)
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 72)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }

                if model.isNavigating {
                    NavigationOverlay(model: model, mapView: mapView, showMapOptions: $showMapOptions)
                }

                if model.showArrival {
                    ArrivalOverlay(model: model)
                }
            }
        }
    }
}

struct TopHeader: View {
    @ObservedObject var model: DriveViewModel

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 15).fill(DrivePalette.ink)
                Text("H").font(.hohi(19, weight: .black)).foregroundStyle(.white)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text("HOHI DRIVE")
                    .font(.hohi(17, weight: .black))
                    .tracking(0.7)
                    .foregroundStyle(DrivePalette.ink)
                HStack(spacing: 6) {
                    Circle().fill(model.hudConnected ? Color.green : DrivePalette.pink).frame(width: 7, height: 7)
                    Text(model.hudConnected ? "Đã kết nối" : "Đang tìm HUD")
                        .font(.hohi(11, weight: .semibold))
                        .foregroundStyle(DrivePalette.muted)
                }
            }

            Spacer()

            Button { model.centerOnUser() } label: {
                Image(systemName: "location.north.fill")
                    .font(.hohi(15, weight: .bold))
                    .foregroundStyle(DrivePalette.ink)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.86))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
        }
    }
}

struct RouteSheet: View {
    @ObservedObject var model: DriveViewModel
    @Binding var collapsed: Bool
    @Binding var dragOffset: CGFloat
    @Binding var baseOffset: CGFloat
    let maxHeight: CGFloat

    private var filledStops: Int {
        model.stops.filter { !$0.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    private var canAddStop: Bool {
        model.stops.count < model.maxStops && !model.stops.isEmpty &&
        !model.stops.last!.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(DrivePalette.muted.opacity(0.28))
                .frame(width: 38, height: 5)
                .padding(.top, 9)
                .padding(.bottom, 8)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LỘ TRÌNH")
                        .font(.hohi(10, weight: .black))
                        .tracking(1.1)
                        .foregroundStyle(DrivePalette.muted)
                    Text(filledStops == 0 ? "Thêm điểm đến" : "\(filledStops) chặng đã thêm")
                        .font(.hohi(19, weight: .black))
                        .foregroundStyle(DrivePalette.ink)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        collapsed.toggle()
                    }
                } label: {
                    Image(systemName: collapsed ? "chevron.up" : "chevron.down")
                        .font(.hohi(13, weight: .black))
                        .foregroundStyle(DrivePalette.ink)
                        .frame(width: 38, height: 38)
                        .background(DrivePalette.bg)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            if !collapsed {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        CurrentLocationRow(model: model)
                            .padding(.top, 7)

                        ForEach(Array(model.stops.enumerated()), id: \.element.id) { index, stop in
                            RouteStopEditor(model: model, stopID: stop.id, index: index)
                        }

                        Button {
                            guard canAddStop else { return }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                model.addStop()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.hohi(17, weight: .bold))
                                Text(model.stops.count >= model.maxStops ? "Đã đạt tối đa \(model.maxStops) chặng" : "Thêm chặng tiếp theo")
                                    .font(.hohi(13, weight: .bold))
                                Spacer()
                                if canAddStop {
                                    Text("+\(model.stops.count + 1)")
                                        .font(.hohi(11, weight: .black))
                                }
                            }
                            .foregroundStyle(canAddStop ? DrivePalette.lavender : DrivePalette.muted.opacity(0.45))
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(DrivePalette.lavender.opacity(canAddStop ? 0.08 : 0.035))
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(DrivePalette.lavender.opacity(canAddStop ? 0.22 : 0.08), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAddStop)
                        .padding(.horizontal, 14)
                        .padding(.top, 6)

                        if model.isCalculating || !model.statusText.isEmpty {
                            HStack(spacing: 7) {
                                if model.isCalculating { ProgressView().scaleEffect(0.72) }
                                Text(model.statusText)
                                    .font(.hohi(10, weight: .medium))
                                    .foregroundStyle(DrivePalette.muted)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 4)
                }
                .frame(maxHeight: maxHeight - 150)

                Button { model.startOrContinue() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "location.north.fill")
                        Text("Bắt đầu chỉ đường")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.hohi(14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 50)
                    .background(LinearGradient(colors: [DrivePalette.lavender, DrivePalette.lavenderSoft], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(10)
            }
        }
        .background(.ultraThinMaterial.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 28, y: 12)
        .offset(y: baseOffset + dragOffset)
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    let predicted = value.predictedEndTranslation.height
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        if predicted > 90 {
                            collapsed = true
                        } else if predicted < -70 {
                            collapsed = false
                        }
                        dragOffset = 0
                    }
                }
        )
        .onChange(of: collapsed) { newValue in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                baseOffset = newValue ? maxHeight - 78 : 0
            }
        }
    }
}

struct CurrentLocationRow: View {
    @ObservedObject var model: DriveViewModel
    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle().fill(DrivePalette.lavender.opacity(0.13))
                Image(systemName: "location.fill")
                    .font(.hohi(12, weight: .bold))
                    .foregroundStyle(DrivePalette.lavender)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("VỊ TRÍ HIỆN TẠI")
                    .font(.hohi(9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(DrivePalette.muted)
                Text(model.currentLocation == nil ? "Đang xác định vị trí…" : "Vị trí của bạn")
                    .font(.hohi(13, weight: .semibold))
                    .foregroundStyle(DrivePalette.ink)
            }
            Spacer()
            Button { model.centerOnUser() } label: {
                Image(systemName: "scope")
                    .foregroundStyle(DrivePalette.lavender)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
    }
}

struct RouteStopEditor: View {
    @ObservedObject var model: DriveViewModel
    let stopID: UUID
    let index: Int

    private var stop: DriveStop? { model.stops.first(where: { $0.id == stopID }) }

    var body: some View {
        if let stop {
            VStack(spacing: 0) {
                HStack(spacing: 11) {
                    ZStack {
                        Circle().fill(index == 0 ? DrivePalette.pink.opacity(0.12) : DrivePalette.lavender.opacity(0.12))
                        Text("\(index + 1)")
                            .font(.hohi(11, weight: .black))
                            .foregroundStyle(index == 0 ? DrivePalette.pink : DrivePalette.lavender)
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("CHẶNG \(index + 1)")
                            .font(.hohi(9, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(DrivePalette.muted)
                        TextField("Nhập điểm đến…", text: Binding(
                            get: { stop.address },
                            set: { model.updateStop($0, id: stop.id) }
                        ))
                        .font(.hohi(14, weight: .semibold))
                        .foregroundStyle(DrivePalette.ink)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .disabled(stop.completed)
                    }

                    Spacer(minLength: 4)

                    if stop.completed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if model.stops.count > 1 {
                        Button { model.removeStop(id: stop.id) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.hohi(18, weight: .semibold))
                                .foregroundStyle(DrivePalette.ink.opacity(0.22))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 9)

                if model.activeStopID == stop.id && !model.suggestions.isEmpty && !stop.completed {
                    VStack(spacing: 0) {
                        ForEach(Array(model.suggestions.prefix(3)), id: \.self) { suggestion in
                            Button { model.chooseSuggestion(suggestion) } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundStyle(DrivePalette.lavender)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(suggestion.title)
                                            .font(.hohi(12, weight: .semibold))
                                            .foregroundStyle(DrivePalette.ink)
                                            .lineLimit(1)
                                        Text(suggestion.subtitle)
                                            .font(.hohi(10))
                                            .foregroundStyle(DrivePalette.muted)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 7)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 60)
                    .padding(.trailing, 15)
                    .padding(.bottom, 6)
                }
            }
        }
    }
}

struct NavigationOverlay: View {
    @ObservedObject var model: DriveViewModel
    let mapView: MKMapView?
    @Binding var showMapOptions: Bool

    private var step: RouteStep? {
        model.routeSteps.indices.contains(model.currentStepIndex) ? model.routeSteps[model.currentStepIndex] : nil
    }

    private var distanceText: String {
        guard let step, let loc = model.currentLocation else { return "—" }
        return NavigationManager.formatDistance(CLLocation(latitude: step.endLat, longitude: step.endLng).distance(from: loc))
    }

    private var roadName: String {
        guard let step else { return "Đang dẫn đường" }
        return step.roadName.isEmpty ? "Đang dẫn đường" : step.roadName
    }

    private var maneuverIcon: String {
        switch step?.maneuver {
        case "left": return "arrow.turn.up.left"
        case "right": return "arrow.turn.up.right"
        case "uturn": return "arrow.uturn.left"
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
                    instruction: step?.instruction ?? "Đang tính hướng đi…",
                    maneuverIcon: maneuverIcon
                )
                .padding(.horizontal, 16)
                .padding(.top, 44)

                Spacer()

                HStack(alignment: .bottom) {
                    SpeedBadge(speed: speedText)
                    Spacer()
                    VStack(spacing: 8) {
                        MapZoomControls(model: model, mapView: mapView)
                        MapExtraControls(model: model, showMapOptions: $showMapOptions)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 172)

                NavigationBottomStats(model: model)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button { model.stopNavigation() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.fill")
                            Text("STOP")
                        }
                        .font(.hohi(13, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 48)
                        .background(Color.red.opacity(0.92))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.25), radius: 14, y: 7)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 18)
                    .padding(.bottom, 92)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct NavigationTopCard: View {
    let distance: String
    let roadName: String
    let instruction: String
    let maneuverIcon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: maneuverIcon)
                .font(.hohi(31, weight: .black))
                .foregroundStyle(DrivePalette.pink)
                .frame(width: 48)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(distance)
                        .font(.hohi(25, weight: .black))
                    Text(distance.contains("m") ? "" : "")
                }
                Text(instruction)
                    .font(.hohi(12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(1)
                Text(roadName)
                    .font(.hohi(13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "speaker.wave.2.fill")
                .font(.hohi(15, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.07))
                .clipShape(Circle())
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(DrivePalette.navCard.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 22, y: 10)
    }
}

struct SpeedBadge: View {
    let speed: String
    var body: some View {
        VStack(spacing: 0) {
            Text(speed).font(.hohi(28, weight: .black)).foregroundStyle(.white)
            Text("km/h").font(.hohi(10, weight: .semibold)).foregroundStyle(.white.opacity(0.72))
        }
        .frame(width: 76, height: 76)
        .background(DrivePalette.navCard.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
    }
}

struct MapZoomControls: View {
    @ObservedObject var model: DriveViewModel
    let mapView: MKMapView?
    var body: some View {
        VStack(spacing: 0) {
            Button { model.zoomMap(0.62, mapView: mapView) } label: {
                Image(systemName: "plus").frame(width: 42, height: 42)
            }
            Divider().background(.white.opacity(0.12))
            Button { model.zoomMap(1.62, mapView: mapView) } label: {
                Image(systemName: "minus").frame(width: 42, height: 42)
            }
        }
        .font(.hohi(17, weight: .bold))
        .foregroundStyle(.white)
        .background(DrivePalette.navCard.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
    }
}

struct MapExtraControls: View {
    @ObservedObject var model: DriveViewModel
    @Binding var showMapOptions: Bool
    var body: some View {
        VStack(spacing: 8) {
            Button { model.centerOnUser() } label: {
                Image(systemName: model.followUser ? "location.fill" : "location")
                    .frame(width: 42, height: 42)
            }
            Button { model.toggleHeading() } label: {
                Image(systemName: model.headingMode ? "location.north.fill" : "location.north")
                    .frame(width: 42, height: 42)
            }
            Button { showMapOptions = true } label: {
                Image(systemName: "square.2.layers.3d.top.filled")
                    .frame(width: 42, height: 42)
            }
        }
        .font(.hohi(15, weight: .bold))
        .foregroundStyle(.white)
        .background(DrivePalette.navCard.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
        .confirmationDialog("Lớp bản đồ", isPresented: $showMapOptions) {
            Button("Tiêu chuẩn") { model.mapType = .standard }
            Button("Vệ tinh") { model.mapType = .satellite }
            Button("Kết hợp") { model.mapType = .hybrid }
            Button("Hủy", role: .cancel) {}
        }
    }
}

struct NavigationBottomStats: View {
    @ObservedObject var model: DriveViewModel

    private var remainingTime: String {
        guard !model.routeSteps.isEmpty else { return "—" }
        let seconds = model.routeSteps.dropFirst(model.currentStepIndex).reduce(0) { $0 + $1.durationValue }
        let minutes = max(1, seconds / 60)
        return "\(minutes) min"
    }

    private var arrival: String {
        let seconds = model.routeSteps.dropFirst(model.currentStepIndex).reduce(0) { $0 + $1.durationValue }
        guard seconds > 0 else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date().addingTimeInterval(TimeInterval(seconds)))
    }

    private var totalDistance: String {
        NavigationManager.formatDistance(Double(model.routeSteps.reduce(0) { $0 + $1.distance }))
    }

    var body: some View {
        HStack(spacing: 0) {
            StatItem(value: totalDistance, label: "Khoảng cách")
            Divider().frame(height: 36).background(.white.opacity(0.12))
            StatItem(value: arrival, label: "Dự kiến")
            Divider().frame(height: 36).background(.white.opacity(0.12))
            StatItem(value: remainingTime, label: "Thời gian")
        }
        .padding(.vertical, 13)
        .background(DrivePalette.navCard.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 22, y: 10)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.hohi(15, weight: .black)).foregroundStyle(.white)
            Text(label).font(.hohi(9, weight: .medium)).foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }
}

struct ArrivalOverlay: View {
    @ObservedObject var model: DriveViewModel

    private var distance: String {
        guard let trip = model.completedTrips.first(where: { $0.stopNumber == model.lastCompletedStopNumber }) else { return "—" }
        return trip.distance
    }

    private var duration: String {
        guard let trip = model.completedTrips.first(where: { $0.stopNumber == model.lastCompletedStopNumber }) else { return "—" }
        return trip.duration
    }

    var body: some View {
        ZStack {
            Color.white.opacity(0.88).ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer(minLength: 32)

                ZStack {
                    Circle().fill(DrivePalette.lavender.opacity(0.18)).frame(width: 104, height: 104)
                    Circle().fill(DrivePalette.lavender).frame(width: 78, height: 78)
                    Image(systemName: "checkmark")
                        .font(.hohi(36, weight: .black))
                        .foregroundStyle(.white)
                }

                Text("Chặng đã hoàn thành!")
                    .font(.hohi(25, weight: .black))
                    .foregroundStyle(DrivePalette.ink)
                Text("Chặng \(model.lastCompletedStopNumber)")
                    .font(.hohi(14, weight: .semibold))
                    .foregroundStyle(DrivePalette.muted)

                HStack(spacing: 12) {
                    CompletionStat(value: distance, label: "Khoảng cách")
                    CompletionStat(value: duration, label: "Thời gian")
                }

                HStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.hohi(23, weight: .bold))
                        .foregroundStyle(DrivePalette.lavender)
                        .frame(width: 44, height: 44)
                        .background(DrivePalette.lavender.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Thanh toán đã sẵn sàng")
                            .font(.hohi(13, weight: .bold))
                            .foregroundStyle(DrivePalette.ink)
                        Text("Thực hiện thanh toán trên thiết bị HUD")
                            .font(.hohi(11, weight: .medium))
                            .foregroundStyle(DrivePalette.muted)
                    }
                    Spacer()
                }
                .padding(14)
                .background(DrivePalette.bg.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                Button { model.continueNextStage() } label: {
                    HStack {
                        Text(model.nextIncompleteIndex == nil ? "Hoàn tất chuyến" : "Tiếp tục chặng tiếp theo")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.hohi(14, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .background(LinearGradient(colors: [DrivePalette.lavender, DrivePalette.lavenderSoft], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button { model.startNewTrip() } label: {
                    Text("Về màn hình chính")
                        .font(.hohi(13, weight: .bold))
                        .foregroundStyle(DrivePalette.lavender)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(.white.opacity(0.9))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(DrivePalette.lavender.opacity(0.45), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 28)
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: 520)
        }
        .transition(.opacity)
    }
}

struct CompletionStat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.hohi(21, weight: .black)).foregroundStyle(DrivePalette.ink)
            Text(label).font(.hohi(9, weight: .medium)).foregroundStyle(DrivePalette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct OrdersHome: View {
    @ObservedObject var model: DriveViewModel
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Đơn hàng").font(.hohi(30, weight: .black)).foregroundStyle(DrivePalette.ink).padding(.top, 18)
                Text("Các chặng đã hoàn thành trong ngày").font(.hohi(14, weight: .medium)).foregroundStyle(DrivePalette.muted)
                HStack(spacing: 10) {
                    SummaryPill(value: "\(model.completedTrips.count)", label: "Chặng")
                    SummaryPill(value: "\(model.completedTrips.reduce(0) { $0 + $1.orderCount })", label: "Đơn")
                }
                if model.completedTrips.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "shippingbox").font(.hohi(30)).foregroundStyle(DrivePalette.pink)
                        Text("Chưa có chặng hoàn thành").font(.hohi(17, weight: .bold))
                        Text("Khi hoàn thành chặng, dữ liệu sẽ tự xuất hiện ở đây.")
                            .font(.hohi(12))
                            .foregroundStyle(DrivePalette.muted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                    .background(.white.opacity(0.78))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                } else {
                    ForEach(model.completedTrips) { trip in
                        OrderTripCard(trip: trip) { value in model.updateOrderCount(id: trip.id, value: value) }
                    }
                    Button(role: .destructive) { model.clearHistory() } label: {
                        Text("Xóa lịch sử đơn hàng").font(.hohi(13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 18)
        }
    }
}

struct SummaryPill: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.hohi(20, weight: .black))
            Text(label).font(.hohi(9, weight: .bold)).foregroundStyle(DrivePalette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct OrderTripCard: View {
    let trip: CompletedTrip
    let onChange: (Int) -> Void
    @State private var value: String

    init(trip: CompletedTrip, onChange: @escaping (Int) -> Void) {
        self.trip = trip
        self.onChange = onChange
        _value = State(initialValue: "\(trip.orderCount)")
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(DrivePalette.pink.opacity(0.12))
                Text("\(trip.stopNumber)").font(.hohi(13, weight: .black)).foregroundStyle(DrivePalette.pink)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.destination).font(.hohi(14, weight: .bold)).foregroundStyle(DrivePalette.ink).lineLimit(1)
                Text("\(trip.distance) · \(trip.duration)").font(.hohi(10, weight: .medium)).foregroundStyle(DrivePalette.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Đơn").font(.hohi(9, weight: .bold)).foregroundStyle(DrivePalette.muted)
                TextField("0", text: $value)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 42)
                    .font(.hohi(16, weight: .black))
                    .onChange(of: value) { onChange(Int($0) ?? 0) }
            }
        }
        .padding(14)
        .background(.white.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.07), radius: 15, y: 6)
    }
}

struct BottomBar: View {
    @Binding var tab: MainTab
    var body: some View {
        HStack(spacing: 5) {
            ForEach(MainTab.allCases, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { tab = item }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: item == .map ? "map.fill" : "shippingbox.fill")
                            .font(.hohi(15, weight: .bold))
                        if tab == item { Text(item.rawValue).font(.hohi(12, weight: .black)) }
                    }
                    .foregroundStyle(tab == item ? .white : DrivePalette.ink.opacity(0.38))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(tab == item ? AnyShapeStyle(LinearGradient(colors: [DrivePalette.lavender, DrivePalette.lavenderSoft], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.clear))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.white.opacity(0.90))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 22, y: 9)
    }
}

#Preview { ContentView() }
