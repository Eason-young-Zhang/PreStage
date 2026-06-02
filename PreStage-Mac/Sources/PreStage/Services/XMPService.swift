import Foundation

struct XMPValues {
    var rating: Int?
    var colorLabel: ColorLabel?
    var pickState: PickState?
}

enum XMPServiceError: LocalizedError {
    case cannotParseExistingSidecar(URL)
    case missingWritableDescription(URL)

    var errorDescription: String? {
        switch self {
        case .cannotParseExistingSidecar(let url):
            "Could not parse existing XMP sidecar at \(url.path)."
        case .missingWritableDescription(let url):
            "Could not find a writable XMP description in \(url.path)."
        }
    }
}

struct XMPService {
    func applySidecarMetadata(to item: MediaItem) -> MediaItem {
        var updated = item
        let sidecarURL = xmpSidecarURL(for: item.url)
        guard FileManager.default.fileExists(atPath: sidecarURL.path) else {
            return updated
        }
        guard let values = readSidecar(for: item.url) else {
            updated.xmpStatus = .conflict
            return updated
        }

        if let rating = values.rating {
            updated.rating = max(0, min(5, rating))
        }
        if let colorLabel = values.colorLabel {
            updated.colorLabel = colorLabel
        }
        if let pickState = values.pickState {
            updated.pickState = pickState
        }
        updated.xmpStatus = .sidecarFound
        return updated
    }

    func writeSidecar(for item: MediaItem) throws {
        let sidecarURL = xmpSidecarURL(for: item.url)
        if FileManager.default.fileExists(atPath: sidecarURL.path) {
            guard let document = try? XMLDocument(contentsOf: sidecarURL) else {
                throw XMPServiceError.cannotParseExistingSidecar(sidecarURL)
            }
            guard let description = firstDescriptionElement(in: document.rootElement()) else {
                throw XMPServiceError.missingWritableDescription(sidecarURL)
            }
            applyPreStageAttributes(to: description, item: item, preserveExistingCreatorTool: true)
            let data = document.xmlData(options: [.nodePrettyPrint])
            try data.write(to: sidecarURL, options: .atomic)
            return
        }

        try newSidecarXML(for: item).write(to: sidecarURL, atomically: true, encoding: .utf8)
    }

    private func newSidecarXML(for item: MediaItem) -> String {
        let label = item.colorLabel?.xmpLabelName ?? ""
        let pickState = item.pickState.rawValue
        let escapedFilename = item.filename.xmlEscaped
        return """
        <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description rdf:about="\(escapedFilename)"
              xmlns:xmp="http://ns.adobe.com/xap/1.0/"
              xmlns:photoshop="http://ns.adobe.com/photoshop/1.0/"
              xmlns:prestage="https://local.codex/prestage/1.0/"
              xmp:CreatorTool="PreStage"
              xmp:Rating="\(item.rating)"
              xmp:Label="\(label.xmlEscaped)"
              photoshop:Urgency="\(photoshopUrgency(for: item.colorLabel))"
              prestage:PickState="\(pickState)" />
          </rdf:RDF>
        </x:xmpmeta>
        <?xpacket end="w"?>
        """
    }

    private func readSidecar(for mediaURL: URL) -> XMPValues? {
        let sidecarURL = xmpSidecarURL(for: mediaURL)
        guard let document = try? XMLDocument(contentsOf: sidecarURL) else { return nil }
        var values = XMPValues()
        collectValues(from: document.rootElement(), values: &values)
        return values
    }

    private func collectValues(from element: XMLElement?, values: inout XMPValues) {
        guard let element else { return }
        for attribute in element.attributes ?? [] {
            switch normalizedName(attribute.name) {
            case "Rating":
                applyRatingValue(attribute.stringValue, to: &values)
            case "Label":
                values.colorLabel = ColorLabel(displayName: attribute.stringValue ?? "")
            case "PickState":
                values.pickState = PickState(rawValue: attribute.stringValue ?? "")
            default:
                break
            }
        }

        if isLeafTextElement(element), let text = element.stringValue {
            switch normalizedName(element.name ?? element.localName) {
            case "Rating":
                applyRatingValue(text, to: &values)
            case "Label":
                values.colorLabel = ColorLabel(displayName: text)
            case "PickState":
                values.pickState = PickState(rawValue: text)
            default:
                break
            }
        }

        for child in element.children ?? [] {
            collectValues(from: child as? XMLElement, values: &values)
        }
    }

