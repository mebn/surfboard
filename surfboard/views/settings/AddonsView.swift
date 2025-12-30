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
    
    @State private var newAddonUrl: String = ""
    @State private var bundleAddonUrls: [String] = []
    
    /// All addon URLs (bundle + saved), deduplicated
    private var allAddonUrls: [AddonItem] {
        var items: [AddonItem] = []
        var seenUrls = Set<String>()
        
        // First add bundle addons (from Secrets.xcconfig)
        for url in bundleAddonUrls {
            let normalizedUrl = normalizeUrl(url)
            if !seenUrls.contains(normalizedUrl) {
                seenUrls.insert(normalizedUrl)
                items.append(AddonItem(url: url, isFromBundle: true, savedAddon: nil))
            }
        }
        
        // Then add saved addons, skipping duplicates
        for addon in savedAddons {
            let normalizedUrl = normalizeUrl(addon.url)
            if !seenUrls.contains(normalizedUrl) {
                seenUrls.insert(normalizedUrl)
                items.append(AddonItem(url: addon.url, isFromBundle: false, savedAddon: addon))
            }
        }
        
        return items
    }
    
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
                if allAddonUrls.isEmpty {
                    Text("No addons added yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(allAddonUrls) { item in
                        HStack {
                            TextField("", text: .constant(item.url))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if !item.isFromBundle, let savedAddon = item.savedAddon {
                                Button(action: {
                                    deleteAddon(savedAddon)
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
        .onAppear {
            loadBundleAddons()
        }
    }
    
    private func loadBundleAddons() {
        var urls: [String] = []
        let keys = ["CINEMETA", "TORRENTIO", "MEDIAFUSION"]
        
        for key in keys {
            if let urlString = Bundle.main.object(forInfoDictionaryKey: key) as? String,
               !urlString.isEmpty {
                urls.append(urlString)
            }
        }
        
        bundleAddonUrls = urls
    }
    
    private func addAddon() {
        let trimmedUrl = newAddonUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUrl.isEmpty else { return }
        
        // Check for duplicates
        let normalizedNewUrl = normalizeUrl(trimmedUrl)
        let existingUrls = allAddonUrls.map { normalizeUrl($0.url) }
        
        if existingUrls.contains(normalizedNewUrl) {
            // Already exists, don't add duplicate
            newAddonUrl = ""
            return
        }
        
        let savedAddon = SavedAddon(url: trimmedUrl)
        modelContext.insert(savedAddon)
        newAddonUrl = ""
    }
    
    private func deleteAddon(_ addon: SavedAddon) {
        modelContext.delete(addon)
    }
    
    private func normalizeUrl(_ url: String) -> String {
        var normalized = url.lowercased()
        if normalized.hasPrefix("stremio://") {
            normalized = normalized.replacingOccurrences(of: "stremio://", with: "https://")
        }
        // Remove trailing slashes for comparison
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }
}

/// Helper struct for displaying addon items
private struct AddonItem: Identifiable {
    let id = UUID()
    let url: String
    let isFromBundle: Bool
    let savedAddon: SavedAddon?
}

#Preview {
    AddonsView()
        .modelContainer(for: [AppSettings.self, SavedAddon.self], inMemory: true)
}
