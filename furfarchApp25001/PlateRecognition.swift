import Foundation
import Vision
import UIKit
import AVFoundation

struct PlateRecognitionResult {
    let rawCandidates: [String]
    let bestMatch: String?
}

enum PlateRecognizer {
    // Broad EU-style: 2–3 letters + optional 1–2 letters + 1–6 digits, allowing optional hyphen.
    // We validate after normalization (spaces removed, uppercase).
    private static let broadRegex = try! NSRegularExpression(pattern: "^[A-Z]{1,4}-?[0-9]{1,7}$|^[A-Z]{1,3}[0-9]{1,7}[A-Z]{0,2}$", options: [])

    static func recognize(from image: UIImage, completion: @escaping (PlateRecognitionResult) -> Void) {
        let request = VNRecognizeTextRequest { req, err in
            if let err = err {
                print("DEBUG: VNRecognizeTextRequest error: \(err)")
            }
            let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
            print("DEBUG: PlateRecognizer found observations: \(observations.count)")

            let candidateTuples: [(string: String, confidence: Float)] = observations.flatMap { obs in
                obs.topCandidates(5).map { ($0.string, $0.confidence) }
            }
            print("DEBUG: PlateRecognizer raw candidates: \(candidateTuples.map { "\($0.string) (\($0.confidence))" })")

            // Generate multiple normalized variants per candidate and score them.
            var scored: [(plate: String, score: Double)] = []
            for (raw, conf) in candidateTuples {
                for variant in normalizeVariants(raw) {
                    let s = scorePlateCandidate(variant, baseConfidence: Double(conf))
                    scored.append((variant, s))
                }
            }

            // Deduplicate by keeping max score per string
            var bestByString: [String: Double] = [:]
            for (p, s) in scored {
                bestByString[p] = max(bestByString[p] ?? -Double.infinity, s)
            }

            let all = bestByString
                .sorted(by: { $0.value > $1.value })
                .map { $0.key }

            let best = bestByString
                .filter { isPlateLike($0.key) }
                .max(by: { $0.value < $1.value })?.key

            DispatchQueue.main.async {
                completion(.init(rawCandidates: all, bestMatch: best))
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "en-GB", "de-DE", "fr-FR", "it-IT", "nl-NL"]

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

        print("DEBUG: PlateRecognizer cannot create CGImage or CIImage from UIImage")
        DispatchQueue.main.async { completion(.init(rawCandidates: [], bestMatch: nil)) }
    }

    static func recognize(from cgImage: CGImage, completion: @escaping (PlateRecognitionResult) -> Void) {
        let uiImage = UIImage(cgImage: cgImage)
        recognize(from: uiImage, completion: completion)
    }

    static func recognize(from ciImage: CIImage, completion: @escaping (PlateRecognitionResult) -> Void) {
        let context = CIContext(options: nil)
        if let cg = context.createCGImage(ciImage, from: ciImage.extent) {
            recognize(from: cg, completion: completion)
        } else {
            DispatchQueue.main.async { completion(.init(rawCandidates: [], bestMatch: nil)) }
        }
    }

    static func recognize(from pixelBuffer: CVPixelBuffer, completion: @escaping (PlateRecognitionResult) -> Void) {
        let request = VNRecognizeTextRequest { req, err in
            if let err = err { print("DEBUG: VNRecognizeTextRequest error: \(err)") }
            let observations = (req.results as? [VNRecognizedTextObservation]) ?? []

            let candidateTuples: [(string: String, confidence: Float)] = observations.flatMap { obs in
                obs.topCandidates(5).map { ($0.string, $0.confidence) }
            }

            var scored: [(plate: String, score: Double)] = []
            for (raw, conf) in candidateTuples {
                for variant in normalizeVariants(raw) {
                    scored.append((variant, scorePlateCandidate(variant, baseConfidence: Double(conf))))
                }
            }

            var bestByString: [String: Double] = [:]
            for (p, s) in scored { bestByString[p] = max(bestByString[p] ?? -Double.infinity, s) }

            let all = bestByString.sorted(by: { $0.value > $1.value }).map { $0.key }
            let best = bestByString.filter { isPlateLike($0.key) }.max(by: { $0.value < $1.value })?.key
            DispatchQueue.main.async { completion(.init(rawCandidates: all, bestMatch: best)) }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "en-GB", "de-DE", "fr-FR", "it-IT", "nl-NL"]

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do { try handler.perform([request]) } catch {
                print("DEBUG: VNImageRequestHandler.perform failed (pixelBuffer): \(error)")
                DispatchQueue.main.async { completion(.init(rawCandidates: [], bestMatch: nil)) }
            }
        }
    }

