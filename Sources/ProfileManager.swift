import Foundation

/// Manages button profiles: loading, saving, and switching between profiles
class ProfileManager {
    static let shared = ProfileManager()

    private let userDefaults = UserDefaults.standard
    private let profilesKey = "ButtonProfiles"
    private let activeProfileKey = "ActiveProfileName"

    private(set) var profiles: [ButtonProfile] = []
    private(set) var activeProfile: ButtonProfile

    var onProfileChanged: ((ButtonProfile) -> Void)?

    private init() {
        // Initialize with default values first
        self.profiles = []
        self.activeProfile = ButtonProfile.desktopTerminal

        // Load saved profiles or use defaults
        if let savedProfiles = loadProfilesFromUserDefaults(), !savedProfiles.isEmpty {
            self.profiles = savedProfiles
        } else {
            self.profiles = ButtonProfile.allDefaultProfiles
            saveProfilesToUserDefaults()
        }

        // Load active profile
        let activeProfileName = userDefaults.string(forKey: activeProfileKey) ?? "Desktop + Terminal"
        self.activeProfile = profiles.first { $0.name == activeProfileName } ?? ButtonProfile.desktopTerminal

        // Ensure default profiles are always available
        ensureDefaultProfilesExist()
    }

    // MARK: - Profile Management

    func setActiveProfile(_ profile: ButtonProfile) {
        activeProfile = profile
        userDefaults.set(profile.name, forKey: activeProfileKey)
        onProfileChanged?(profile)
    }

    func setActiveProfile(named name: String) {
        if let profile = profiles.first(where: { $0.name == name }) {
            setActiveProfile(profile)
        }
    }

    func addProfile(_ profile: ButtonProfile) {
        if !profiles.contains(where: { $0.name == profile.name }) {
            profiles.append(profile)
            saveProfilesToUserDefaults()
        }
    }

    func updateProfile(_ profile: ButtonProfile) {
        if let index = profiles.firstIndex(where: { $0.name == profile.name }) {
            profiles[index] = profile
            saveProfilesToUserDefaults()

            // Update active profile if it's the one being modified
            if activeProfile.name == profile.name {
                activeProfile = profile
                onProfileChanged?(profile)
            }
        }
    }

    func deleteProfile(named name: String) {
        // Prevent deleting the active profile or default profiles
        guard name != activeProfile.name else { return }
        guard !ButtonProfile.allDefaultProfiles.contains(where: { $0.name == name }) else { return }

        profiles.removeAll { $0.name == name }
        saveProfilesToUserDefaults()
    }

    func resetToDefaults() {
        profiles = ButtonProfile.allDefaultProfiles
        activeProfile = ButtonProfile.desktopTerminal
        userDefaults.set(activeProfile.name, forKey: activeProfileKey)
        saveProfilesToUserDefaults()
        onProfileChanged?(activeProfile)
    }

    // MARK: - Persistence

    private func loadProfilesFromUserDefaults() -> [ButtonProfile]? {
        guard let data = userDefaults.data(forKey: profilesKey) else { return nil }
        return try? JSONDecoder().decode([ButtonProfile].self, from: data)
    }

    private func saveProfilesToUserDefaults() {
        if let data = try? JSONEncoder().encode(profiles) {
            userDefaults.set(data, forKey: profilesKey)
        }
    }

    private func ensureDefaultProfilesExist() {
        let existingNames = profiles.map { $0.name }

        for defaultProfile in ButtonProfile.allDefaultProfiles {
            if !existingNames.contains(defaultProfile.name) {
                profiles.append(defaultProfile)
            }
        }

        // Save if we added any missing default profiles
        let currentProfiles = loadProfilesFromUserDefaults() ?? []
        if profiles.count != currentProfiles.count {
            saveProfilesToUserDefaults()
        }
    }

    // MARK: - Profile Info

    func getProfileNames() -> [String] {
        profiles.map { $0.name }
    }

    func getProfile(named name: String) -> ButtonProfile? {
        profiles.first { $0.name == name }
    }
}
