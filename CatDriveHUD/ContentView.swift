import SwiftUI
import MapKit

private enum DrivePalette {
    static let ink = Color(red: 0.12, green: 0.13, blue: 0.18)
    static let muted = Color(red: 0.43, green: 0.44, blue: 0.50)
    static let lavender = Color(red: 0.39, green: 0.34, blue: 0.92)
    static let lavenderSoft = Color(red: 0.63, green: 0.59, blue: 0.98)
    static let pink = Color(red: 0.94, green: 0.34, blue: 0.61)
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
    @State private var showSettings = false
    @State private var qrDraft = ""

    var body: some View {
        ZStack {
            if tab == .map {
                MapHome(model: model, mapView: $mapView, showMapOptions: $showMapOptions)
            } else {
                BackgroundView()
                OrdersHome(model: model)
            }

            VStack {
                Spacer()
                BottomBar(tab: $tab)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showSettings) {
            PaymentSettingsView(value: qrDraft) { value in
                model.saveQR(value)
                qrDraft = value
                showSettings = false
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear { qrDraft = model.qrString }
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
    @State private var showSuggestions = true

    var body: some View {
        ZStack {
            DriveMapView(model: model, mapView: $mapView)
                .ignoresSafeArea()

            // Soft top scrim only; the map remains fully interactive everywhere else.
            LinearGradient(colors: [.white.opacity(0.82), .white.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 190)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 10) {
                TopHeader(model: model)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if model.isNavigating {
                    LiveNavigationCard(model: model)
                        .padding(.horizontal, 16)
                } else {
                    RouteEntryCard(model: model, showSuggestions: $showSuggestions)
                        .padding(.horizontal, 16)
                        .frame(maxHeight: UIScreen.main.bounds.height * 0.48)
                }

                Spacer()
            }

            MapControls(model: model, mapView: mapView, showMapOptions: $showMapOptions)
                .padding(.trailing, 14)
                .padding(.bottom, model.showArrival ? 250 : 95)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

            if model.showArrival {
                VStack {
                    Spacer()
                    ArrivalCard(model: model)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 86)
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
                Text("HOHI DRIVE").font(.hohi(17, weight: .black)).tracking(0.7).foregroundStyle(DrivePalette.ink)
                HStack(spacing: 6) {
                    Circle().fill(model.hudConnected ? Color.green : DrivePalette.pink).frame(width: 7, height: 7)
                    Text(model.hudConnected ? "Đã kết nối" : "Đang tìm HUD").font(.hohi(11, weight: .semibold)).foregroundStyle(DrivePalette.muted)
                }
            }
            Spacer()
            Button { } label: {
                Image(systemName: "location.north.fill")
                    .font(.hohi(15, weight: .bold))
                    .foregroundStyle(model.headingMode ? DrivePalette.pink : DrivePalette.ink)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.86))
                    .clipShape(Circle())
            }
        }
    }
}

struct RouteEntryCard: View {
    @ObservedObject var model: DriveViewModel
    @Binding var showSuggestions: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    Circle().fill(DrivePalette.lavender.opacity(0.13))
                    Image(systemName: "location.fill").font(.hohi(13, weight: .bold)).foregroundStyle(DrivePalette.lavender)
                }.frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("VỊ TRÍ HIỆN TẠI").font(.hohi(9, weight: .bold)).tracking(1).foregroundStyle(DrivePalette.muted)
                    Text(model.currentLocation == nil ? "Đang xác định vị trí…" : "Vị trí của bạn")
                        .font(.hohi(14, weight: .semibold)).foregroundStyle(DrivePalette.ink)
                }
                Spacer()
                Button { model.centerOnUser() } label: {
                    Image(systemName: "scope").font(.hohi(16, weight: .bold)).foregroundStyle(DrivePalette.lavender)
                }
            }.padding(.horizontal, 15).padding(.vertical, 12)

            Divider().padding(.leading, 60)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.stops.enumerated()), id: \.element.id) { index, stop in
                        StopInputRow(model: model, stopID: stop.id, index: index, showSuggestions: $showSuggestions)
                        if index < model.stops.count - 1 { Divider().padding(.leading, 60) }
                    }
                }
            }

            HStack {
                Button { model.addStop() } label: {
                    Label("Thêm chặng", systemImage: "plus.circle.fill")
                        .font(.hohi(13, weight: .bold))
                        .foregroundStyle(DrivePalette.lavender)
                }
                Spacer()
                Text("\(model.stops.count)/\(model.maxStops)").font(.hohi(11, weight: .bold)).foregroundStyle(DrivePalette.muted)
            }.padding(.horizontal, 15).padding(.vertical, 10)

            Button { model.startOrContinue() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    Text("Bắt đầu chỉ đường")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.hohi(14, weight: .bold)).foregroundStyle(.white)
                .padding(.horizontal, 17).frame(height: 50)
                .background(LinearGradient(colors: [DrivePalette.lavender, DrivePalette.lavenderSoft], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }.padding(9)

            if model.isCalculating || !model.statusText.isEmpty {
                HStack(spacing: 7) {
                    if model.isCalculating { ProgressView().scaleEffect(0.72) }
                    Text(model.statusText).font(.hohi(10, weight: .medium)).foregroundStyle(DrivePalette.muted)
                    Spacer()
                }.padding(.horizontal, 16).padding(.bottom, 10)
            }
        }
        .background(.ultraThinMaterial.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.14), radius: 25, y: 12)
    }
}

