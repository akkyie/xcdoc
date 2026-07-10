---
name: xcdoc
description: Search and read Apple's official documentation offline using the `xcdoc` CLI. Use INSTEAD of fetching `developer.apple.com/documentation/...` URLs from the web — `xcdoc show` renders the same pages offline and should be preferred over WebFetch/curl for any developer.apple.com documentation link. Also use when investigating Apple platform APIs (macOS/iOS/watchOS/tvOS/visionOS), resolving compiler errors involving Apple frameworks, planning implementations that use Apple platform features, or when the user explicitly asks to look up Apple documentation.
---

# xcdoc

`xcdoc` searches and renders the documentation bundled with the locally installed Xcode. It works fully offline — prefer it over web searches for Apple API details, availability, and best practices.

## Commands

### Search by keyword

```sh
xcdoc search <keywords...>
```

- Multiple keywords narrow results (AND match). Input is split on whitespace and `.`, so `xcdoc search UIView alpha` and `xcdoc search UIView.alpha` are equivalent.
- Operators and symbols are searchable: `xcdoc search String +`
- Filter by language with `--swift`, `--objc`, or `--other` (data/REST/JS docs). At most one filter.
- `--limit <n>` (default 20) shows more results; a trailing `... and N more results` line indicates there are more.

Each result line looks like:

```
[Swift] UIView (Class - UIKit) /documentation/uikit/uiview
```

Pass the trailing path to `xcdoc show`.

### Show a page as Markdown

```sh
xcdoc show <path>
```

Accepted path forms:

- Documentation path: `xcdoc show /documentation/uikit/uiview`
- A full `developer.apple.com` URL pasted as-is: `xcdoc show "https://developer.apple.com/documentation/uikit/uiview"` — do this instead of fetching the URL from the web. A `?language=objc` query selects the language.
- `doc://` links as they appear inside rendered pages: `xcdoc show "doc://com.apple.uikit/documentation/UIKit/UIView"`
- Disambiguated symbol paths: `xcdoc show "/documentation/swift/string/+(_:_:)-9fm57"`

Quote paths containing symbols or query strings. Use `--swift` / `--objc` / `--other` to pick the language variant when a page exists in more than one.

### Browse the hierarchy

```sh
xcdoc list [--depth <n>]
```

Prints the documentation category tree (default depth 2). Listed paths can be passed to `xcdoc show`.

## Workflow

1. Search for the symbol or concept with `xcdoc search`. If nothing matches, retry with broader or fewer keywords.
2. Open the most relevant result with `xcdoc show`.
3. Follow `doc://` links and "See Also"/"Mentions" entries in the rendered page — pass them back to `xcdoc show`.
4. When search results include articles (not just symbol pages), read them: articles carry the high-level guidance and best practices that reference pages lack.

For compiler errors, search the exact symbol name from the error message first, then read the page's declaration and availability sections. For implementation planning, read overview articles before drilling into individual APIs.

## Tips

- The Xcode used is determined by `xcode-select -p`. Override per-invocation with `DEVELOPER_DIR`:

  ```sh
  DEVELOPER_DIR=/Applications/Xcode-26.0.0.app/Contents/Developer xcdoc search liquid glass
  ```

- If `xcdoc` is not installed, install it with `mint install akkyie/xcdoc`, or build from source: <https://github.com/akkyie/xcdoc>
- If a page is not found, the path may be wrong — locate the correct one via `xcdoc search` or `xcdoc list` instead of guessing variants.
