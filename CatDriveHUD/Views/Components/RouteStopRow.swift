import SwiftUI
import UIKit
import MapKit

struct RouteStopRow: View {
    @ObservedObject var model: DriveViewModel
    let stopID: UUID
    let number: Int

    private var currentStop: DriveStop? {
        model.stops.first(where: { $0.id == stopID })
    }

    private var addressBinding: Binding<String> {
        Binding(
            get: {
                model.stops.first(where: { $0.id == stopID })?.address ?? ""
            },
            set: { newValue in
                model.updateStop(newValue, id: stopID)
            }
        )
    }

    var body: some View {
        if let stop = currentStop {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(number == 1 ? HOHITheme.pink.opacity(0.10) : HOHITheme.purple.opacity(0.10))
                            .frame(width: 40, height: 40)

                        Text(String(format: "%02d", number))
                            .font(.hohi(11.5, weight: .black))
                            .foregroundStyle(number == 1 ? HOHITheme.pink : HOHITheme.purple)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Destination \(number)")
                            .font(.hohi(14, weight: .semibold))
                            .foregroundStyle(HOHITheme.ink)

                        StableTextField(
                            text: addressBinding,
                            placeholder: "Enter location",
                            isEnabled: !stop.completed,
                            returnKeyType: number < model.maxStops ? .next : .done,
                            onBeginEditing: {
                                model.selectSuggestionField(id: stopID)
                            },
                            onSubmit: {}
                        )
                        .frame(height: 28)
                        .id(stopID)
                    }

                    Spacer(minLength: 4)

                    if stop.completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.hohi(18, weight: .bold))
                            .foregroundStyle(.green)
                            .padding(.top, 3)
                    } else {
                        Button {
                            DispatchQueue.main.async {
                                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                                    model.removeStop(id: stopID)
                                }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.hohi(10.5, weight: .black))
                                .foregroundStyle(HOHITheme.muted)
                                .frame(width: 30, height: 30)
                                .background(HOHITheme.background)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isCalculating)
                    }
                }
                .padding(.vertical, 8)

                if model.activeStopID == stopID && !model.suggestions.isEmpty && !stop.completed {
                    VStack(spacing: 0) {
                        ForEach(Array(model.suggestions.prefix(3)), id: \.self) { suggestion in
                            Button {
                                model.chooseSuggestion(suggestion)
                                UIApplication.shared.sendAction(
                                    #selector(UIResponder.resignFirstResponder),
                                    to: nil,
                                    from: nil,
                                    for: nil
                                )
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.hohi(13, weight: .bold))
                                        .foregroundStyle(HOHITheme.purple)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.title)
                                            .font(.hohi(12, weight: .semibold))
                                            .foregroundStyle(HOHITheme.ink)
                                            .lineLimit(1)
                                        Text(suggestion.subtitle)
                                            .font(.hohi(10.5, weight: .medium))
                                            .foregroundStyle(HOHITheme.muted)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(HOHITheme.background.opacity(0.74))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.leading, 52)
                    .padding(.bottom, 4)
                }
            }
        }
    }
}
