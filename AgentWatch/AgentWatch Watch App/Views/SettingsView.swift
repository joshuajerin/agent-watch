// SettingsView.swift
// VPS URL, bearer token (Keychain), voice config.
// Accessible via the Watch app's navigation.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var vpsURL: String = ""
    @State private var token: String = ""
    @State private var voiceRate: Double = 0.5
    @State private var voicePitch: Double = 1.0
    @State private var showTokenField: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section("Connection") {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VPS URL")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.gray)
                        TextField("wss://your-vps:443/ws", text: $vpsURL)
                            .font(.system(.caption2, design: .monospaced))
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auth Token")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.gray)
                        if showTokenField {
                            SecureField("token", text: $token)
                                .font(.system(.caption2, design: .monospaced))
                        } else {
                            Button(action: { showTokenField = true }) {
                                Text(token.isEmpty ? "tap to set" : "••••••••")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Voice") {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rate: \(String(format: "%.1f", voiceRate))")
                            .font(.system(.caption2, design: .monospaced))
                        Slider(value: $voiceRate, in: 0.1...1.0)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pitch: \(String(format: "%.1f", voicePitch))")
                            .font(.system(.caption2, design: .monospaced))
                        Slider(value: $voicePitch, in: 0.5...2.0)
                    }
                }

                Section {
                    Button("Save") { saveSettings() }
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.green)

                    Button("Clear Token") { clearToken() }
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .onAppear { loadSettings() }
        }
    }

    private func loadSettings() {
        vpsURL = UserDefaults.standard.string(forKey: "vps_url") ?? ""
        token = KeychainHelper.load(key: "auth_token") ?? ""
        voiceRate = UserDefaults.standard.double(forKey: "voice_rate").clamped(to: 0.1...1.0, default: 0.5)
        voicePitch = UserDefaults.standard.double(forKey: "voice_pitch").clamped(to: 0.5...2.0, default: 1.0)
    }

    private func saveSettings() {
        guard vpsURL.hasPrefix("wss://") else {
            appState.setError("URL must start with wss://")
            return
        }
        UserDefaults.standard.set(vpsURL, forKey: "vps_url")
        UserDefaults.standard.set(voiceRate, forKey: "voice_rate")
        UserDefaults.standard.set(voicePitch, forKey: "voice_pitch")
        KeychainHelper.save(key: "auth_token", value: token)
        appState.reloadSettings()
        showTokenField = false
    }

    private func clearToken() {
        token = ""
        KeychainHelper.delete(key: "auth_token")
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:                kSecClassGenericPassword,
            kSecAttrAccount as String:          key,
            kSecValueData as String:            data,
            kSecAttrAccessible as String:       kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:                kSecClassGenericPassword,
            kSecAttrAccount as String:          key,
            kSecReturnData as String:           true,
            kSecMatchLimit as String:           kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Double extension

private extension Double {
    func clamped(to range: ClosedRange<Double>, default defaultValue: Double) -> Double {
        guard self > 0 else { return defaultValue }
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
