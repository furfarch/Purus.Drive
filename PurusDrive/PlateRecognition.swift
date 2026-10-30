import Foundation
import Vision
import UIKit

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
                print("PlateRecognizer: text request failed: \(err)")
            }
            let observations = (req.results as? [VNRecognizedTextObservation]) ?? []

            let candidateTuples: [(string: String, confidence: Float)] = observations.flatMap { obs in
                obs.topCandidates(5).map { ($0.string, $0.confidence) }
            }

            // Generate multiple normalized variants per candidate and score them.
            var scored: [(plate: String, score: Double)] = []
            for (raw, conf) in candidateTuples {
                for (variant, substitutions) in normalizeVariants(raw) {
                    // each OCR-confusion swap is a guess; without this "AG 1234" loses to "A61234"
                    let s = scorePlateCandidate(variant, baseConfidence: Double(conf)) - Double(substitutions) * 6
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

        // camera photos are usually stored rotated (.right); Vision needs the orientation to read them upright
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        if let cgImage = image.cgImage {
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) } catch {
                    print("PlateRecognizer: perform failed: \(error)")
                    DispatchQueue.main.async { completion(.init(rawCandidates: [], bestMatch: nil)) }
                }
            }
            return
        }

        if let ci = CIImage(image: image) {
            let handler = VNImageRequestHandler(ciImage: ci, orientation: orientation, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) } catch {
                    print("PlateRecognizer: perform failed (CIImage): \(error)")
                    DispatchQueue.main.async { completion(.init(rawCandidates: [], bestMatch: nil)) }
                }
            }
            return
        }

        print("PlateRecognizer: cannot create CGImage or CIImage from UIImage")
        DispatchQueue.main.async { completion(.init(rawCandidates: [], bestMatch: nil)) }
    }

    // MARK: - Normalization & scoring

    /// Produces multiple variants because different mappings help for different OCR mistakes.
    /// Each variant comes with the number of characters that were substituted.
    static func normalizeVariants(_ text: String) -> [(String, Int)] {
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
        if v0.isEmpty { return [] }
        // text that already reads as a plate is taken as is
        if isPlateLike(v0) { return [(v0, 0)] }
        let v1 = map(filtered, table: letterToDigit)
        let v2 = map(filtered, table: digitToLetter)

        func changes(_ v: String) -> Int { zip(v0, v).filter { $0 != $1 }.count }

        // De-duplicate while preserving order.
        var seen = Set<String>()
        var out: [(String, Int)] = []
        for v in [v0, v1, v2] {
            if !v.isEmpty && !seen.contains(v) {
                seen.insert(v)
                out.append((v, changes(v)))
            }
        }
        return out
    }

    /// Scoring prefers realistic plates:
    /// - must contain digits
    /// - prefers letter+digit mixture
    /// - prefers patterns like "BE56789" instead of english words like "EDIT".
    static func scorePlateCandidate(_ plate: String, baseConfidence: Double) -> Double {
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

}

private extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