    private func normalizedName(_ rawName: String?) -> String {
        guard let rawName else { return "" }
        let local = rawName.split(separator: ":").last.map(String.init) ?? rawName
        switch local {
        case "Rating":
            return "Rating"
        case "Label":
            return "Label"
        case "PickState":
            return "PickState"
        default:
            return local
        }
    }

    private func isLeafTextElement(_ element: XMLElement) -> Bool {
        guard let children = element.children, !children.isEmpty else { return false }
        return !children.contains { $0 is XMLElement }
    }

    private func applyRatingValue(_ rawValue: String?, to values: inout XMPValues) {
        guard let rating = Int((rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        if rating == -1 {
            values.rating = 0
            if values.pickState == nil {
                values.pickState = .rejected
            }
        } else {
            values.rating = rating
        }
    }

    private func firstDescriptionElement(in element: XMLElement?) -> XMLElement? {
        guard let element else { return nil }
        if element.name == "rdf:Description" || element.localName == "Description" || element.name == "Description" {
            return element
        }

        for child in element.children ?? [] {
            if let match = firstDescriptionElement(in: child as? XMLElement) {
                return match
            }
        }
        return nil
    }

    private func applyPreStageAttributes(to element: XMLElement, item: MediaItem, preserveExistingCreatorTool: Bool) {
        setAttribute("xmlns:xmp", value: "http://ns.adobe.com/xap/1.0/", on: element)
        setAttribute("xmlns:photoshop", value: "http://ns.adobe.com/photoshop/1.0/", on: element)
        setAttribute("xmlns:prestage", value: "https://local.codex/prestage/1.0/", on: element)
        if !preserveExistingCreatorTool || element.attribute(forName: "xmp:CreatorTool") == nil {
            setAttribute("xmp:CreatorTool", value: "PreStage", on: element)
        }
        setAttribute("xmp:Rating", value: "\(item.rating)", on: element)
        setAttribute("xmp:Label", value: item.colorLabel?.xmpLabelName ?? "", on: element)
        setAttribute("photoshop:Urgency", value: "\(photoshopUrgency(for: item.colorLabel))", on: element)
        setAttribute("prestage:PickState", value: item.pickState.rawValue, on: element)
        element.removeAttribute(forName: "photocopy:PickState")
    }

    private func setAttribute(_ name: String, value: String, on element: XMLElement) {
        if let attribute = element.attribute(forName: name) {
            attribute.stringValue = value
        } else {
            element.addAttribute(XMLNode.attribute(withName: name, stringValue: value) as! XMLNode)
        }
    }

    private func xmpSidecarURL(for mediaURL: URL) -> URL {
        mediaURL.deletingPathExtension().appendingPathExtension("xmp")
    }

    private func photoshopUrgency(for label: ColorLabel?) -> Int {
        switch label {
        case .red: 1
        case .yellow: 2
        case .green: 3
        case .blue: 4
        case .purple: 5
        case .none: 0
        }
    }
}

private extension ColorLabel {
    var xmpLabelName: String {
        switch self {
        case .red: "Red"
        case .yellow: "Yellow"
        case .green: "Green"
        case .blue: "Blue"
        case .purple: "Purple"
        }
    }

    init?(displayName: String) {
        let normalized = displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "red", "红色":
            self = .red
        case "yellow", "黄色":
            self = .yellow
        case "green", "绿色":
            self = .green
        case "blue", "蓝色":
            self = .blue
        case "purple", "紫色":
            self = .purple
        default:
            self.init(rawValue: normalized)
        }
    }
}

private extension String {
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
