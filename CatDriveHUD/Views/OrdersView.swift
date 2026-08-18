import SwiftUI

struct OrdersView: View {
    @ObservedObject var model: DriveViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [HOHITheme.background, .white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Orders")
                                .font(.hohi(31, weight: .black))
                                .foregroundStyle(HOHITheme.ink)
                            Text("Completed routes today")
                                .font(.hohi(13.5, weight: .medium))
                                .foregroundStyle(HOHITheme.muted)
                        }
                        Spacer()
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.hohi(18, weight: .bold))
                            .foregroundStyle(HOHITheme.purple)
                            .frame(width: 46, height: 46)
                            .background(.white.opacity(0.82))
                            .clipShape(Circle())
                    }
                    .padding(.top, 18)

                    HStack(spacing: 10) {
                        SummaryPill(value: "\(model.completedTrips.count)", label: "Routes")
                        SummaryPill(
                            value: "\(model.completedTrips.reduce(0) { $0 + $1.orderCount })",
                            label: "Orders"
                        )
                    }

                    if model.completedTrips.isEmpty {
                        placeholder
                    } else {
                        ForEach(model.completedTrips) { trip in
                            OrderTripCard(trip: trip) { value in
                                model.updateOrderCount(id: trip.id, value: value)
                            }
                        }
                    }

                    Spacer(minLength: 110)
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 13) {
            Image(systemName: "shippingbox")
                .font(.hohi(34, weight: .medium))
                .foregroundStyle(HOHITheme.purple)
            Text("Order history")
                .font(.hohi(18, weight: .bold))
                .foregroundStyle(HOHITheme.ink)
            Text("Completed stages will appear here. Detailed order management will be developed later.")
                .font(.hohi(12.5, weight: .medium))
                .foregroundStyle(HOHITheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 26)
        .padding(.vertical, 44)
        .hohiCard(radius: 25)
    }
}

private struct SummaryPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.hohi(22, weight: .black))
                .foregroundStyle(HOHITheme.ink)
            Text(label)
                .font(.hohi(10, weight: .bold))
                .foregroundStyle(HOHITheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .hohiCard(radius: 19)
    }
}

private struct OrderTripCard: View {
    let trip: CompletedTrip
    let onChange: (Int) -> Void
    @State private var value: String

    init(trip: CompletedTrip, onChange: @escaping (Int) -> Void) {
        self.trip = trip
        self.onChange = onChange
        _value = State(initialValue: "\(trip.orderCount)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(trip.completedAt, style: .time)
                    .font(.hohi(12, weight: .semibold))
                    .foregroundStyle(HOHITheme.muted)
                Spacer()
                Text("Completed")
                    .font(.hohi(10.5, weight: .bold))
                    .foregroundStyle(HOHITheme.purple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(HOHITheme.purple.opacity(0.08))
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(HOHITheme.pink.opacity(0.10))
                        .frame(width: 42, height: 42)
                    Text("\(trip.stopNumber)")
                        .font(.hohi(13, weight: .black))
                        .foregroundStyle(HOHITheme.pink)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.destination)
                        .font(.hohi(14, weight: .bold))
                        .foregroundStyle(HOHITheme.ink)
                        .lineLimit(1)
                    Text("\(trip.distance) · \(trip.duration)")
                        .font(.hohi(10.5, weight: .medium))
                        .foregroundStyle(HOHITheme.muted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Orders")
                        .font(.hohi(9.5, weight: .bold))
                        .foregroundStyle(HOHITheme.muted)
                    TextField("0", text: $value)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 46)
                        .font(.hohi(16, weight: .black))
                        .onChange(of: value) { onChange(Int($0) ?? 0) }
                }
            }
        }
        .padding(16)
        .hohiCard(radius: 22)
    }
}
