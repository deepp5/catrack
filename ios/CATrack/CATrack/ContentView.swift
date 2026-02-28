import SwiftUI

struct ContentView: View {
    
    @State private var responseText = "Press button to test backend"
    
    var body: some View {
        VStack(spacing: 20) {
            
            Text(responseText)
                .padding()
            
            Button("Connect to Backend") {
                Task {
                    await callBackend()
                }
            }
        }
        .padding()
    }
    
    func callBackend() async {
        guard let url = URL(string: "http://127.0.0.1:8000/ping") else {
            responseText = "Invalid URL"
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(PingResponse.self, from: data)
            responseText = decoded.status
            
        } catch {
            responseText = "Error: \(error.localizedDescription)"
        }
    }
}

struct PingResponse: Codable {
    let status: String
}
//comments
