import Cocoa
import Vision

// https://developer.apple.com/documentation/vision/vnrecognizetextrequest

func main(args: [String]) -> Int32 {
    guard CommandLine.arguments.count == 2 else {
        fputs(String(format: "usage: %1$@ image\n", CommandLine.arguments[0]), stderr)
        return 1
    }

    // Flag ideas:
    // --version
    // Print REVISION
    // --langs
    // guard let langs = VNRecognizeTextRequest.supportedRecognitionLanguages(for: .accurate, revision: REVISION)
    // --fast (default accurate)
    // --fix (default no language correction)

    // let (src, dst) = (args[1], args[2])
    let src = args[1]

    guard let img = NSImage(byReferencingFile: src) else {
        fputs("Error: failed to load image '\(src)'\n", stderr)
        return 1
    }

    guard let imgRef = img.cgImage(forProposedRect: &img.alignmentRect, context: nil, hints: nil) else {
        fputs("Error: failed to convert NSImage to CGImage for '\(src)'\n", stderr)
        return 1
    }


    let request = VNRecognizeTextRequest { (request, error) in
        let observations = request.results as? [VNRecognizedTextObservation] ?? []

        // for each observation, generate a one-line json with bounding box (4 corners in array of pixel points), text, and confidence
        let obs = observations.map { (obs) -> String in
            let text = obs.topCandidates(1).first?.string ?? ""
            let confidence = obs.topCandidates(1).first?.confidence ?? 0
            let rect = obs.boundingBox
            let corners = [
                [rect.minX, 1 - rect.maxY],
                [rect.maxX, 1 - rect.maxY],
                [rect.maxX, 1 - rect.minY],
                [rect.minX, 1 - rect.minY]
            ]
            // convert corners into integer pixel points
            let cornersInPixel = corners.map { (point) -> [Int] in
                let x = Int(point[0] * CGFloat(imgRef.width))
                let y = Int(point[1] * CGFloat(imgRef.height))
                return [x, y]
            }
            let json = "{\"text\": \"\(text)\", \"confidence\": \(confidence), \"corners\": \(cornersInPixel)}"
            return json
        }

        // try? obs.joined(separator: "\n").write(to: URL(fileURLWithPath: dst), atomically: true, encoding: String.Encoding.utf8)

        // output json array to stdout
        print("[\(obs.joined(separator: ","))]")
    }
    request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
    request.usesLanguageCorrection = true
    // request.revision = REVISION
    request.revision = 2
    request.recognitionLanguages = ["zh-Hans", "en-US"]
    request.usesCPUOnly = false
    request.minimumTextHeight = 0.01 // <20px over 1920px
    //request.customWords = [String]

    try? VNImageRequestHandler(cgImage: imgRef, options: [:]).perform([request])

    return 0
}
exit(main(args: CommandLine.arguments))
