import SwiftDocC


extension RenderNode {
    func renderAsMarkdown() -> String {
        var md = ""

        if let title = metadata.title {
            md += "# \(title)\n\n"
        }

        if let roleHeading = metadata.roleHeading {
            md += roleHeading + "\n\n"
        }

        if let platforms = metadata.platforms, !platforms.isEmpty {
            md += renderAvailability(platforms) + "\n\n"
        }

        if let abstract = abstract {
            md += renderInlineContent(abstract) + "\n\n"
        }

        for section in primaryContentSections {
            if let contentSection = section as? ContentRenderSection {
                md += renderBlockContent(contentSection.content)
            }
        }

        if !topicSections.isEmpty {
            md += renderTopics(topicSections, references: references)
        }

        if !seeAlsoSections.isEmpty {
            md += renderSeeAlso(seeAlsoSections, references: references)
        }

        if !relationshipSections.isEmpty {
            md += renderRelationships(relationshipSections, references: references)
        }

        return md
    }

    private func renderRelationships(_ sections: [RelationshipsRenderSection], references: [String: any RenderReference]) -> String {
        var md = "## Relationships\n\n"

        for section in sections {
            md += "### \(section.title)\n\n"
            for identifier in section.identifiers {
                if let ref = references[identifier] as? TopicRenderReference {
                    md += "- [\(ref.title)](\(ref.url))\n"
                } else {
                    let name = identifier.split(separator: "/").last.map(String.init) ?? identifier
                    md += "- \(name)\n"
                }
            }
            md += "\n"
        }

        return md
    }

    private func renderTopics(_ sections: [TaskGroupRenderSection], references: [String: any RenderReference]) -> String {
        var md = "## Topics\n\n"

        for section in sections {
            if let title = section.title {
                md += "### \(title)\n\n"
            }

            for identifier in section.identifiers {
                if let ref = references[identifier] as? TopicRenderReference {
                    md += "- [\(ref.title)](\(ref.url))\n"
                } else {
                    md += "- \(identifier)\n"
                }
            }
            md += "\n"
        }

        return md
    }

    private func renderSeeAlso(_ sections: [TaskGroupRenderSection], references: [String: any RenderReference]) -> String {
        var md = "## See Also\n\n"

        for section in sections {
            if let title = section.title {
                md += "### \(title)\n\n"
            }

            for identifier in section.identifiers {
                if let ref = references[identifier] as? TopicRenderReference {
                    md += "- [\(ref.title)](\(ref.url))\n"
                } else {
                    md += "- \(identifier)\n"
                }
            }
            md += "\n"
        }

        return md
    }

    private func renderAvailability(_ platforms: [AvailabilityRenderItem]) -> String {
        let availabilities = platforms.compactMap { platform -> String? in
            guard let name = platform.name, let version = platform.introduced else { return nil }
            var str = "\(name) \(version)+"
            if let deprecated = platform.deprecated {
                str += " (deprecated: \(deprecated))"
            }
            return str
        }
        return availabilities.joined(separator: " | ")
    }

    private func renderBlockContent(_ items: [RenderBlockContent]) -> String {
        var md = ""
        for item in items {
            md += renderBlockItem(item)
        }
        return md
    }

    private func renderBlockItem(_ item: RenderBlockContent) -> String {
        switch item {
        case .heading(let heading):
            let prefix = String(repeating: "#", count: heading.level)
            return "\(prefix) \(heading.text)\n\n"
        case .paragraph(let paragraph):
            return renderInlineContent(paragraph.inlineContent) + "\n\n"
        case .aside(let aside):
            let content = renderBlockContent(aside.content)
            let style = aside.style.rawValue
            return "> **\(style.capitalized)**: \(content.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
        case .unorderedList(let list):
            return renderUnorderedList(list.items)
        case .orderedList(let list):
            return renderOrderedList(list.items)
        case .codeListing(let listing):
            let code = listing.code.joined(separator: "\n")
            let lang = listing.syntax ?? ""
            return "```\(lang)\n\(code)\n```\n\n"
        case .termList(let termList):
            return renderTermList(termList.items)
        case .table(let table):
            return renderTable(table)
        case .small(let small):
            return "<small>\(renderInlineContent(small.inlineContent))</small>\n\n"
        case .thematicBreak:
            return "---\n\n"
        case .row(let row):
            var md = ""
            for column in row.columns {
                md += renderBlockContent(column.content)
            }
            return md
        case .links(let links):
            var md = ""
            for item in links.items {
                md += "- \(item)\n"
            }
            return md + "\n"
        case .video(let video):
            return "![](\(video.identifier.identifier))\n\n"
        case .step, .endpointExample, .dictionaryExample, .tabNavigator, ._nonfrozenEnum_useDefaultCase:
            return ""
        }
    }

    private func renderUnorderedList(_ items: [RenderBlockContent.ListItem]) -> String {
        var md = ""
        for item in items {
            let content = renderBlockContent(item.content)
            let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
            md += "- \(text)\n"
        }
        return md + "\n"
    }

    private func renderOrderedList(_ items: [RenderBlockContent.ListItem]) -> String {
        var md = ""
        for (index, item) in items.enumerated() {
            let content = renderBlockContent(item.content)
            let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
            md += "\(index + 1). \(text)\n"
        }
        return md + "\n"
    }

    private func renderTermList(_ items: [RenderBlockContent.TermListItem]) -> String {
        var md = ""
        for item in items {
            let term = renderInlineContent(item.term.inlineContent)
            md += "**\(term)**\n"
            let definition = renderBlockContent(item.definition.content)
            md += ": \(definition.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
        }
        return md
    }

    private func renderTable(_ table: RenderBlockContent.Table) -> String {
        var md = ""
        let header = table.header == .both || table.header == .row

        for (rowIndex, row) in table.rows.enumerated() {
            let cells = row.cells.map { cell in
                renderBlockContent(cell).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            md += "| " + cells.joined(separator: " | ") + " |\n"

            if rowIndex == 0 && header {
                md += "|" + cells.map { _ in " --- " }.joined(separator: "|") + "|\n"
            }
        }
        return md + "\n"
    }

    private func renderInlineContent(_ items: [RenderInlineContent]) -> String {
        var result = ""
        for item in items {
            switch item {
            case .text(let text):
                result += text
            case .codeVoice(let code):
                result += "`\(code)`"
            case .reference(let identifier, _, let overridingTitle, _):
                let title = overridingTitle ?? identifier.identifier
                if title == identifier.identifier {
                    result += "<\(identifier.identifier)>"
                } else {
                    result += "[\(title)](\(identifier.identifier))"
                }
            case .emphasis(let inlineContent):
                let inner = renderInlineContent(inlineContent)
                result += "*\(inner)*"
            case .strong(let inlineContent):
                let inner = renderInlineContent(inlineContent)
                result += "**\(inner)**"
            case .image(let identifier, _):
                result += "![](\(identifier.identifier))"
            case .newTerm(let inlineContent):
                let inner = renderInlineContent(inlineContent)
                result += "_\(inner)_"
            case .subscript(let inlineContent):
                let inner = renderInlineContent(inlineContent)
                result += "<sub>\(inner)</sub>"
            case .superscript(let inlineContent):
                let inner = renderInlineContent(inlineContent)
                result += "<sup>\(inner)</sup>"
            case .strikethrough(let inlineContent):
                let inner = renderInlineContent(inlineContent)
                result += "~~\(inner)~~"
            case .inlineHead(let inlineContent):
                let inner = renderInlineContent(inlineContent)
                result += "**\(inner)**"
            @unknown default:
                break
            }
        }
        return result
    }

}

