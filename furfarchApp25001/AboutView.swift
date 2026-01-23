import SwiftUI

struct AboutView: View {
    private var yearMonth: String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy MMMM" // e.g., 2025 December
        return formatter.string(from: now)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text("Simply Drive")
                    .font(.headline)

                Text("\(yearMonth) • Personal Vehicle and Drive Log")
                    .font(.subheadline)
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
