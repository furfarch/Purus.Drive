import SwiftUI
import Combine

struct MigrationOverlayView: View {
    @EnvironmentObject var progress: MigrationProgress

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Group {
                    switch progress.state {
                    case .idle:
                        EmptyView()
                    case .running(let title, let message):
                        overlayBox(icon: AnyView(ProgressView()), title: title, subtitle: message, tint: .accentColor)
                    case .success(let message):
                        overlayBox(icon: AnyView(Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)), title: (message ?? "Done"), subtitle: nil, tint: .green)
                    case .failure(let error):
                        overlayBox(icon: AnyView(Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)), title: "Migration failed", subtitle: error, tint: .yellow)
                    }
                }
                .animation(.default, value: progress.isVisible)
                .padding()
                .allowsHitTesting(false) // non-blocking
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func overlayBox(icon: AnyView, title: String, subtitle: String?, tint: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            icon
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).bold()
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
        .shadow(radius: 6)
        .frame(maxWidth: 420)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

