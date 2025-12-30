//
//  AddonsView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-30.
//

import SwiftUI
import SwiftData

struct AddonsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedAddon.createdAt) private var savedAddons: [SavedAddon]
    @ObservedObject private var addonManager = AddonManager.shared
    
    @State private var newAddonUrl: String = ""
    
    var body: some View {
        List {
            Section("New addon") {
                HStack {
                    TextField("https://.../manifest.json", text: $newAddonUrl)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                    
                    Button(action: {
                        addAddon()
                    }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .disabled(newAddonUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            
            Section("Your addons") {
                if savedAddons.isEmpty {
                    Text("No addons added yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(savedAddons) { addon in
                        HStack {
                            TextField("", text: .constant(addon.url))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                deleteAddon(addon)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    private func addAddon() {
        let trimmedUrl = newAddonUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUrl.isEmpty else { return }
        
        // Check for duplicates against saved addons
        let normalizedNewUrl = addonManager.normalizeUrl(trimmedUrl)
        if savedAddons.contains(where: { addonManager.normalizeUrl($0.url) == normalizedNewUrl }) {
            newAddonUrl = ""
            return
        }
        
        let savedAddon = SavedAddon(url: trimmedUrl)
        modelContext.insert(savedAddon)
        newAddonUrl = ""
        
        // Reload addons
        Task {
            await addonManager.loadAddons(savedAddonUrls: savedAddons.map { $0.url } + [trimmedUrl])
        }
    }
    
    private func deleteAddon(_ addon: SavedAddon) {
        modelContext.delete(addon)
        
        // Reload addons
        Task {
            let remainingUrls = savedAddons.filter { $0.id != addon.id }.map { $0.url }
            await addonManager.loadAddons(savedAddonUrls: remainingUrls)
        }
    }
}

#Preview {
    AddonsView()
        .modelContainer(for: [AppSettings.self, SavedAddon.self], inMemory: true)
}
