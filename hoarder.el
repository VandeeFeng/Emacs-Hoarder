;;; hoarder.el --- Hoarder client for Emacs -*- lexical-binding: t -*-

;; Copyright (C) 2024 

;; Author: Your Name
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: bookmarks, hoarder
;; URL: https://github.com/yourusername/emacs-hoarder

;;; Commentary:
;; A client for Hoarder (https://hoarder.app) in Emacs.
;; This package allows you to manage your Hoarder bookmarks directly from Emacs.

;;; Code:

(require 'json)
(require 'url)
(require 'url-http)

(defvar url-mime-charset-string "utf-8")

(defgroup hoarder nil
  "Hoarder client for Emacs."
  :group 'applications)

(defcustom hoarder-server-url "http://localhost:3000"
  "Base URL of your Karakeep server.
For self-hosted instances, this should be your server URL.
For the demo instance, use https://try.karakeep.app"
  :type 'string
  :group 'hoarder)

(defcustom hoarder-api-key ""
  "API key for Karakeep (Bearer token).
For self-hosted instances, this should be your API key.
For the demo instance, you can get one after logging in."
  :type 'string
  :group 'hoarder)

(defcustom hoarder-sync-folder "~/hoarder"
  "Folder where bookmarks will be saved."
  :type 'directory
  :group 'hoarder)

(defcustom hoarder-attachments-folder "~/hoarder/attachments"
  "Folder where bookmark attachments will be saved."
  :type 'directory
  :group 'hoarder)

(defcustom hoarder-update-existing-files nil
  "Whether to update or skip existing bookmark files."
  :type 'boolean
  :group 'hoarder)

(defcustom hoarder-exclude-archived t
  "Whether to exclude archived bookmarks."
  :type 'boolean
  :group 'hoarder)

(defcustom hoarder-only-favorites nil
  "Whether to only sync favorite bookmarks."
  :type 'boolean
  :group 'hoarder)

(defcustom hoarder-download-assets t
  "Whether to download bookmark assets (images, PDFs)."
  :type 'boolean
  :group 'hoarder)

(defcustom hoarder-file-format 'org
  "Format to save bookmarks in.
Can be 'org for Org mode format or 'markdown for Markdown format."
  :type '(choice (const :tag "Org mode" org)
                 (const :tag "Markdown" markdown))
  :group 'hoarder)

(defvar hoarder--client nil
  "Hoarder client instance.")

(cl-defstruct (hoarder-tag (:constructor hoarder-tag-create))
  "Structure representing a Hoarder tag."
  id name attached-by)

(cl-defstruct (hoarder-bookmark (:constructor hoarder-bookmark-create))
  "Structure representing a Hoarder bookmark."
  id created-at modified-at title archived favourited
  tagging-status note summary tags content assets)

(defvar hoarder-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c h s") 'hoarder-sync)
    (define-key map (kbd "C-c h b") 'hoarder-browse-bookmarks)
    map)
  "Keymap for Hoarder mode.")

(defun hoarder--list-local-bookmarks ()
  "List all local bookmark files."
  (when (file-exists-p hoarder-sync-folder)
    (directory-files-recursively hoarder-sync-folder "\\(\\.org\\|\\.md\\)$")))

(defun hoarder-browse-bookmarks ()
  "Browse local bookmarks using completing-read."
  (interactive)
  (let ((files (hoarder--list-local-bookmarks)))
    (if (not files)
        (message "No bookmarks found. Run M-x hoarder-sync first.")
      (let* ((choices (mapcar (lambda (f)
                                (cons (file-name-nondirectory f) f))
                              files))
             (selection (completing-read "Select bookmark: "
                                         (mapcar #'car choices)
                                         nil t)))
        (find-file (cdr (assoc selection choices)))))))

;;;###autoload
(define-minor-mode hoarder-mode
  "Minor mode for Hoarder integration.

\\{hoarder-mode-map}"
  :lighter " Hoarder"
  :keymap hoarder-mode-map
  :group 'hoarder
  (if hoarder-mode
      (unless hoarder-api-key
        (customize-set-variable
         'hoarder-api-key
         (read-string "Enter your Hoarder API key: ")))))

(defun hoarder--api-endpoint ()
  "Get the full API endpoint URL."
  (concat (string-trim-right hoarder-server-url "/") "/api/v1"))

(defconst hoarder--api-path "/api/v1"
  "API path suffix.")

(defun hoarder--make-request (endpoint method &optional params data)
  "Make a synchronous request to the Karakeep API.
ENDPOINT is the API endpoint.
METHOD is the HTTP method.
Optional PARAMS for query parameters.
Optional DATA for request body.
Optional CALLBACK function to handle the response."
  (unless hoarder-api-key
    (error "Karakeep API key not set"))
  (unless hoarder-server-url
    (error "Karakeep server URL not set"))
  
  (let* ((url-request-method method)
         (url-request-extra-headers
          `(("Authorization" . ,(concat "Bearer " hoarder-api-key))
            ("Content-Type" . "application/json")
            ("Accept" . "application/json; charset=utf-8")))
         (url-request-data (when data
                             (encode-coding-string (json-encode data) 'utf-8)))
         (url (if params
                  (concat (hoarder--api-endpoint) endpoint (concat "?" (url-build-query-string
                                                                        (mapcar (lambda (p)
                                                                                  (list (car p)
                                                                                        (format "%s" (cdr p))))
                                                                                params))))
                (concat (hoarder--api-endpoint) endpoint)))
         (buffer (url-retrieve-synchronously url t t)))
    (if (not buffer)
        (error "Failed to retrieve URL: %s" url)
      (with-current-buffer buffer
        (unwind-protect
            (progn
              (goto-char url-http-end-of-headers)
              (let* ((json-object-type 'alist)
                     (json-array-type 'list)
                     (json-key-type 'symbol)
                     (json-string (decode-coding-string
                                   (buffer-substring-no-properties (point) (point-max))
                                   'utf-8))
                     (data (json-read-from-string json-string)))
                data))
          (kill-buffer))))))

(defun hoarder-fetch-bookmarks (&optional cursor limit)
  "Fetch bookmarks from Hoarder.
Optional CURSOR for pagination.
Optional LIMIT for number of results (default 100)."
  (hoarder--make-request
   "/bookmarks"
   "GET"
   `(("limit" . ,(or limit 100))
     ,@(when cursor `(("cursor" . ,cursor))))
   nil))

(defun hoarder--ensure-directory (dir)
  "Ensure directory DIR exists."
  (unless (file-exists-p dir)
    (make-directory dir t)))

(defun hoarder--format-bookmark-as-org (bookmark)
  "Format BOOKMARK as org content."
  (with-temp-buffer
    (let* ((content (alist-get 'content bookmark))
           (type (alist-get 'type content))
           (url (alist-get 'url content))
           (title (or (alist-get 'title bookmark)
                      (alist-get 'title content)
                      "Untitled"))
           (highlights (alist-get 'highlights bookmark))
           (tags (mapcar (lambda (tag)
                           (alist-get 'name tag))
                         (alist-get 'tags bookmark))))
      ;; Insert title and properties
      (insert (format "* %s\n" title))
      (insert ":PROPERTIES:\n")
      (when url
        (insert (format ":URL: %s\n" url)))
      (insert (format ":TYPE: %s\n" type))
      (insert (format ":CREATED: %s\n" (alist-get 'createdAt bookmark)))
      (when (alist-get 'modifiedAt bookmark)
        (insert (format ":MODIFIED: %s\n" (alist-get 'modifiedAt bookmark))))
      (when tags
        (insert (format ":TAGS: %s\n" (mapconcat #'identity tags " "))))
      (insert ":END:\n\n")

      ;; Insert URL as org link
      (when url
        (insert (format "[[%s][%s]]\n\n" url title)))

      ;; Insert highlights if exists
      (when highlights
        (insert "\n** Highlights\n\n")
        (dolist (highlight highlights)
          (let ((text (alist-get 'text highlight))
                (note (alist-get 'note highlight)))
            (when text
              (insert (format "#+begin_quote\n%s\n#+end_quote\n\n" text)))
            (when note
              (insert (format "%s\n\n" note))))))

      ;; Insert note if exists
      (when-let ((note (alist-get 'note bookmark)))
        (insert "\n** Notes\n\n")
        (insert note)))
    (buffer-string)))

(defun hoarder--format-bookmark-as-markdown (bookmark)
  "Format BOOKMARK as markdown content."
  (with-temp-buffer
    (let* ((content (alist-get 'content bookmark))
           (type (alist-get 'type content))
           (url (alist-get 'url content))
           (title (or (alist-get 'title bookmark)
                      (alist-get 'title content)
                      "Untitled"))
           (highlights (alist-get 'highlights bookmark))
           (tags (mapcar (lambda (tag)
                           (concat "#" (alist-get 'name tag)))
                         (alist-get 'tags bookmark))))
      ;; Insert YAML frontmatter
      (insert "---\n")
      (insert (format "title: %s\n" title))
      (when url
        (insert (format "url: %s\n" url)))
      (insert (format "type: %s\n" type))
      (insert (format "created: %s\n" (alist-get 'createdAt bookmark))))
    (when (alist-get 'modifiedAt bookmark)
      (insert (format "modified: %s\n" (alist-get 'modifiedAt bookmark))))
    (when tags
      (insert "tags:\n")
      (dolist (tag tags)
        (insert (format "  - %s\n" tag))))
    (insert "---\n\n")

    ;; Insert URL as markdown link
    (when url
      (insert (format "[%s](%s)\n\n" title url)))

    ;; Insert highlights if exists
    (when highlights
      (insert "\n## Highlights\n\n")
      (dolist (highlight highlights)
        (let ((text (alist-get 'text highlight))
              (note (alist-get 'note highlight)))
          (when text
            (insert (format "> %s\n\n" text))
            (when note
              (insert (format "%s\n\n" note)))))))
    
    (when-let ((note (alist-get 'note bookmark)))
      (insert "
## Notes

")
      (insert note))
    (buffer-string)))

(defun hoarder--format-bookmark (bookmark)
  "Format BOOKMARK according to hoarder-file-format'."
  (if (eq hoarder-file-format 'org)
      (hoarder--format-bookmark-as-org bookmark)
    (hoarder--format-bookmark-as-markdown bookmark)))

(defun hoarder--get-file-extension ()
  "Get file extension based on hoarder-file-format'."
  (if (eq hoarder-file-format 'org)
      ".org"
    ".md"))

(defun hoarder--sanitize-filename (title created-at)
  "Sanitize TITLE and CREATED-AT for use in filenames.
Preserves Chinese characters and other valid Unicode characters."
  (let* ((clean-title (if (string-empty-p title)
                          "untitled"
                        ;; Only remove invalid filesystem characters
                        (replace-regexp-in-string "[/\\\\:*?\"<>|]" "" title)))
         (date (format-time-string "%Y%m%d" (parse-iso8601-time-string created-at))))
    (concat date "-" clean-title (hoarder--get-file-extension))))

(defun hoarder--sanitize-asset-filename (title)
  "Sanitize asset TITLE for use in filenames.
Preserves Chinese characters and other valid Unicode characters."
  (let ((clean-title (replace-regexp-in-string "[/\\\\:*?\"<>|]" "" title)))
    (if (string-empty-p clean-title)
        "asset"
      clean-title)))

(defun hoarder--download-image (url asset-id title)
  "Download image from URL with ASSET-ID and TITLE."
  (let* ((filename (hoarder--sanitize-asset-filename title))
         (path (expand-file-name filename hoarder-attachments-folder)))
    (when (and url (not (file-exists-p path)))
      (hoarder--ensure-directory hoarder-attachments-folder)
      (url-copy-file url path t)
      path)))

(defun hoarder--fetch-bookmark-highlights (bookmark-id)
  "Fetch highlights for bookmark with BOOKMARK-ID."
  (hoarder--make-request
   (format "/bookmarks/%s/highlights" bookmark-id)
   "GET"
   nil
   nil))

(defun hoarder--save-bookmark (bookmark)
  "Save BOOKMARK to a local file."
  (let* ((title (or (alist-get 'title bookmark)
                    (alist-get 'title (alist-get 'content bookmark))
                    "Untitled"))
         (created-at (alist-get 'createdAt bookmark))
         (filename (hoarder--sanitize-filename title created-at))
         (filepath (expand-file-name filename hoarder-sync-folder))
         (bookmark-id (alist-get 'id bookmark)))
    (hoarder--ensure-directory hoarder-sync-folder)
    (unless (and (file-exists-p filepath)
                 (not hoarder-update-existing-files))
      ;; Fetch highlights
      (let* ((highlights (hoarder--fetch-bookmark-highlights bookmark-id))
             (merged-content (append
                              ;; Use the original bookmark as base
                              bookmark
                              ;; Add highlights from highlights endpoint
                              `((highlights . ,(alist-get 'highlights highlights))))))
        ;; Download assets if enabled
        (when (and hoarder-download-assets
                   (alist-get 'assets bookmark))
          (dolist (asset (alist-get 'assets bookmark))
            (let ((asset-id (alist-get 'id asset))
                  (asset-type (alist-get 'assetType asset)))
              (when (equal asset-type "image")
                (hoarder--download-image
                 (alist-get 'imageUrl (alist-get 'content bookmark))
                 asset-id
                 title)))))
        ;; Save bookmark content
        (let ((content (hoarder--format-bookmark merged-content)))
          (write-region content nil filepath))))))

(defun hoarder--process-bookmarks (bookmarks)
  "Process and save BOOKMARKS to local files."
  (let ((total (length bookmarks))
        (current 0))
    (dolist (bookmark bookmarks)
      (setq current (1+ current))
      (message "Processing bookmark %d/%d..." current total)
      (hoarder--save-bookmark bookmark))
    (message "Finished processing %d bookmarks" total)))

(defun hoarder-fetch-all-bookmarks ()
  "Fetch all bookmarks from Hoarder."
  (let ((all-bookmarks '())
        (cursor nil)
        (has-more t))
    (while has-more
      (let* ((params `(("limit" . 100)
                       ,@(when cursor `(("cursor" . ,cursor)))
                       ,@(when hoarder-exclude-archived `(("archived" . "false")))
                       ,@(when hoarder-only-favorites `(("favourited" . "true")))))
             (response (hoarder--make-request "/bookmarks" "GET" params nil))
             (bookmarks (alist-get 'bookmarks response))
             (next-cursor (alist-get 'nextCursor response)))
        (setq all-bookmarks (append all-bookmarks bookmarks))
        (if next-cursor
            (setq cursor next-cursor)
          (setq has-more nil))
        (message "Fetched %d bookmarks so far..." (length all-bookmarks))))
    (message "Processing %d bookmarks..." (length all-bookmarks))
    (hoarder--process-bookmarks all-bookmarks)))

(defun hoarder-sync ()
  "Sync bookmarks from Hoarder to local files."
  (interactive)
  (message "Starting Hoarder sync...")
  (hoarder-fetch-all-bookmarks))

(provide 'hoarder)
;;; hoarder.el ends here 
