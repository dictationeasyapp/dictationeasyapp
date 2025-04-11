import SwiftUI
#if canImport(UIKit)
import PhotosUI
import Vision
import Photos
import AVFoundation
import UIKit
#endif

struct ScanTabView: View {
    #if canImport(UIKit)
    @EnvironmentObject var settings: SettingsModel
    @Binding var selectedTab: TabSelection
    @EnvironmentObject var ocrManager: OCRManager
    @Binding var isEditingPastDictation: Bool
    let onNavigateToText: (Bool) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPermissionAlert = false
    @State private var showLimitedAccessMessage = false
    @State private var showCameraPermissionAlert = false
    @State private var showCameraUnavailableAlert = false
    @State private var showCamera = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Photo Selection and Camera Buttons
                    HStack(spacing: 20) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Label("Select Image 選擇圖片", systemImage: "photo")
                                .font(.title2)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .onTapGesture {
                            checkPhotoLibraryPermission()
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

                        Button(action: {
                            checkCameraPermission()
                        }) {
                            Label("Take Photo 拍照", systemImage: "camera")
                                .font(.title2)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
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

                    // Past Dictations Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Past Dictation 過去文章")
                            .font(.headline)
                            .padding(.horizontal)

                        if settings.pastDictations.isEmpty {
                            Text("No past dictations 沒有過去文章")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(settings.pastDictations) { entry in
                                Button(action: {
                                    settings.editingDictationId = entry.id
                                    settings.extractedText = entry.text
                                    isEditingPastDictation = true
                                    onNavigateToText(true)

                                    #if DEBUG
                                    print("ScanTabView - Selected entry for editing: \(entry.id)")
                                    print("ScanTabView - Set editingDictationId: \(String(describing: settings.editingDictationId))")
                                    #endif
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(entry.date, style: .date)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)

                                            let sentences = entry.text.splitIntoSentences()
                                            let preview = sentences.isEmpty ? String(entry.text.prefix(50)) : sentences[0]
                                            Text(preview.count > 50 ? String(preview.prefix(50)) + "..." : preview)
                                                .font(.body)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .shadow(radius: 1)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        settings.deletePastDictation(id: entry.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Scan 掃描")
            // Present the camera UI using Cursor's ImagePicker
            .sheet(isPresented: $showCamera) {
                ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
            }
            // Photo Library Permission Alerts
            .alert("Photo Library Access Denied 無法訪問照片庫", isPresented: $showPermissionAlert) {
                Button("Go to Settings 前往設置", role: .none) {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel 取消", role: .cancel) { }
            } message: {
                Text("Please grant photo library access in Settings to scan images. 請在設置中授予照片庫訪問權限以掃描圖片。")
            }
            .alert("Limited Photo Access 照片訪問受限", isPresented: $showLimitedAccessMessage) {
                Button("Select More Photos 選擇更多照片", role: .none) {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Continue 繼續", role: .cancel) { }
            } message: {
                Text("You have limited photo access. Select more photos to scan, or continue with the current selection. 您已限制照片訪問。選擇更多照片進行掃描，或繼續使用當前選擇。")
            }
            // Camera Permission Alert
            .alert("Camera Access Denied 相機訪問被拒絕", isPresented: $showCameraPermissionAlert) {
                Button("Go to Settings 前往設置", role: .none) {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel 取消", role: .cancel) { }
            } message: {
                Text("Please enable camera access in Settings to take photos. 請在設置中啟用相機訪問以拍攝照片。")
            }
            // Camera Unavailable Alert
            .alert("Camera Unavailable 相機不可用", isPresented: $showCameraUnavailableAlert) {
                Button("OK 確定", role: .cancel) { }
            } message: {
                Text("The camera is not available on this device. 該設備上相機不可用。")
            }
            // General Error Alert
            .alert("Error 錯誤", isPresented: $showError) {
                Button("OK 確定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized:
            // Full access granted, proceed
            showLimitedAccessMessage = false
        case .limited:
            // Limited access granted, show message to select more photos
            showLimitedAccessMessage = true
        case .denied, .restricted:
            // Access denied or restricted, show alert
            showPermissionAlert = true
        case .notDetermined:
            // Request permission
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    switch newStatus {
                    case .authorized:
                        showLimitedAccessMessage = false
                    case .limited:
                        showLimitedAccessMessage = true
                    case .denied, .restricted:
                        showPermissionAlert = true
                    default:
                        showPermissionAlert = true
                    }
                }
            }
        @unknown default:
            showPermissionAlert = true
        }
    }

    private func checkCameraPermission() {
        // Check if camera is available on the device
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            showCameraUnavailableAlert = true
            return
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            // Camera access granted, show the camera UI
            showCamera = true
        case .denied, .restricted:
            // Camera access denied or restricted, show alert
            showCameraPermissionAlert = true
        case .notDetermined:
            // Request camera permission
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.showCamera = true
                    } else {
                        self.showCameraPermissionAlert = true
                    }
                }
            }
        @unknown default:
            showCameraPermissionAlert = true
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
                settings.extractedText = ocrManager.extractedText
                settings.savePastDictation(text: settings.extractedText)
                isEditingPastDictation = false
                onNavigateToText(true)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isProcessing = false
        }
    }
    #else
    // Fallback for platforms without UIKit (e.g., macOS)
    var body: some View {
        NavigationView {
            Text("Scan feature is only available on iOS devices. 掃描功能僅在 iOS 設備上可用。")
                .padding()
                .navigationTitle("Scan 掃描")
        }
    }
    #endif
}

#Preview {
    ScanTabView(
        selectedTab: .constant(.scan),
        isEditingPastDictation: .constant(false),
        onNavigateToText: { _ in }
    )
    .environmentObject(SettingsModel())
    .environmentObject(OCRManager())
}
