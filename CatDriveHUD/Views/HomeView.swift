import SwiftUI

struct HomeView: View {
    @ObservedObject var model: DriveViewModel
    let onStart: () -> Void

    @FocusState private var focusedStopID: UUID?

    private var canAddStop: Bool {
        guard model.stops.count < model.maxStops, let last = model.stops.last else { return false }
        return !last.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canStart: Bool {
        model.stops.contains { !$0.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var connectionLabel: String {
        model.hudConnected ? "HUD connected" : "HUD not connected"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [HOHITheme.background, .white, Color(red: 0.98, green: 0.975, blue: 1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                titleBlock
                    .padding(.top, 10)
                    .padding(.horizontal, 20)

                routeCard
                    .padding(.horizontal, 16)

                Spacer(minLength: 92)
            }
        }
        .onAppear {
            if let first = model.stops.first, model.stops.count == 1, first.address.isEmpty {
                focusedStopID = first.id
            }
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("HOHI DRIVE")
                .font(.hohi(22, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(HOHITheme.ink)

            HStack(spacing: 6) {
                Circle()
                    .fill(model.hudConnected ? HOHITheme.purple : HOHITheme.pink)
                    .frame(width: 7, height: 7)
                Text(connectionLabel)
                    .font(.hohi(12, weight: .semibold))
                    .foregroundStyle(model.hudConnected ? HOHITheme.purple : HOHITheme.muted)
            }
        }
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Where are you going?")
                .font(.hohi(25, weight: .heavy))
                .foregroundStyle(HOHITheme.ink)

            Divider().opacity(0.45)

            currentLocationRow

            destinationList

            addLocationButton

            if model.isCalculating || !model.statusText.isEmpty {
                HStack(spacing: 8) {
                    if model.isCalculating {
                        ProgressView().scaleEffect(0.82)
                    }
                    Text(model.statusText)
                        .font(.hohi(11, weight: .medium))
                        .foregroundStyle(HOHITheme.muted)
                        .lineLimit(2)
                    Spacer()
                }
            }

            startRouteButton

            Text("You can add up to \(model.maxStops) destinations")
                .font(.hohi(11, weight: .medium))
                .foregroundStyle(HOHITheme.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
        .hohiCard(radius: 28)
    }

    private var destinationList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(model.stops.enumerated()), id: \.element.id) { index, stop in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 52)
                            .opacity(0.35)
                    }

                    RouteStopRow(
                        model: model,
                        focusedStopID: $focusedStopID,
                        stopID: stop.id,
                        number: index + 1
                    )
                }
            }
            .padding(.bottom, 4)
        }
        .frame(maxHeight: min(CGFloat(max(model.stops.count, 1)) * 96.0, 320.0))
        .scrollDismissesKeyboard(.interactively)
    }

    private var addLocationButton: some View {
        Button {
            guard canAddStop else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                model.addStop()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focusedStopID = model.stops.last?.id
            }
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
            .foregroundStyle(canAddStop ? HOHITheme.purple : HOHITheme.muted.opacity(0.55))
            .padding(.horizontal, 15)
            .frame(height: 52)
            .background(HOHITheme.purple.opacity(canAddStop ? 0.055 : 0.025))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        HOHITheme.purple.opacity(canAddStop ? 0.24 : 0.08),
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
            focusedStopID = nil
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
            .frame(height: 58)
            .background(HOHITheme.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: HOHITheme.purple.opacity(0.22), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!canStart || model.isCalculating)
        .opacity(canStart ? 1 : 0.48)
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
        .padding(.vertical, 4)
    }
}