    static func recognize(from sampleBuffer: CMSampleBuffer, completion: @escaping (PlateRecognitionResult) -> Void) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            DispatchQueue.main.async { completion(.init(rawCandidates: [], bestMatch: nil)) }
            return
        }
        recognize(from: pixelBuffer, completion: completion)
    }

    // MARK: - Normalization & scoring

    /// Produces multiple variants because different mappings help for different OCR mistakes.
    private static func normalizeVariants(_ text: String) -> [String] {
        let upper = text.uppercased()

        // Keep only letters/digits and hyphen, drop spaces and punctuation.
        let filtered = upper.filter { ch in
            ch.isNumber || (ch >= "A" && ch <= "Z") || ch == "-"
        }

        // Common OCR confusions for plates.
        // We'll produce two variants: one letter->digit heavy, one digit->letter heavy.
        let letterToDigit: [Character: Character] = [
            "O": "0",
            "I": "1",
            "L": "1",
            "S": "5",
            "B": "8",
            "Z": "2",
            "G": "6",
            "D": "0",
            "T": "7"
        ]
        let digitToLetter: [Character: Character] = [
            "0": "O",
            "1": "I",
            "2": "Z",
            "5": "S",
            "6": "G",
            "8": "B",
            "7": "T"
        ]

        func map(_ input: String, table: [Character: Character]) -> String {
            String(input.map { table[$0] ?? $0 })
        }

        let v0 = filtered
        let v1 = map(filtered, table: letterToDigit)
        let v2 = map(filtered, table: digitToLetter)

        // De-duplicate while preserving order.
        var seen = Set<String>()
        var out: [String] = []
        for v in [v0, v1, v2] {
            if !v.isEmpty && !seen.contains(v) {
                seen.insert(v)
                out.append(v)
            }
        }
        return out
    }

    /// Scoring prefers realistic plates:
    /// - must contain digits
    /// - prefers letter+digit mixture
    /// - prefers patterns like "BE56789" instead of english words like "EDIT".
    private static func scorePlateCandidate(_ plate: String, baseConfidence: Double) -> Double {
        // Base confidence from Vision (0..1). Convert to 0..100 to make penalties easier.
        var score = baseConfidence * 100.0

        let letters = plate.filter { $0 >= "A" && $0 <= "Z" }.count
        let digits = plate.filter { $0.isNumber }.count

        // Hard penalties for obviously non-plate candidates
        if digits == 0 { score -= 80 }               // words like EDIT
        if letters == 0 { score -= 30 }              // all digits sometimes ok, but less likely for EU

        // Prefer mixed alnum
        score += Double(min(letters, 4)) * 4.0
        score += Double(min(digits, 7)) * 5.0

        // Prefer common EU / CH pattern: starts with letters and ends with digits.
        if plate.first?.isLetter == true && plate.last?.isNumber == true {
            score += 20
        }

        // Penalize if it looks like an english word (all letters, short)
        if digits == 0 && letters >= 3 { score -= 50 }

        // Small penalty for too short/too long
        if plate.count < 4 { score -= 20 }
        if plate.count > 10 { score -= 10 }

        return score
    }

    private static func isPlateLike(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return broadRegex.firstMatch(in: text, options: [], range: range) != nil
    }

    #if canImport(UIKit)
    /// Captures a snapshot of the key window/screen and runs recognition on it.
    static func recognizeFromScreen(completion: @escaping (PlateRecognitionResult) -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let window = windowScene.keyWindow ?? windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first
        else {
            print("DEBUG: No key window available for screen snapshot")
            completion(.init(rawCandidates: [], bestMatch: nil))
            return
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { ctx in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        recognize(from: image, completion: completion)
    }
    #endif
}