struct StopInputRow: View {
    @ObservedObject var model: DriveViewModel
    let stopID: UUID
    let index: Int
    @Binding var showSuggestions: Bool

    private var stop: DriveStop? { model.stops.first(where: { $0.id == stopID }) }

    var body: some View {
        if let stop {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 11) {
                    ZStack {
                        Circle().fill(DrivePalette.pink.opacity(0.12))
                        Text("\(index + 1)").font(.hohi(11, weight: .black)).foregroundStyle(DrivePalette.pink)
                    }.frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("CHẶNG \(index + 1)").font(.hohi(9, weight: .bold)).tracking(1).foregroundStyle(DrivePalette.muted)
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
                    Spacer()

                    if stop.completed {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else if model.stops.count > 1 {
                        Button { model.removeStop(id: stop.id) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.hohi(19, weight: .semibold))
                                .foregroundStyle(DrivePalette.ink.opacity(0.22))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if showSuggestions && model.activeStopID == stop.id && !model.suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(model.suggestions.prefix(4)), id: \.self) { suggestion in
                            Button { model.chooseSuggestion(suggestion) } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: "mappin.and.ellipse").foregroundStyle(DrivePalette.lavender)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(suggestion.title).font(.hohi(12, weight: .semibold)).foregroundStyle(DrivePalette.ink)
                                        Text(suggestion.subtitle).font(.hohi(10)).foregroundStyle(DrivePalette.muted)
                                    }
                                    Spacer()
                                }.padding(.vertical, 8)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.leading, 45).padding(.bottom, 4)
                }
            }
            .padding(.horizontal, 15).padding(.vertical, 11)
        }
    }
}

struct LiveNavigationCard: View {
    @ObservedObject var model: DriveViewModel
    var step: RouteStep? { model.routeSteps.indices.contains(model.currentStepIndex) ? model.routeSteps[model.currentStepIndex] : nil }
    var body: some View {
        HStack(spacing: 12) {
            ZStack { Circle().fill(DrivePalette.lavender.opacity(0.13)); Image(systemName: iconName).font(.hohi(18, weight: .bold)).foregroundStyle(DrivePalette.lavender) }.frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text("CHẶNG \(model.currentStopIndex + 1) · TIẾP THEO").font(.hohi(9, weight: .bold)).tracking(0.9).foregroundStyle(DrivePalette.muted)
                Text(roadName).font(.hohi(15, weight: .bold)).foregroundStyle(DrivePalette.ink).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(distanceText).font(.hohi(15, weight: .black)).foregroundStyle(DrivePalette.lavender)
                Text(model.statusText.replacingOccurrences(of: "Đang dẫn đường · ", with: "")).font(.hohi(9, weight: .medium)).foregroundStyle(DrivePalette.muted).lineLimit(1)
            }
        }.padding(14).background(.ultraThinMaterial.opacity(0.94)).clipShape(RoundedRectangle(cornerRadius: 22)).shadow(color: .black.opacity(0.12), radius: 20, y: 8)
    }
    var roadName: String { step?.roadName.isEmpty == false ? step!.roadName : "Đang dẫn đường" }
    var distanceText: String { guard let step, let loc = model.currentLocation else { return "—" }; return NavigationManager.formatDistance(CLLocation(latitude: step.endLat, longitude: step.endLng).distance(from: loc)) }
    var iconName: String { switch step?.maneuver { case "left": "arrow.turn.up.left"; case "right": "arrow.turn.up.right"; case "uturn": "arrow.uturn.left"; default: "arrow.up" } }
}

