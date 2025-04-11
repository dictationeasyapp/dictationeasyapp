import SwiftUI

struct SettingsTabView: View {
    @EnvironmentObject var settings: SettingsModel
    @State private var showDeleteConfirmation = false
    @State private var showSettingsError = false // For file system errors
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        return "App Version: \(version) 應用版本：\(version)"
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Label("Delete All Past Dictations 刪除所有過去文章", systemImage: "trash")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(settings.pastDictations.isEmpty ? Color.gray : Color.red)
                            .cornerRadius(10)
                    }
                    .disabled(settings.pastDictations.isEmpty)
                    .accessibilityLabel("Delete All Past Dictations Button 刪除所有過去文章按鈕")
                } header: {
                    Text("Data Management 數據管理")
                }
                
                Section {
                    Text(appVersion)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("App Version 應用版本")
                } header: {
                    Text("About 關於")
                }
            }
            .padding(.horizontal)
            .navigationTitle("Settings 設置")
            .alert("Delete All Past Dictations 刪除所有過去文章", isPresented: $showDeleteConfirmation) {
                Button("Delete 刪除", role: .destructive) {
                    settings.deleteAllPastDictations()
                }
                Button("Cancel 取消", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete all past dictations? This action cannot be undone. 您確定要刪除所有過去文章嗎？此操作無法撤銷。")
            }
            .alert("Settings Error 設置錯誤", isPresented: $showSettingsError) {
                Button("OK 確定", role: .cancel) {
                    settings.error = nil // Clear the error after dismissal
                }
            } message: {
                Text(settings.error ?? "Unknown error 未知錯誤")
            }
            .onChange(of: settings.error) { newError in
                if newError != nil {
                    showSettingsError = true
                }
            }
        }
    }
}

#Preview {
    SettingsTabView()
        .environmentObject(SettingsModel())
}
