import SwiftUI

struct ArrivalView: View {
    @ObservedObject var model: DriveViewModel
    let onHome: () -> Void

    private var trip: CompletedTrip? {
        model.completedTrips.first(where: { $0.stopNumber == model.lastCompletedStopNumber })
    }

    private var origin: String {
        let completedIndex = model.lastCompletedStopNumber - 1
        if completedIndex <= 0 { return "Current Location" }
        let previousIndex = completedIndex - 1
        guard model.stops.indices.contains(previousIndex) else { return "Previous Stop" }
        let value = model.stops[previousIndex].address.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Previous Stop" : value
    }

    private var destination: String {
        let index = model.lastCompletedStopNumber - 1
        guard model.stops.indices.contains(index) else { return "Destination" }
        let value = model.stops[index].address.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Destination" : value
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white, HOHITheme.background, Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer(minLength: 48)

                    ZStack {
                        Circle()
                            .fill(HOHITheme.purple.opacity(0.13))
                            .frame(width: 132, height: 132)
                            .blur(radius: 3)
                        Circle()
                            .fill(HOHITheme.primaryGradient)
                            .frame(width: 108, height: 108)
                            .shadow(color: HOHITheme.purple.opacity(0.30), radius: 24)
                        Image(systemName: "checkmark")
                            .font(.hohi(46, weight: .black))
                            .foregroundStyle(.white)
                    }

                    Text("Trip Completed!")
                        .font(.hohi(30, weight: .black))
                        .foregroundStyle(HOHITheme.ink)

                    Text("\(origin)  →  \(destination)")
                        .font(.hohi(16, weight: .medium))
                        .foregroundStyle(HOHITheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    HStack(spacing: 14) {
                        CompletionStat(
                            value: trip?.distance ?? "—",
                            label: "Distance"
                        )
                        CompletionStat(
                            value: trip?.duration ?? "—",
                            label: "Duration"
                        )
                    }

                    HStack(spacing: 14) {
                        Image(systemName: "display")
                            .font(.hohi(23, weight: .bold))
                            .foregroundStyle(HOHITheme.purple)
                            .frame(width: 50, height: 50)
                            .background(HOHITheme.purple.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.qrString.isEmpty ? "Payment QR is not configured" : "Payment is ready")
                                .font(.hohi(15, weight: .bold))
                                .foregroundStyle(HOHITheme.ink)
                            Text(model.qrString.isEmpty ? "Open Order and save the QR payment data before the next completed stage." : "The payment QR is showing on the external OLED device.")
                                .font(.hohi(12.5, weight: .medium))
                                .foregroundStyle(HOHITheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                    }
                    .padding(18)
                    .hohiCard(radius: 22)

                    Button {
                        if model.nextIncompleteIndex == nil {
                            model.startNewTrip()
                            onHome()
                        } else {
                            model.continueNextStage()
                        }
                    } label: {
                        HStack {
                            Text(model.nextIncompleteIndex == nil ? "Finish Trip" : "Continue to Next Stop")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.hohi(15, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 58)
                        .background(HOHITheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: HOHITheme.purple.opacity(0.22), radius: 14, y: 6)
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.startNewTrip()
                        onHome()
                    } label: {
                        Text("Back to Home")
                            .font(.hohi(15, weight: .bold))
                            .foregroundStyle(HOHITheme.purple)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(.white.opacity(0.80))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(HOHITheme.purple.opacity(0.35), lineWidth: 1.3)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 22)
            }
        }
    }
}

private struct CompletionStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.hohi(24, weight: .black))
                .foregroundStyle(HOHITheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.hohi(11, weight: .medium))
                .foregroundStyle(HOHITheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .hohiCard(radius: 22)
    }
}