struct MapControls: View {
    @ObservedObject var model: DriveViewModel
    let mapView: MKMapView?
    @Binding var showMapOptions: Bool

    var body: some View {
        VStack(spacing: 8) {
            Button { model.zoomMap(0.62, mapView: mapView) } label: { Image(systemName: "plus").frame(width: 42, height: 42) }
            Divider().frame(width: 22)
            Button { model.zoomMap(1.62, mapView: mapView) } label: { Image(systemName: "minus").frame(width: 42, height: 42) }
        }
        .font(.hohi(16, weight: .bold)).foregroundStyle(DrivePalette.ink)
        .padding(4).background(.white.opacity(0.92)).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        .overlay(alignment: .bottom) {
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
                    Image(systemName: "square.2.layers.3d.top.filled").frame(width: 42, height: 42)
                }
            }
            .font(.hohi(15, weight: .bold)).foregroundStyle(DrivePalette.ink)
            .padding(4).background(.white.opacity(0.92)).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: .black.opacity(0.12), radius: 16, y: 6)
            .offset(y: 158)
        }
        .confirmationDialog("Lớp bản đồ", isPresented: $showMapOptions) {
            Button("Tiêu chuẩn") { model.mapType = .standard }
            Button("Vệ tinh") { model.mapType = .satellite }
            Button("Kết hợp") { model.mapType = .hybrid }
            Button("Hủy", role: .cancel) {}
        }
    }
}

struct ArrivalCard: View {
    @ObservedObject var model: DriveViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack { Circle().fill(.green.opacity(0.13)); Image(systemName: "checkmark").font(.hohi(15, weight: .black)).foregroundStyle(.green) }.frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHẶNG \(model.lastCompletedStopNumber) ĐÃ HOÀN THÀNH").font(.hohi(10, weight: .bold)).tracking(0.7).foregroundStyle(DrivePalette.muted)
                    Text("Mã thanh toán đang được gửi tới OLED").font(.hohi(13, weight: .semibold)).foregroundStyle(DrivePalette.ink)
                }
                Spacer()
            }
            Text("QR không hiển thị trên iPhone. HUD OLED hiển thị mã thanh toán; firmware tự giữ trong 5 phút.").font(.hohi(11, weight: .medium)).foregroundStyle(DrivePalette.muted)
            Button { model.continueNextStage() } label: {
                HStack { Image(systemName: "arrow.right"); Text(model.nextIncompleteIndex == nil ? "Kết thúc chuyến" : "Tiếp tục chặng tiếp theo") }
                    .font(.hohi(13, weight: .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 46).background(DrivePalette.lavender).clipShape(RoundedRectangle(cornerRadius: 15))
            }
        }.padding(16).background(.white.opacity(0.96)).clipShape(RoundedRectangle(cornerRadius: 22)).shadow(color: .black.opacity(0.16), radius: 22, y: 10)
    }
}

