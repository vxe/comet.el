;;; comet.el --- LLM-assisted interaction for comint REPLs -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;; Author: Claude
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: convenience, tools, ai, repl
;; URL: https://github.com/yourusername/comet.el

;;; Commentary:

;; Comet is an Emacs extension that adds LLM-assisted interaction to any
;; `comint'-derived REPL (CIDER, SLY, Shell, IELM, etc.).
;;
;; It provides a universal minibuffer prompt to query an AI model and insert
;; or evaluate the response directly in the active REPL.
;;
;; Comet's goal is to be a REPL-native AI companion, helping you write,
;; generate, or reason about code in context — without leaving your workflow
;; or dealing with language-specific syntax.
;;
;; Setup:
;;   1. Install gptel: M-x package-install RET gptel RET
;;   2. Add API key to ~/.authinfo (recommended):
;;        machine api.openai.com login apikey password YOUR-KEY-HERE
;;   3. Load comet: (require 'comet)
;;
;; Usage:
;;   M-x comet-send-prompt (or C-c C-a in supported REPL modes)
;;
;;   Prefix arguments:
;;   - No prefix → Insert as comment
;;   - C-u → Insert raw
;;   - C-u C-u → Send as REPL input (evaluate)
;;
;; Comet uses gptel's configuration, which by default reads API keys from
;; ~/.authinfo.  This is the secure and recommended method for storing keys.

;;; Code:

(require 'comint)
(require 'auth-source)
(require 'cl-lib)

;;; External declarations (for byte-compiler)
(declare-function gptel-request "gptel" (prompt &rest args))
(declare-function gptel-make-openai "gptel-openai" (name &rest args))
(declare-function gptel-make-anthropic "gptel-anthropic" (name &rest args))
(declare-function gptel-make-ollama "gptel-ollama" (name &rest args))
(declare-function gptel-make-gemini "gptel-gemini" (name &rest args))
(declare-function gptel-make-groq "gptel-openai" (name &rest args))
(defvar gptel-backend)
(defvar gptel-model)
(defvar gptel--known-backends)

;;; Customization

(defgroup comet nil
  "LLM-assisted interaction for comint REPLs."
  :group 'convenience
  :prefix "comet-")

(defcustom comet-default-backend 'gptel
  "The default AI backend to use for Comet queries.
Supported values: 'gptel, 'claude-api (extensible)."
  :type '(choice (const :tag "GPTEL" gptel)
                 (const :tag "Claude API" claude-api)
                 (symbol :tag "Custom backend"))
  :group 'comet)

(defcustom comet-insert-separator t
  "Whether to insert a separator line before Comet responses."
  :type 'boolean
  :group 'comet)

(defcustom comet-comment-prefix-alist
  '((emacs-lisp-mode . ";;")
    (lisp-mode . ";;")
    (scheme-mode . ";;")
    (clojure-mode . ";;")
    (python-mode . "#")
    (shell-mode . "#")
    (sh-mode . "#")
    (ruby-mode . "#")
    (perl-mode . "#")
    (sql-mode . "--")
    (haskell-mode . "--")
    (erlang-mode . "%")
    (default . "#"))
  "Alist mapping major modes to their comment prefixes."
  :type '(alist :key-type symbol :value-type string)
  :group 'comet)

(defcustom comet-system-message
  "You are a helpful AI assistant integrated into a REPL environment. \
Provide concise, accurate code snippets and explanations suitable for \
immediate use in the REPL. Focus on practical, executable solutions."
  "System message sent to the LLM backend with each Comet request."
  :type 'string
  :group 'comet)

(defcustom comet-use-stream nil
  "Whether to stream responses from the LLM backend.
If non-nil, responses will be streamed as they are generated.
Note: Streaming support depends on the backend and model being used."
  :type 'boolean
  :group 'comet)

;;; Provider Registry

(defconst comet-provider-registry
  '(("api.openai.com"
     :name "OpenAI"
     :type openai
     :make-fn gptel-make-openai
     :models (gpt-4o gpt-4o-mini gpt-4-turbo gpt-3.5-turbo))
    ("api.anthropic.com"
     :name "Anthropic"
     :type anthropic
     :make-fn gptel-make-anthropic
     :models (claude-3-5-sonnet-20241022 claude-3-5-haiku-20241022
              claude-3-opus-20240229 claude-3-sonnet-20240229))
    ("api.groq.com"
     :name "Groq"
     :type groq
     :make-fn gptel-make-groq
     :models (llama-3.3-70b-versatile llama-3.1-8b-instant
              mixtral-8x7b-32768 gemma2-9b-it))
    ("generativelanguage.googleapis.com"
     :name "Gemini"
     :type gemini
     :make-fn gptel-make-gemini
     :models (gemini-1.5-flash gemini-1.5-pro gemini-2.0-flash-exp))
    ("localhost:11434"
     :name "Ollama"
     :type ollama
     :make-fn gptel-make-ollama
     :local t
     :models nil))
  "Registry of known LLM providers and their configuration.
Each entry is (HOSTNAME PLIST) where PLIST contains:
  :name - Display name for the provider
  :type - Provider type symbol
  :make-fn - Function to create the backend
  :models - List of available model symbols
  :local - t if this is a local service (no auth required)")

(defun comet--find-authinfo-providers ()
  "Find LLM providers that have API keys configured in authinfo.
Returns a list of plists with :host, :name, :type, and :key."
  (let ((providers nil))
    (dolist (entry comet-provider-registry)
      (let* ((host (car entry))
             (info (cdr entry))
             (local-p (plist-get info :local)))
        ;; For local services, check if accessible; for others, check authinfo
        (when (or local-p
                  (auth-source-search :host host :require '(:secret) :max 1))
          (push (list :host host
                      :name (plist-get info :name)
                      :type (plist-get info :type)
                      :make-fn (plist-get info :make-fn)
                      :models (plist-get info :models)
                      :local local-p)
                providers))))
    (nreverse providers)))

(defun comet--ensure-backend-registered (provider-info)
  "Ensure a backend is registered for PROVIDER-INFO.
If not already registered, create and register it.
Returns the backend name."
  (let* ((name (plist-get provider-info :name))
         (type (plist-get provider-info :type))
         (make-fn (plist-get provider-info :make-fn))
         (models (plist-get provider-info :models))
         (local-p (plist-get provider-info :local)))

    ;; Check if backend already exists
    (unless (and (boundp 'gptel--known-backends)
                 (assoc name gptel--known-backends))
      ;; Register the backend
      (require (intern (format "gptel-%s" type)) nil t)
      (when (fboundp make-fn)
        (cond
         ;; Ollama (local, no key needed)
         ((eq type 'ollama)
          (funcall make-fn name
                   :host (plist-get provider-info :host)
                   :stream t
                   :models (or models '(mistral:latest llama3:latest))))
         ;; Cloud providers (use authinfo key)
         (t
          (funcall make-fn name
                   :stream t
                   :key 'gptel-api-key-from-auth-source)))))
    name))

;;; Session Context

(defvar-local comet-session nil
  "Buffer-local session data for Comet.
Stores conversation history and model context.")

(defvar comet-prompt-history nil
  "History of Comet prompts used across REPL sessions.")

(defun comet-init-session ()
  "Initialize a Comet session for the current buffer.
This is automatically called when entering a REPL mode."
  (unless comet-session
    (setq comet-session
          (list :created (current-time)
                :history '()
                :context nil
                :model nil))))

(defun comet-add-to-session-history (prompt response)
  "Add PROMPT and RESPONSE to the current session's conversation history."
  (when comet-session
    (let ((history (plist-get comet-session :history)))
      (plist-put comet-session :history
                 (append history (list (list :prompt prompt
                                             :response response
                                             :timestamp (current-time))))))))

;;; Backend Abstraction

(defun comet--get-comment-prefix ()
  "Get the appropriate comment prefix for the current major mode."
  (or (cdr (assq major-mode comet-comment-prefix-alist))
      (cdr (assq 'default comet-comment-prefix-alist))
      "#"))

(defun comet--send-to-backend (prompt callback)
  "Send PROMPT to the configured AI backend and call CALLBACK with its response.
The CALLBACK function should accept one argument: the response string.

This function handles the backend communication asynchronously."
  (cond
   ;; GPTEL backend
   ((and (eq comet-default-backend 'gptel)
         (fboundp 'gptel-request))
    (gptel-request prompt
                   :system comet-system-message
                   :stream comet-use-stream
                   :callback (lambda (response info)
                               (cond
                                ;; Successful response
                                ((stringp response)
                                 (funcall callback (string-trim response)))
                                ;; Request was aborted
                                ((eq response 'abort)
                                 (message "Comet: Request aborted"))
                                ;; Error or no response
                                (t
                                 (message "Comet: Request failed - %s"
                                          (or (plist-get info :status) "Unknown error")))))))

   ;; Claude API backend (placeholder for future implementation)
   ((eq comet-default-backend 'claude-api)
    (error "Claude API backend not yet implemented. Please use GPTEL or implement a custom backend"))

   ;; No supported backend found
   (t
    (error "No supported AI backend found. Please install GPTEL or configure comet-default-backend"))))

;;;###autoload
(defun comet-switch-provider ()
  "Switch LLM provider based on what's available in authinfo.
Automatically discovers providers with API keys in ~/.authinfo,
shows them in a completing-read menu, and switches to the selected
provider for all subsequent Comet interactions."
  (interactive)
  (let* ((available-providers (comet--find-authinfo-providers))
         (provider-names (mapcar (lambda (p) (plist-get p :name))
                                available-providers)))
    (if (null available-providers)
        (user-error "No LLM providers found in authinfo.
Please add API keys to ~/.authinfo. See M-x describe-variable RET comet-provider-registry")
      ;; Let user select provider
      (let* ((selected-name (completing-read
                            "Select LLM provider: "
                            provider-names nil t))
             (provider-info (cl-find-if
                            (lambda (p) (string= (plist-get p :name) selected-name))
                            available-providers))
             (backend-name (comet--ensure-backend-registered provider-info))
             (models (plist-get provider-info :models)))

        ;; Now select model from the provider
        (when models
          (let* ((current-model (and (boundp 'gptel-model) gptel-model))
                 (model-names (mapcar #'symbol-name models))
                 (default-model (if (memq current-model models)
                                   (symbol-name current-model)
                                 (car model-names)))
                 (selected-model (intern
                                 (completing-read
                                  (format "Select %s model: " selected-name)
                                  model-names nil t nil nil default-model))))
            ;; Set the backend and model globally
            (when (boundp 'gptel-backend)
              (setq gptel-backend
                    (alist-get backend-name gptel--known-backends nil nil #'equal)))
            (when (boundp 'gptel-model)
              (setq gptel-model selected-model))

            (message "Comet switched to %s (%s)" selected-name selected-model)))

        ;; For local providers without predefined models
        (unless models
          (when (boundp 'gptel-backend)
            (setq gptel-backend
                  (alist-get backend-name gptel--known-backends nil nil #'equal)))
          (message "Comet switched to %s" selected-name))))))

;;; Core Functions

(defun comet--format-response (prompt response prefix-arg)
  "Format RESPONSE based on PREFIX-ARG behavior.
PREFIX-ARG controls the insertion mode:
  - nil: Insert as comment
  - (4): Insert raw
  - (16): Return for evaluation"
  (let ((comment-prefix (comet--get-comment-prefix)))
    (cond
     ;; C-u C-u: Return raw for evaluation
     ((equal prefix-arg '(16))
      response)

     ;; C-u: Insert raw
     ((equal prefix-arg '(4))
      (format "\n%s\n" (string-trim response)))

     ;; Default: Insert as comment
     (t
      (let ((separator (if comet-insert-separator
                          (format "\n%s %s\n" comment-prefix (make-string 60 ?-))
                        ""))
            (header (format "%s Comet: %s\n" comment-prefix prompt))
            (body (mapconcat (lambda (line)
                              (format "%s %s" comment-prefix line))
                            (split-string (string-trim response) "\n")
                            "\n")))
        (format "%s%s%s\n" separator header body))))))

(defun comet--insert-at-repl (text &optional eval)
  "Insert TEXT at the end of the REPL buffer.
If EVAL is non-nil, send the text as REPL input for evaluation."
  (let ((inhibit-read-only t))
    (goto-char (point-max))
    (if eval
        ;; Send as REPL input
        (progn
          (insert text)
          (comint-send-input))
      ;; Just insert the text
      (insert text))))

;;;###autoload
(defun comet-send-prompt (prompt &optional prefix-arg)
  "Prompt the user for a Comet query and send it to the LLM backend.
Inserts the response into the current REPL buffer.

PREFIX-ARG controls how the response is inserted:
  - No prefix → Insert as comment
  - C-u → Insert raw
  - C-u C-u → Send as REPL input (evaluate)"
  (interactive
   (list (read-from-minibuffer "Comet prompt: "
                               nil nil nil 'comet-prompt-history)
         current-prefix-arg))

  ;; Initialize session if needed
  (comet-init-session)

  (let ((buf (current-buffer))
        (eval-mode (equal prefix-arg '(16))))

    (message "Comet: Sending query to %s..." comet-default-backend)

    (comet--send-to-backend
     prompt
     (lambda (response)
       (with-current-buffer buf
         ;; Add to session history
         (comet-add-to-session-history prompt response)

         ;; Format and insert response
         (let ((formatted (comet--format-response prompt response prefix-arg)))
           (comet--insert-at-repl formatted eval-mode)

           (message "Comet: Response inserted.")))))))

;;;###autoload
(defun comet-continue ()
  "Continue the previous Comet conversation with a follow-up prompt."
  (interactive)
  (if (and comet-session
           (plist-get comet-session :history))
      (call-interactively #'comet-send-prompt)
    (message "No previous Comet conversation in this buffer.")))

;;;###autoload
(defun comet-clear-session ()
  "Clear the current buffer's Comet session history."
  (interactive)
  (when (yes-or-no-p "Clear Comet session history for this buffer? ")
    (setq comet-session nil)
    (comet-init-session)
    (message "Comet session cleared.")))

;;;###autoload
(defun comet-show-session-history ()
  "Display the conversation history for the current Comet session."
  (interactive)
  (if (and comet-session
           (plist-get comet-session :history))
      (let ((history (plist-get comet-session :history)))
        (with-current-buffer (get-buffer-create "*Comet Session History*")
          (erase-buffer)
          (special-mode)
          (dolist (entry history)
            (let ((prompt (plist-get entry :prompt))
                  (response (plist-get entry :response))
                  (timestamp (plist-get entry :timestamp)))
              (insert (format "=== %s ===\n" (format-time-string "%Y-%m-%d %H:%M:%S" timestamp)))
              (insert (format "Prompt: %s\n\n" prompt))
              (insert (format "Response:\n%s\n\n" response))
              (insert (make-string 80 ?-))
              (insert "\n\n")))
          (goto-char (point-min))
          (pop-to-buffer (current-buffer))))
    (message "No Comet session history in this buffer.")))

;;; Keybindings

(defvar comet-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-a") #'comet-send-prompt)
    (define-key map (kbd "C-c C-c") #'comet-continue)
    (define-key map (kbd "C-c C-k") #'comet-clear-session)
    (define-key map (kbd "C-c C-s") #'comet-switch-provider)
    map)
  "Keymap for Comet commands.")

;;;###autoload
(define-minor-mode comet-mode
  "Minor mode for LLM-assisted interaction in comint REPLs."
  :lighter " Comet"
  :keymap comet-mode-map
  (when comet-mode
    (comet-init-session)))

;;; Mode-specific setup

(defun comet-setup-repl-mode ()
  "Enable Comet mode and initialize session for REPL buffers."
  (comet-mode 1))

;; Auto-enable for common REPL modes
(with-eval-after-load 'cider-repl
  (add-hook 'cider-repl-mode-hook #'comet-setup-repl-mode))

(with-eval-after-load 'sly
  (add-hook 'sly-mrepl-mode-hook #'comet-setup-repl-mode))

(with-eval-after-load 'geiser-repl
  (add-hook 'geiser-repl-mode-hook #'comet-setup-repl-mode))

(with-eval-after-load 'shell
  (add-hook 'shell-mode-hook #'comet-setup-repl-mode))

(with-eval-after-load 'ielm
  (add-hook 'ielm-mode-hook #'comet-setup-repl-mode))

(with-eval-after-load 'inferior-python
  (add-hook 'inferior-python-mode-hook #'comet-setup-repl-mode))

;;; Optional Enhancements

;;;###autoload
(defun comet-insert-code-at-point (code)
  "Insert CODE at point in the current buffer, formatted appropriately."
  (interactive "sCode to insert: ")
  (insert code))

(provide 'comet)

;;; comet.el ends here
