import SwiftUI

// MARK: - Liquid Glass primitives
//
// One place for the app's visual language. `glassPanel()` is the workhorse —
// SectionShell, tiles, and cards all route through it, so the look is tuned here.

extension View {
    /// Standard Upsee glass panel — native Liquid Glass with a hairline edge
    /// highlight and a soft drop shadow for depth against the backdrop.
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat = 18, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        self
            .glassEffect(tint.map { Glass.regular.tint($0.opacity(0.16)) } ?? .regular, in: shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .white.opacity(0.03)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }
}

// MARK: - Window backdrop

/// Soft layered color field behind all content — gives the glass something to
/// refract. Tuned to stay quiet in light mode and moody in dark mode.
struct UpseeBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                RadialGradient(
                    colors: [Color.blue.opacity(0.20), .clear],
                    center: .init(x: 0.1, y: 0.0),
                    startRadius: 0, endRadius: geo.size.width * 0.75
                )
                RadialGradient(
                    colors: [Color.teal.opacity(0.14), .clear],
                    center: .init(x: 1.0, y: 1.0),
                    startRadius: 0, endRadius: geo.size.width * 0.8
                )
                RadialGradient(
                    colors: [Color.indigo.opacity(0.12), .clear],
                    center: .init(x: 0.85, y: 0.05),
                    startRadius: 0, endRadius: geo.size.width * 0.5
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Tiles

/// Compact glass stat tile for the Home grid. Clickable when `action` is set.
struct GlassTile: View {
    let icon: String
    let title: String
    let value: String
    var detail: String? = nil
    var tint: Color = .blue
    var badgeCount: Int = 0
    var action: (() -> Void)? = nil

    @State private var hovering = false

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundStyle(tint)
                    Text(title.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.85), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                Text(value)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(cornerRadius: 16, tint: hovering ? tint : nil)
            .scaleEffect(hovering && action != nil ? 1.015 : 1.0)
            .animation(.spring(duration: 0.25), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .disabled(action == nil)
    }
}

/// Large hero tile for the Home top row — bigger number, optional progress bar.
struct HeroTile: View {
    let icon: String
    let title: String
    let value: String
    var detail: String? = nil
    var tint: Color = .blue
    var progress: Double? = nil
    var action: (() -> Void)? = nil

    @State private var hovering = false

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon).foregroundStyle(tint)
                    Text(title.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                Text(value)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let progress {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.15))
                            Capsule()
                                .fill(LinearGradient(colors: [tint, tint.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * min(1, max(0, progress)))
                        }
                    }
                    .frame(height: 6)
                }
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(cornerRadius: 20, tint: hovering ? tint : nil)
            .scaleEffect(hovering && action != nil ? 1.01 : 1.0)
            .animation(.spring(duration: 0.25), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .disabled(action == nil)
    }
}

/// Inline attention chip — compact alert that jumps to its section.
struct AttentionChip: View {
    let icon: String
    let text: String
    var tint: Color = .orange
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(text).font(.caption.weight(.medium)).lineLimit(1)
                Image(systemName: "chevron.right").font(.caption2).opacity(0.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(tint)
            .glassEffect(Glass.regular.tint(tint.opacity(hovering ? 0.30 : 0.18)), in: Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
