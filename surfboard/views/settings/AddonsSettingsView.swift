//
//  AddonsSettingsView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-27.
//

import SwiftUI
import SwiftData

struct AddonsSettingsView: View {
    @Bindable var settings: AppSettings
    @State private var torrentioURL: String = ""
    @State private var showSavedMessage: Bool = false
    
    private var secretsURL: String {
        Bundle.main.object(forInfoDictionaryKey: "TORRENTIO_BASE_URL") as? String ?? ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("Addons")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Torrentio Base URL")
                    .font(.headline)
                
                Text("Enter your Torrentio addon URL including the API key. Leave empty to use the default from secrets.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("https://torrentio.strem.fun/...", text: $torrentioURL)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                if !secretsURL.isEmpty {
                    Text("Default URL from secrets: \(secretsURL.prefix(50))...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 20) {
                    Button("Save") {
                        settings.torrentioBaseURL = torrentioURL.isEmpty ? nil : torrentioURL
                        showSavedMessage = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showSavedMessage = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Reset to Default") {
                        torrentioURL = ""
                        settings.torrentioBaseURL = nil
                    }
                    .buttonStyle(.bordered)
                    
                    if showSavedMessage {
                        Text("Saved!")
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }
                }
                .padding(.top, 10)
            }
            
            Spacer()
        }
        .padding(40)
        .onAppear {
            torrentioURL = settings.torrentioBaseURL ?? ""
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: AppSettings.self, configurations: config)
    let settings = AppSettings()
    container.mainContext.insert(settings)
    
    return AddonsSettingsView(settings: settings)
        .modelContainer(container)
}
