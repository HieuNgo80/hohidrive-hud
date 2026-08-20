import SwiftUI

struct OrdersView: View {
    @ObservedObject var model: DriveViewModel
    @State private var qrDraft = ""

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
                    header
                    paymentQRCard

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
        .onAppear { qrDraft = model.qrString }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Orders")
                    .font(.hohi(31, weight: .black))
                    .foregroundStyle(HOHITheme.ink)
                Text("Payment setup & completed routes")
                    .font(.hohi(13.5, weight: .medium))
                    .foregroundStyle(HOHITheme.muted)
            }
            Spacer()
            Image(systemName: "bag.fill")
                .font(.hohi(17, weight: .bold))
                .foregroundStyle(HOHITheme.purple)
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.82))
                .clipShape(Circle())
        }
        .padding(.top, 18)
    }

    private var paymentQRCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Payment QR")
                        .font(.hohi(17, weight: .black))
                        .foregroundStyle(HOHITheme.ink)
                    Text("Paste the QR payment data used for every completed stage.")
                        .font(.hohi(11.5, weight: .medium))
                        .foregroundStyle(HOHITheme.muted)
                }
                Spacer()
                Text(model.qrString.isEmpty ? "NOT SET" : "SAVED")
                    .font(.hohi(9.5, weight: .black))
                    .foregroundStyle(model.qrString.isEmpty ? HOHITheme.pink : HOHITheme.purple)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background((model.qrString.isEmpty ? HOHITheme.pink : HOHITheme.purple).opacity(0.08))
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                Image(systemName: "qrcode")
                    .font(.hohi(18, weight: .bold))
                    .foregroundStyle(HOHITheme.purple)

                StableTextField(
                    text: $qrDraft,
                    placeholder: "Paste VietQR / QR payload here",
                    returnKeyType: .done,
                    onSubmit: { model.saveQR(qrDraft) }
                )
                .frame(height: 42)
            }
            .padding(.horizontal, 14)
            .background(HOHITheme.background.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            HStack(spacing: 10) {
                Button {
                    model.saveQR(qrDraft)
                } label: {
                    Text("Save QR Data")
                        .font(.hohi(12.5, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 43)
                        .background(HOHITheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                if !model.qrString.isEmpty || !qrDraft.isEmpty {
                    Button {
                        qrDraft = ""
                        model.clearQR()
                    } label: {
                        Image(systemName: "trash")
                            .font(.hohi(13, weight: .bold))
                            .foregroundStyle(HOHITheme.pink)
                            .frame(width: 44, height: 43)
                            .background(HOHITheme.pink.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "display")
                    .font(.hohi(12, weight: .bold))
                    .foregroundStyle(HOHITheme.purple)
                Text("The QR image is never displayed in the iPhone app. When a stage is completed, this saved payload is sent to the external OLED HUD for 5 minutes.")
                    .font(.hohi(10.5, weight: .medium))
                    .foregroundStyle(HOHITheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .hohiCard(radius: 22)
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
