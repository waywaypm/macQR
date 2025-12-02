import SwiftUI
import Vision
import AppKit

// 移除类级别的@MainActor，改为在需要的方法上使用@MainActor标记
class QRCodeScanner: ObservableObject, @unchecked Sendable {
    @Published var qrCodeContent: [String] = []
    
    func scanQRCode(from image: NSImage) async -> [String]? {
        return await withCheckedContinuation { continuation in
            scanQRCode(from: image) { content in
                continuation.resume(returning: content)
            }
        }
    }
    
    private func scanQRCode(from image: NSImage, completion: @escaping ([String]?) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(nil)
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        
        let request = VNDetectBarcodesRequest { request, error in
            guard let results = request.results as? [VNBarcodeObservation], error == nil else {
                completion(nil)
                return
            }
            
            var qrCodeResults: [String] = []
            
            for result in results {
                if result.symbology == .qr { // 只处理二维码
                    if let payload = result.payloadStringValue {
                        qrCodeResults.append(payload)
                    }
                }
            }
            
            if qrCodeResults.isEmpty {
                completion(nil)
            } else {
                completion(qrCodeResults)
            }
        }
        
        do {
            try requestHandler.perform([request])
        } catch {
            completion(nil)
        }
    }
}