import SwiftUI

struct AboutView: View {
    /// build month, read from the app binary's date (the current month was shown before)
    private var buildMonth: String? {
        guard let path = Bundle.main.executablePath,
              let date = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy MMMM" // e.g., 2025 December
        return formatter.string(from: date)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text("Purus Drive")
                    .font(.headline)

                Text([buildMonth, "Personal Vehicle and Drive Log"].compactMap { $0 }.joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Text("Icon Credits")
                    .font(.title3)
                    .bold()

                VStack(alignment: .leading, spacing: 8) {
                    Link("Van icon by Icons8", destination: URL(string: "https://icons8.com/icon/30485/van")!)
                    Link("Truck Ramp icon by Icons8", destination: URL(string: "https://icons8.com/icon/G2CogVmUerTy/truck-ramp")!)
                    Link("Camper icon by Icons8", destination: URL(string: "https://icons8.com/icon/19819/camper")!)
                    Link("Truck With Trailer icon by Icons8", destination: URL(string: "https://icons8.com/icon/Ter45jrGlmza/truck-with-trailer")!)
                    Link("Utility Trailer icon by Icons8", destination: URL(string: "https://icons8.com/icon/wb008axDewRF/utility-trailer")!)
                    Link("Trailer icon by Icons8", destination: URL(string: "https://icons8.com/icon/17yo0TvgAx0t/trailer")!)
                    Link("Motorbike icon by Icons8", destination: URL(string: "https://icons8.com/icon/259/scooter")!)
                    Link("Cars icon by Icons8", destination: URL(string: "https://icons8.com/icon/16559/traffic-jam")!)
                    Link("Sedan icon by Icons8", destination: URL(string: "https://icons8.com/icon/16553/sedan")!)
                }
                .font(.body)

                Spacer(minLength: 0)
            }
            .padding()
        }
    }
}

#Preview {
    NavigationStack { AboutView() }
}
