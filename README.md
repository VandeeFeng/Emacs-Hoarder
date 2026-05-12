# Emacs Hoarder

An Emacs client for [Hoarder](https://hoarder.app) (now renamed to [Karakeep](https://karakeep.app)), allowing you to manage your bookmarks directly from Emacs.

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
export KARAKEEP_API_KEY='your-karakeep-api-key'
export KARAKEEP_SERVER_ADDR='https://your-karakeep-server'
```

If you can not get the env in emacs :

```elisp
(use-package exec-path-from-shell
  :ensure t
  :config
  (when (memq window-system '(mac ns x))
  (exec-path-from-shell-initialize)
  (exec-path-from-shell-copy-env "KARAKEEP_SERVER_ADDR")
  (exec-path-from-shell-copy-env "KARAKEEP_API_KEY")))
```

In Emacs:

```elisp
;; Set your API key (will be prompted if not set)
(setq karakeep-api-key "your-api-key")
(setq karakeep-server-addr "https://your-server-url")

;; Customize sync folder (default: ~/hoarder)
(setq hoarder-sync-folder "~/your/path/")

;; Other options
(setq hoarder-file-format 'markdown)    ; set file format, org as default
(setq hoarder-update-existing-files t)  ; Update existing files during sync,default t
(setq hoarder-exclude-archived t)       ; Exclude archived bookmarks,default t
(setq hoarder-only-favorites nil)       ; Only sync favorite bookmarks,defult nil
```

The environment variable names follow the official [karakeep-CLI](https://docs.karakeep.app/integrations/command-line/#usage) configuration.

Legacy is still supported:

```bash
export KARAKEEP_SERVER_URL='https://your-karakeep-server'
export HOARDER_API_KEY='your-hoarder-api-key'
export HOARDER_SERVER_URL='https://your-hoarder-server'
```

```elisp
(setq hoarder-api-key "your-api-key")
(setq hoarder-server-url "https://your-server-url")
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
   - `M-x hoarder-sync-tag`: Sync bookmarks by given tag name, storing them in a dedicated `#tagname` folder under the sync folder.

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
