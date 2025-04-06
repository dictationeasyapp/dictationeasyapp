import SwiftUI
import PhotosUI
import Vision

#if os(iOS)
import UIKit
#endif

struct ScanTabView: View {
    @Binding var selectedTab: TabSelection
    @EnvironmentObject var ocrManager: OCRManager
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Select Image 選擇圖片", systemImage: "photo")
                        .font(.title2)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .onChange(of: selectedItem) { newItem in
                    if let newItem = newItem {
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                selectedImage = image
                            } else {
                                errorMessage = "Failed to load image 無法加載圖片"
                                showError = true
                            }
                        }
                    } else {
                        selectedImage = nil
                    }
                }

                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .cornerRadius(10)
                }

                if isProcessing {
                    ProgressView("Processing... 處理中")
                }

                if selectedImage != nil {
                    HStack(spacing: 20) {
                        Button(action: {
                            selectedItem = nil
                            selectedImage = nil
                        }) {
                            Label("Cancel 取消", systemImage: "xmark")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(10)
                        }

                        Button(action: {
                            processImage()
                        }) {
                            Label("Extract Text 提取文字", systemImage: "text.viewfinder")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Scan 掃描")
            .alert("Error 錯誤", isPresented: $showError) {
                Button("OK 確定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func processImage() {
        guard let image = selectedImage else { return }
        isProcessing = true
        Task {
            do {
                try await ocrManager.processImage(image)
                if let ocrError = ocrManager.error {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: ocrError])
                }
                selectedTab = .text
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isProcessing = false
        }
    }
}

#Preview {
    ScanTabView(selectedTab: .constant(.scan))
        .environmentObject(OCRManager())
}
