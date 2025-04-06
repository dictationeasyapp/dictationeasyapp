import SwiftUI
import Vision

#if os(iOS)
import UIKit
#endif

@MainActor
class OCRManager: ObservableObject {
    enum OCRError: Error {
        case invalidImage
        case recognitionFailed
    }

    @Published var extractedText: String = ""
    @Published var isProcessing: Bool = false
    @Published var error: String?

    private let supportedLanguages = ["en-US", "zh-Hant"]

    func processImage(_ image: UIImage) async throws {
        isProcessing = true
        error = nil

        guard let cgImage = image.cgImage else {
            error = "Failed to process image 無法處理圖片"
            isProcessing = false
            throw OCRError.invalidImage
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }

            if let error = error {
                Task { @MainActor in
                    self.error = error.localizedDescription
                    self.isProcessing = false
                }
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                Task { @MainActor in
                    self.error = "No text found in image 圖片中未找到文字"
                    self.isProcessing = false
                }
                return
            }

            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")

            Task { @MainActor in
                self.extractedText = self.cleanText(recognizedText)
                self.isProcessing = false
            }
        }

        request.recognitionLanguages = supportedLanguages
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        do {
            try requestHandler.perform([request])
        } catch {
            self.error = error.localizedDescription
            self.isProcessing = false
            throw error
        }
    }

    private func cleanText(_ text: String) -> String {
        let chineseRegex = try! NSRegularExpression(pattern: "[\\u4e00-\\u9fff]+")
        let range = NSRange(text.startIndex..., in: text)
        let matches = chineseRegex.matches(in: text, range: range)

        var cleanedText = text

        if !matches.isEmpty {
            cleanedText = text.components(separatedBy: .whitespacesAndNewlines)
                .filter { component in
                    let componentRange = NSRange(component.startIndex..., in: component)
                    return chineseRegex.firstMatch(in: component, range: componentRange) != nil ||
                           component.rangeOfCharacter(from: .punctuationCharacters) != nil
                }
                .joined(separator: " ")
        }

        return cleanedText.components(separatedBy: CharacterSet(charactersIn: ".!?。！？"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ".\n")
    }
}
