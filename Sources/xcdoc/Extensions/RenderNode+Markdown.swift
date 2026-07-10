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
            } else if let declarationsSection = section as? DeclarationsRenderSection {
                md += renderDeclarations(declarationsSection)
            } else if let parametersSection = section as? ParametersRenderSection {
                md += renderParameters(parametersSection)
            }
        }

        for section in sections {
            if let tutorialSections = section as? TutorialSectionsRenderSection {
                md += renderTutorialSections(tutorialSections)
            }
        }

        if !topicSections.isEmpty {
            md += renderTaskGroups(topicSections, heading: "Topics", references: references)
        }

        if !seeAlsoSections.isEmpty {
            md += renderTaskGroups(seeAlsoSections, heading: "See Also", references: references)
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

    private func renderTaskGroups(_ sections: [TaskGroupRenderSection], heading: String, references: [String: any RenderReference]) -> String {
        var md = "## \(heading)\n\n"

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

    private func renderDeclarations(_ section: DeclarationsRenderSection) -> String {
        guard !section.declarations.isEmpty else { return "" }

        var md = "## Declaration\n\n"
        for declaration in section.declarations {
            let code = declaration.tokens.map(\.text).joined()
            let lang = declaration.languages?.first ?? ""
            md += "```\(lang)\n\(code)\n```\n\n"
        }
        return md
    }

    private func renderParameters(_ section: ParametersRenderSection) -> String {
        guard !section.parameters.isEmpty else { return "" }

        var md = "## Parameters\n\n"
        for parameter in section.parameters {
            md += "**\(parameter.name)**\n"
            let content = renderBlockContent(parameter.content)
            md += ": \(content.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
        }
        return md
    }

    private func renderTutorialSections(_ section: TutorialSectionsRenderSection) -> String {
        var md = ""

        for task in section.tasks {
            md += "## \(task.title)\n\n"

            for layout in task.contentSection {
                switch layout {
                case .fullWidth(let content):
                    md += renderBlockContent(content)
                case .contentAndMedia(let content):
                    md += renderBlockContent(content.content)
                case .columns(let columns):
                    for column in columns {
                        md += renderBlockContent(column.content)
                    }
                @unknown default:
                    break
                }
            }

            md += renderBlockContent(task.stepsSection)
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
        case .step(let step):
            return renderStep(step)
        case .endpointExample, .dictionaryExample, .tabNavigator, ._nonfrozenEnum_useDefaultCase:
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

    private func renderStep(_ step: RenderBlockContent.TutorialStep) -> String {
        var md = renderBlockContent(step.content)

        if !step.caption.isEmpty {
            md += renderBlockContent(step.caption)
        }

        if let code = step.code, let file = references[code.identifier] as? FileReference {
            let content = file.content.joined(separator: "\n")
            md += "```\(file.syntax)\n\(content)\n```\n\n"
        }

        return md
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

        // GFM requires a header/separator row even when the table has none.
        // `.column` headers aren't expressible in GFM either, so they fall
        // back to the same empty-header treatment as `.none`.
        if !header, let columnCount = table.rows.first?.cells.count {
            let emptyCells = Array(repeating: "", count: columnCount)
            md += "| " + emptyCells.joined(separator: " | ") + " |\n"
            md += "|" + emptyCells.map { _ in " --- " }.joined(separator: "|") + "|\n"
        }

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

