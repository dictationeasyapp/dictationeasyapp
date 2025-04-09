import SwiftUI

#if os(iOS)
import UIKit
#endif

struct TextTabView: View {
    @Binding var selectedTab: TabSelection
    @EnvironmentObject var settings: SettingsModel
    @EnvironmentObject var ocrManager: OCRManager

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
                    Button(action: {
                        #if os(iOS)
                        UIPasteboard.general.string = settings.extractedText
                        #endif
                    }) {
                        Label("Copy 複製", systemImage: "doc.on.doc")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }

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
                    selectedTab = .speech
                }) {
                    Label("Confirm 確認", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(!settings.extractedText.isEmpty ? Color.blue : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(settings.extractedText.isEmpty)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Text 文字")
            .onAppear {
                if settings.extractedText.isEmpty {
                    settings.extractedText = ocrManager.extractedText
                }
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
    TextTabView(selectedTab: .constant(.text))
        .environmentObject(SettingsModel())
        .environmentObject(OCRManager())
}
