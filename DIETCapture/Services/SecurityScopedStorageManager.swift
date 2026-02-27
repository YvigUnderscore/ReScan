// SecurityScopedStorageManager.swift
// ReScan
//
// Manages security-scoped bookmark data for external external storage (SSD/USB-C).
// Allows the app to remember and write to a user-selected folder across sessions.

import Foundation
import Combine

/// Singleton manager for external storage URLs and bookmarks.
final class SecurityScopedStorageManager: ObservableObject {
    static let shared = SecurityScopedStorageManager()
    
    // MARK: - Properties
    
    /// The resolved URL that the user selected, if it exists and is accessible.
    @Published var externalStorageURL: URL? {
        didSet {
            // Keep AppSettings in sync for UI purposes
            AppSettings.shared.hasExternalStorage = (externalStorageURL != nil)
        }
    }
    
    private let userDefaultsKey = "externalStorageBookmarkData"
    
    // MARK: - Initialization
    
    private init() {
        restoreBookmark()
    }
    
    deinit {
        stopAccessing()
    }
    
    // MARK: - Methods
    
    /// Save a newly selected URL from the UIDocumentPicker / fileImporter
    func saveExternalURL(_ url: URL) {
        // Stop accessing the old one if it exists
        stopAccessing()
        
        // Ensure we can access the new URL
        guard url.startAccessingSecurityScopedResource() else {
            print("[SecurityScopedStorageManger] Failed to start accessing the new URL.")
            return
        }
        
        do {
            let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: userDefaultsKey)
            externalStorageURL = url
            print("[SecurityScopedStorageManger] Saved bookmark for \(url.lastPathComponent)")
        } catch {
            print("[SecurityScopedStorageManger] Failed to create bookmark data: \(error.localizedDescription)")
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    /// Clear the saved external URL and bookmark
    func clearExternalURL() {
        stopAccessing()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        externalStorageURL = nil
    }
    
    // MARK: - Internal
    
    private func restoreBookmark() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }
        
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("[SecurityScopedStorageManger] Bookmark data is stale. Attempting to renew.")
                // Try saving it again later, we just need to re-bookmark it
                // Actually, doing it here is fine
                let newData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(newData, forKey: userDefaultsKey)
            }
            
            if url.startAccessingSecurityScopedResource() {
                DispatchQueue.main.async { [weak self] in
                    self?.externalStorageURL = url
                }
                print("[SecurityScopedStorageManger] Restored bookmark for \(url.lastPathComponent)")
            } else {
                print("[SecurityScopedStorageManger] Failed to start accessing restored URL.")
                // We don't clear it just in case the drive is temporarily unplugged
            }
        } catch {
            print("[SecurityScopedStorageManger] Failed to resolve bookmark: \(error.localizedDescription)")
            // It could be unplugged, or permissions revoked. Let's not clear it immediately.
        }
    }
    
    private func stopAccessing() {
        externalStorageURL?.stopAccessingSecurityScopedResource()
    }
}
