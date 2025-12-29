import Foundation
import Vision
import UIKit

struct PlateRecognitionResult {
    let rawCandidates: [String]
    let bestMatch: String?
}

enum PlateRecognizer {
    // Adjust regex to your region's plate format as needed
    private static let plateRegex = try! NSRegularExpression(pattern: "^[A-Z0-9\\-]{5,8}$", options: [])

    static func recognize(from image: UIImage, completion: @escaping (PlateRecognitionResult) -> Void) {
        // Prepare a VNImageRequestHandler using cgImage if available, otherwise fall back to CIImage
        let request = VNRecognizeTextRequest { req, err in
            if let err = err {
                print("DEBUG: VNRecognizeTextRequest error: \(err)")
            }
            let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
            print("DEBUG: PlateRecognizer found observations: \(observations.count)")
            let candidates = observations.compactMap { $0.topCandidates(1).first?.string }
            print("DEBUG: PlateRecognizer raw candidates: \(candidates)")

            let normalized = candidates.map { normalizePlateCandidate($0) }
            let best = normalized.first(where: { isPlateLike($0) })

            DispatchQueue.main.async {
                completion(.init(rawCandidates: normalized, bestMatch: best))
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        // Try cgImage first
        if let cgImage = image.cgImage {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) } catch {
                    print("DEBUG: VNImageRequestHandler.perform failed: \(error)")
                    DispatchQueue.main.async { completion(.init(rawCandidates: [], bestMatch: nil)) }
                }
            }
            return
        }

        // Fallback to CIImage
        if let ci = CIImage(image: image) {
            let handler = VNImageRequestHandler(ciImage: ci, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) } catch {
                    print("DEBUG: VNImageRequestHandler.perform failed (CIImage): \(error)")
                    DispatchQueue.main.async { completion(.init(rawCandidates: [], bestMatch: nil)) }
                }
            }
            return
        }

        // Can't create image buffer
        print("DEBUG: PlateRecognizer cannot create CGImage or CIImage from UIImage")
        DispatchQueue.main.async { completion(.init(rawCandidates: [], bestMatch: nil)) }
    }

    private static func normalizePlateCandidate(_ text: String) -> String {
        var t = text.uppercased()
        t = t.replacingOccurrences(of: " ", with: "")
        t = t.replacingOccurrences(of: "·", with: "")
        t = t.replacingOccurrences(of: "—", with: "-")
        t = t.replacingOccurrences(of: "–", with: "-")
        t = t.replacingOccurrences(of: "—", with: "-")

        t = t.map { ch -> Character in
            switch ch {
            case "O": return "0"
            case "I": return "1"
            case "S": return "5"
            case "B": return "8"
            default:  return ch
            }
        }.reduce(into: "", { $0.append($1) })

        return t
    }

    private static func isPlateLike(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return plateRegex.firstMatch(in: text, options: [], range: range) != nil
    }
}
