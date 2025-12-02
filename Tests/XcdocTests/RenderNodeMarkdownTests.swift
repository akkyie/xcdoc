import Foundation
import SwiftDocC
import Testing

@testable import xcdoc

@Suite("RenderNode+Markdown Tests")
struct RenderNodeMarkdownTests {
    @Test("renderAsMarkdown produces expected output for comprehensive input")
    func renderAsMarkdownComprehensive() throws {
        let json = """
        {
            "schemaVersion": {
                "major": 0,
                "minor": 3,
                "patch": 0
            },
            "identifier": {
                "url": "doc://test/documentation/TestModule/TestClass",
                "interfaceLanguage": "swift"
            },
            "kind": "symbol",
            "metadata": {
                "title": "TestClass",
                "roleHeading": "Class",
                "platforms": [
                    {
                        "name": "iOS",
                        "introducedAt": "15.0"
                    },
                    {
                        "name": "macOS",
                        "introducedAt": "12.0",
                        "deprecatedAt": "14.0"
                    }
                ]
            },
            "abstract": [
                { "type": "text", "text": "A " },
                {
                    "type": "strong",
                    "inlineContent": [
                        { "type": "text", "text": "test" }
                    ]
                },
                { "type": "text", "text": " class with " },
                { "type": "codeVoice", "code": "code" },
                { "type": "text", "text": " and " },
                {
                    "type": "emphasis",
                    "inlineContent": [
                        { "type": "text", "text": "emphasis" }
                    ]
                },
                { "type": "text", "text": "." }
            ],
            "primaryContentSections": [
                {
                    "kind": "content",
                    "content": [
                        {
                            "type": "heading",
                            "level": 2,
                            "text": "Overview"
                        },
                        {
                            "type": "paragraph",
                            "inlineContent": [
                                { "type": "text", "text": "Regular text, " },
                                { "type": "codeVoice", "code": "inlineCode" },
                                { "type": "text", "text": ", " },
                                {
                                    "type": "reference",
                                    "identifier": "doc://test/ref",
                                    "isActive": true,
                                    "overridingTitle": "Link Title"
                                },
                                { "type": "text", "text": ", " },
                                {
                                    "type": "reference",
                                    "identifier": "doc://test/autolink",
                                    "isActive": true
                                },
                                { "type": "text", "text": ", " },
                                {
                                    "type": "newTerm",
                                    "inlineContent": [
                                        { "type": "text", "text": "term" }
                                    ]
                                },
                                { "type": "text", "text": ", " },
                                {
                                    "type": "subscript",
                                    "inlineContent": [
                                        { "type": "text", "text": "sub" }
                                    ]
                                },
                                { "type": "text", "text": ", " },
                                {
                                    "type": "superscript",
                                    "inlineContent": [
                                        { "type": "text", "text": "super" }
                                    ]
                                },
                                { "type": "text", "text": ", " },
                                {
                                    "type": "strikethrough",
                                    "inlineContent": [
                                        { "type": "text", "text": "strike" }
                                    ]
                                },
                                { "type": "text", "text": ", " },
                                {
                                    "type": "inlineHead",
                                    "inlineContent": [
                                        { "type": "text", "text": "head" }
                                    ]
                                },
                                { "type": "text", "text": ", " },
                                { "type": "image", "identifier": "img-id" },
                                { "type": "text", "text": "." }
                            ]
                        },
                        {
                            "type": "aside",
                            "style": "note",
                            "content": [
                                {
                                    "type": "paragraph",
                                    "inlineContent": [
                                        { "type": "text", "text": "This is a note." }
                                    ]
                                }
                            ]
                        },
                        {
                            "type": "unorderedList",
                            "items": [
                                {
                                    "content": [
                                        {
                                            "type": "paragraph",
                                            "inlineContent": [
                                                { "type": "text", "text": "Item A" }
                                            ]
                                        }
                                    ]
                                },
                                {
                                    "content": [
                                        {
                                            "type": "paragraph",
                                            "inlineContent": [
                                                { "type": "text", "text": "Item B" }
                                            ]
                                        }
                                    ]
                                }
                            ]
                        },
                        {
                            "type": "orderedList",
                            "items": [
                                {
                                    "content": [
                                        {
                                            "type": "paragraph",
                                            "inlineContent": [
                                                { "type": "text", "text": "First" }
                                            ]
                                        }
                                    ]
                                },
                                {
                                    "content": [
                                        {
                                            "type": "paragraph",
                                            "inlineContent": [
                                                { "type": "text", "text": "Second" }
                                            ]
                                        }
                                    ]
                                }
                            ]
                        },
                        {
                            "type": "codeListing",
                            "syntax": "swift",
                            "code": ["let x = 1", "print(x)"]
                        },
                        {
                            "type": "termList",
                            "items": [
                                {
                                    "term": {
                                        "inlineContent": [
                                            { "type": "text", "text": "Key" }
                                        ]
                                    },
                                    "definition": {
                                        "content": [
                                            {
                                                "type": "paragraph",
                                                "inlineContent": [
                                                    { "type": "text", "text": "Value" }
                                                ]
                                            }
                                        ]
                                    }
                                }
                            ]
                        },
                        {
                            "type": "table",
                            "header": "row",
                            "rows": [
                                [
                                    [
                                        {
                                            "type": "paragraph",
                                            "inlineContent": [
                                                { "type": "text", "text": "Header1" }
                                            ]
                                        }
                                    ],
                                    [
                                        {
                                            "type": "paragraph",
                                            "inlineContent": [
                                                { "type": "text", "text": "Header2" }
                                            ]
                                        }
                                    ]
                                ],
                                [
                                    [
                                        {
                                            "type": "paragraph",
                                            "inlineContent": [
                                                { "type": "text", "text": "Cell1" }
                                            ]
                                        }
                                    ],
                                    [
                                        {
                                            "type": "paragraph",
                                            "inlineContent": [
                                                { "type": "text", "text": "Cell2" }
                                            ]
                                        }
                                    ]
                                ]
                            ]
                        },
                        {
                            "type": "small",
                            "inlineContent": [
                                { "type": "text", "text": "Small text" }
                            ]
                        },
                        { "type": "thematicBreak" },
                        {
                            "type": "row",
                            "numberOfColumns": 1,
                            "columns": [
                                {
                                    "size": 1,
                                    "content": [
                                        {
                                            "type": "paragraph",
                                            "inlineContent": [
                                                { "type": "text", "text": "Column content" }
                                            ]
                                        }
                                    ]
                                }
                            ]
                        },
                        {
                            "type": "links",
                            "style": "list",
                            "items": ["link1", "link2"]
                        },
                        {
                            "type": "video",
                            "identifier": "video-id"
                        }
                    ]
                }
            ],
            "topicSections": [
                {
                    "title": "Properties",
                    "identifiers": [
                        "doc://test/prop1",
                        "doc://test/prop2"
                    ]
                }
            ],
            "seeAlsoSections": [
                {
                    "title": "Related",
                    "identifiers": ["doc://test/related"]
                }
            ],
            "relationshipsSections": [
                {
                    "kind": "relationships",
                    "type": "conformsTo",
                    "title": "Conforms To",
                    "identifiers": ["doc://test/protocol"]
                }
            ],
            "sections": [],
            "references": {
                "doc://test/prop1": {
                    "type": "topic",
                    "identifier": "doc://test/prop1",
                    "title": "property1",
                    "url": "/documentation/test/prop1"
                },
                "doc://test/related": {
                    "type": "topic",
                    "identifier": "doc://test/related",
                    "title": "RelatedClass",
                    "url": "/documentation/test/related"
                },
                "doc://test/protocol": {
                    "type": "topic",
                    "identifier": "doc://test/protocol",
                    "title": "SomeProtocol",
                    "url": "/documentation/test/protocol"
                }
            }
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let renderNode = try decoder.decode(RenderNode.self, from: data)
        let markdown = renderNode.renderAsMarkdown()

        let expected = """
            # TestClass

            Class

            iOS 15.0+ | macOS 12.0+ (deprecated: 14.0)

            A **test** class with `code` and *emphasis*.

            ## Overview

            Regular text, `inlineCode`, [Link Title](doc://test/ref), <doc://test/autolink>, _term_, <sub>sub</sub>, <sup>super</sup>, ~~strike~~, **head**, ![](img-id).

            > **Note**: This is a note.

            - Item A
            - Item B

            1. First
            2. Second

            ```swift
            let x = 1
            print(x)
            ```

            **Key**
            : Value

            | Header1 | Header2 |
            | --- | --- |
            | Cell1 | Cell2 |

            <small>Small text</small>

            ---

            Column content

            - link1
            - link2

            ![](video-id)

            ## Topics

            ### Properties

            - [property1](/documentation/test/prop1)
            - doc://test/prop2

            ## See Also

            ### Related

            - [RelatedClass](/documentation/test/related)

            ## Relationships

            ### Conforms To

            - [SomeProtocol](/documentation/test/protocol)


            """

        #expect(markdown == expected)
    }
}
