# Emacs Hoarder

An Emacs client for [Hoarder](https://hoarder.app), allowing you to manage your bookmarks directly from Emacs.

## Features

- Sync Hoarder bookmarks to local Org-mode or Markdown files
- Browse bookmarks using Emacs completion
- Customizable sync options

## Installation

1. Requirements:
   - Emacs 27.1 or later

2. Clone this repository:
   ```bash
   git clone https://github.com/vandeefeng/emacs-hoarder ~/.emacs.d/site-lisp/emacs-hoarder
   ```

3. Add to your Emacs configuration:
   ```elisp
   (add-to-list 'load-path "~/.emacs.d/site-lisp/emacs-hoarder")
   (require 'hoarder)
   ```

## Configuration


Using `.authinfo`:

```
machine hoarder-server.com login api-key password your-hoarder-api-key
```

Environment variables:

```bash
export HOARDER_API_KEY='your-hoarder-api-key'
export HOARDER_SERVER_URL='https://your-hoarder-server'
```
In Emacs:

```elisp
;; Set your API key (will be prompted if not set)
(setq hoarder-api-key "your-api-key")
(setq hoarder-server-url "https://your-server-url")

;; Customize sync folder (default: ~/hoarder)
(setq hoarder-sync-folder "~/your/path/")

;; Other options
(setq hoarder-update-existing-files t)  ; Update existing files during sync,default t
(setq hoarder-exclude-archived t)       ; Exclude archived bookmarks,default t
(setq hoarder-only-favorites nil)       ; Only sync favorite bookmarks,defult nil
```

## Usage

1. Enable the minor mode:
   ```elisp
   M-x hoarder-mode
   ```

2. Key bindings:
   - `C-c h s`: Sync bookmarks from Hoarder
   - `C-c h b`: Browse local bookmarks

3. Commands:
   - `M-x hoarder-sync`: Incrementally sync bookmarks (only changed since last sync)
   - `M-x hoarder-force-sync`: Force sync all bookmarks
   - `M-x hoarder-browse-bookmarks`: Browse and open bookmarks

## File Format

Bookmarks can be saved as Markdown or Org-mode files.

### Markdown

Bookmarks are saved as Markdown files with YAML frontmatter:

```markdown
---
title: Example Bookmark
url: https://example.com
type: link
created: 2024-03-20T12:00:00Z
modified: 2024-03-20T12:00:00Z
tags:
  - #example
  - #bookmark
---

[Example Bookmark](https://example.com)

## Highlights

> This is a highlighted text.

This is a note on the highlight.

## Notes

Your notes about the bookmark
```

### Org Mode

Bookmarks can also be saved in Org mode format with properties:

```org
* Example Bookmark
:PROPERTIES:
:URL: https://example.com
:TYPE: link
:CREATED: 2024-03-20T12:00:00Z
:MODIFIED: 2024-03-20T12:00:00Z
:TAGS: example bookmark
:END:

[[https://example.com][Example Bookmark]]

** Highlights

#+begin_quote
This is a highlighted text.
#+end_quote

This is a note on the highlight.

** Notes

Your notes about the bookmark.
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
