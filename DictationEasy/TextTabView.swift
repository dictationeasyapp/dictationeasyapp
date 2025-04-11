import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct TextTabView: View {
    @Binding var selectedTab: TabSelection
    @EnvironmentObject var settings: SettingsModel
    @EnvironmentObject var ocrManager: OCRManager
    let isEditingPastDictation: Bool
    
    init(selectedTab: Binding<TabSelection>, isEditingPastDictation: Bool = false) {
        self._selectedTab = selectedTab
        self.isEditingPastDictation = isEditingPastDictation
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextEditor(text: $settings.extractedText)
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .placeholder(when: settings.extractedText.isEmpty) {
                        Text("Extracted text will appear here 提取的文字將顯示在此處")
                            .foregroundColor(.gray)
                            .padding()
                    }

                HStack(spacing: 20) {
                    #if canImport(UIKit)
                    Button(action: {
                        UIPasteboard.general.string = settings.extractedText
                    }) {
                        Label("Copy 複製", systemImage: "doc.on.doc")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    #else
                    Button(action: {
                        // Fallback for non-UIKit platforms (e.g., macOS)
                        // Copying to clipboard is not supported in this preview
                    }) {
                        Label("Copy 複製", systemImage: "doc.on.doc")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(true)
                    #endif

                    Button(action: {
                        settings.extractedText = ""
                        ocrManager.extractedText = ""
                    }) {
                        Label("Clear 清除", systemImage: "trash")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)

                Button(action: {
                    // Only save non-empty text
                    if !settings.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        settings.savePastDictation(text: settings.extractedText)
                    }
                    // Set playback mode to Sentence-by-Sentence before navigating
                    settings.playbackMode = .sentenceBySentence
                    selectedTab = .speech
                }) {
                    Label("Confirm 確認", systemImage: "checkmark")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(settings.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .navigationTitle("Text 文字")
            .onAppear {
                if settings.extractedText.isEmpty {
                    settings.extractedText = ocrManager.extractedText
                }
                // Only clear editingDictationId if not editing a past dictation
                if !isEditingPastDictation {
                    settings.editingDictationId = nil
                }
                
                #if DEBUG
                print("TextTabView.onAppear - editingDictationId: \(String(describing: settings.editingDictationId))")
                print("TextTabView.onAppear - isEditingPastDictation: \(isEditingPastDictation)")
                #endif
            }
        }
    }
}

extension View {
    func placeholder<Content: View>(when shouldShow: Bool, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: .topLeading) {
            if shouldShow { placeholder() }
            self
        }
    }
}

#Preview {
    TextTabView(selectedTab: .constant(.text), isEditingPastDictation: false)
        .environmentObject(SettingsModel())
        .environmentObject(OCRManager())
}
