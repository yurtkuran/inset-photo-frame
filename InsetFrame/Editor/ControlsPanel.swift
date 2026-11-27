import SwiftUI

struct ControlsPanel: View {
    @Binding var settings: FrameSettings
    /// Orientation-corrected full-resolution size of the current photograph, used to show pixel values.
    let imageSize: CGSize
    let isExporting: Bool
    let onReset: () -> Void
    let onSave: () -> Void

    var body: some View {
        // The same geometry the export uses, so the displayed pixels match the exported frame.
        let geometry = FrameGeometry(imageRect: CGRect(origin: .zero, size: imageSize), settings: settings)

        VStack(alignment: .leading, spacing: 20) {
            LabeledSlider(
                title: "Frame width",
                valueText: Self.pixelText(geometry.frameWidth),
                accessibilityValueText: Self.pixelAccessibilityText(geometry.frameWidth),
                value: Binding(
                    get: { WidthSliderMapping.position(forPercent: settings.widthPercent) },
                    set: { settings.widthPercent = WidthSliderMapping.percent(forPosition: $0) }
                ),
                range: 0...1
            )
            LabeledSlider(
                title: "Frame offset",
                valueText: Self.pixelText(geometry.frameOffset),
                accessibilityValueText: Self.pixelAccessibilityText(geometry.frameOffset),
                value: $settings.offsetPercent,
                range: FrameSettings.offsetRange,
                step: 0.1
            )
            LabeledSlider(
                title: "Transparency",
                valueText: Self.percentText(settings.transparencyPercent, fractionDigits: 0),
                value: $settings.transparencyPercent,
                range: FrameSettings.transparencyRange,
                step: 1
            )
            ColorRow(color: $settings.color)

            Divider()

            HStack {
                Button("Reset", action: onReset)
                    .disabled(settings == .defaults)
                Spacer()
                Button(action: onSave) {
                    if isExporting {
                        ProgressView()
                            .accessibilityLabel("Saving")
                    } else {
                        Label("Save Photo", systemImage: "square.and.arrow.down")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
            }
        }
    }

    /// Full-resolution pixels, rounded to a whole pixel for display (for example, "15 px").
    nonisolated static func pixelText(_ pixels: CGFloat) -> String {
        "\(Int(pixels.rounded()).formatted()) px"
    }

    nonisolated static func pixelAccessibilityText(_ pixels: CGFloat) -> String {
        String(localized: "\(Int(pixels.rounded())) pixels")
    }

    nonisolated static func percentText(_ percent: Double, fractionDigits: Int) -> String {
        (percent / 100).formatted(.percent.precision(.fractionLength(fractionDigits)))
    }
}

struct LabeledSlider: View {
    let title: LocalizedStringKey
    let valueText: String
    var accessibilityValueText: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                Spacer()
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)

            slider
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text(accessibilityValueText ?? valueText))
        }
    }

    @ViewBuilder
    private var slider: some View {
        if let step {
            Slider(value: $value, in: range, step: step)
        } else {
            Slider(value: $value, in: range)
        }
    }
}

struct ColorRow: View {
    @Binding var color: FrameColor

    private let targetSize: CGFloat = 44
    private let swatchSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            title
            swatches
                // Let the 44 pt touch targets overhang so the outer circles align with the label and divider.
                .padding(.horizontal, -(targetSize - swatchSize) / 2)
        }
    }

    private var title: some View {
        Text("Frame color")
            .accessibilityAddTraits(.isHeader)
    }

    private var swatches: some View {
        let selectedPreset = color.preset
        return HStack(spacing: 0) {
            ForEach(FrameColor.presets) { preset in
                let isSelected = selectedPreset?.id == preset.id
                if preset.id != FrameColor.presets.first?.id {
                    Spacer(minLength: 0)
                }
                Button {
                    color = preset.color
                } label: {
                    Circle()
                        .fill(preset.color.color)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 1))
                        .frame(width: swatchSize, height: swatchSize)
                        .overlay { selectionRing(isVisible: isSelected) }
                        .frame(width: targetSize, height: targetSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preset.name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }

            Spacer(minLength: 0)
            ColorPicker(
                "Custom color",
                selection: Binding(
                    get: { color.cgColor },
                    set: { if let custom = FrameColor(cgColor: $0) { color = custom } }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            .frame(width: targetSize, height: targetSize)
            .overlay { selectionRing(isVisible: selectedPreset == nil).allowsHitTesting(false) }
            .accessibilityAddTraits(selectedPreset == nil ? .isSelected : [])
        }
    }

    @ViewBuilder
    private func selectionRing(isVisible: Bool) -> some View {
        if isVisible {
            Circle()
                .strokeBorder(Color.primary, lineWidth: 2)
                .frame(width: swatchSize + 8, height: swatchSize + 8)
        }
    }
}