struct OrdersHome: View {
    @ObservedObject var model: DriveViewModel
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Đơn hàng").font(.hohi(30, weight: .black)).foregroundStyle(DrivePalette.ink).padding(.top, 18)
                Text("Các chặng đã hoàn thành trong ngày").font(.hohi(14, weight: .medium)).foregroundStyle(DrivePalette.muted)
                HStack(spacing: 10) { SummaryPill(value: "\(model.completedTrips.count)", label: "Chặng"); SummaryPill(value: "\(model.completedTrips.reduce(0) { $0 + $1.orderCount })", label: "Đơn") }
                if model.completedTrips.isEmpty {
                    VStack(spacing: 12) { Image(systemName: "shippingbox").font(.hohi(30)).foregroundStyle(DrivePalette.pink); Text("Chưa có chặng hoàn thành").font(.hohi(17, weight: .bold)); Text("Khi hoàn thành chặng, dữ liệu sẽ tự xuất hiện ở đây.").font(.hohi(12)).foregroundStyle(DrivePalette.muted).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(40).background(.white.opacity(0.78)).clipShape(RoundedRectangle(cornerRadius: 24))
                } else {
                    ForEach(model.completedTrips) { trip in OrderTripCard(trip: trip) { value in model.updateOrderCount(id: trip.id, value: value) } }
                    Button(role: .destructive) { model.clearHistory() } label: { Text("Xóa lịch sử đơn hàng").font(.hohi(13, weight: .semibold)) }.frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                Spacer(minLength: 100)
            }.padding(.horizontal, 18)
        }
    }
}

struct SummaryPill: View { let value: String; let label: String; var body: some View { VStack(spacing: 2) { Text(value).font(.hohi(20, weight: .black)); Text(label).font(.hohi(9, weight: .bold)).foregroundStyle(DrivePalette.muted) }.frame(maxWidth: .infinity).padding(.vertical, 12).background(.white.opacity(0.78)).clipShape(RoundedRectangle(cornerRadius: 18)) } }

struct OrderTripCard: View {
    let trip: CompletedTrip
    let onChange: (Int) -> Void
    @State private var value: String
    init(trip: CompletedTrip, onChange: @escaping (Int) -> Void) { self.trip = trip; self.onChange = onChange; _value = State(initialValue: "\(trip.orderCount)") }
    var body: some View {
        HStack(spacing: 12) {
            ZStack { Circle().fill(DrivePalette.pink.opacity(0.12)); Text("\(trip.stopNumber)").font(.hohi(13, weight: .black)).foregroundStyle(DrivePalette.pink) }.frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 4) { Text(trip.destination).font(.hohi(14, weight: .bold)).foregroundStyle(DrivePalette.ink).lineLimit(1); Text("\(trip.distance) · \(trip.duration)").font(.hohi(10, weight: .medium)).foregroundStyle(DrivePalette.muted) }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) { Text("Đơn").font(.hohi(9, weight: .bold)).foregroundStyle(DrivePalette.muted); TextField("0", text: $value).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 42).font(.hohi(16, weight: .black)).onChange(of: value) { onChange(Int($0) ?? 0) } }
        }.padding(14).background(.white.opacity(0.84)).clipShape(RoundedRectangle(cornerRadius: 20)).shadow(color: .black.opacity(0.07), radius: 15, y: 6)
    }
}

struct PaymentSettingsView: View {
    let value: String
    let onSave: (String) -> Void
    @State private var draft: String
    init(value: String, onSave: @escaping (String) -> Void) { self.value = value; self.onSave = onSave; _draft = State(initialValue: value) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Thanh toán HUD") {
                    Text("Nhập chuỗi VietQR để gửi xuống OLED khi hoàn thành chặng. App không tạo hoặc hiển thị hình QR.").font(.hohi(12)).foregroundStyle(.secondary)
                    TextEditor(text: $draft).frame(minHeight: 110).font(.hohi(13))
                }
            }
            .navigationTitle("Thiết lập")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Lưu") { onSave(draft) }.font(.hohi(14, weight: .bold)) } }
        }
    }
}

struct BottomBar: View {
    @Binding var tab: MainTab
    var body: some View {
        HStack(spacing: 5) {
            ForEach(MainTab.allCases, id: \.self) { item in
                Button { withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { tab = item } } label: {
                    HStack(spacing: 7) {
                        Image(systemName: item == .map ? "map.fill" : "shippingbox.fill").font(.hohi(15, weight: .bold))
                        if tab == item { Text(item.rawValue).font(.hohi(12, weight: .black)) }
                    }
                    .foregroundStyle(tab == item ? .white : DrivePalette.ink.opacity(0.38))
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(tab == item ? AnyShapeStyle(LinearGradient(colors: [DrivePalette.lavender, DrivePalette.lavenderSoft], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.clear))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6).background(.white.opacity(0.90)).clipShape(Capsule()).shadow(color: .black.opacity(0.12), radius: 22, y: 9)
    }
}

#Preview { ContentView() }
