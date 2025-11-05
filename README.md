# 🌠 Comet.el

> *Conversational intelligence for every REPL*

**Comet** is an Emacs extension that brings LLM-assisted interaction to any `comint`-derived REPL, including CIDER, SLY, Shell, IELM, and more.

## ✨ Features

- 🎯 **Universal REPL Integration**: Works with any `comint`-based REPL mode
- 🧠 **Session Context**: Maintains conversation history per REPL buffer
- 🔌 **Backend Agnostic**: Abstracted interface supports multiple LLM backends (GPTEL, Claude API, etc.)
- ⌨️ **Flexible Input Modes**: Insert as comment, raw text, or evaluate directly
- 📝 **Smart Comment Formatting**: Auto-detects language-appropriate comment syntax
- 🔄 **Conversation Continuity**: Continue previous discussions with follow-up prompts

## 📦 Installation

### Manual Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/comet.el.git
   ```

2. Add to your Emacs configuration:
   ```elisp
   (add-to-list 'load-path "/path/to/comet.el")
   (require 'comet)
   ```

### Using `use-package`

```elisp
(use-package comet
  :load-path "/path/to/comet.el"
  :hook ((cider-repl-mode . comet-mode)
         (sly-mrepl-mode . comet-mode)
         (shell-mode . comet-mode)
         (ielm-mode . comet-mode)))
```

## 🔧 Configuration

### Backend Setup

Comet requires an LLM backend. Currently, **GPTEL** is the primary supported backend:

```elisp
;; Install GPTEL first
(use-package gptel
  :config
  (setq gptel-model "gpt-4-turbo"
        gptel-api-key "your-api-key-here"))

;; Configure Comet to use GPTEL
(setq comet-default-backend 'gptel)
```

### Customization Options

```elisp
;; Comment formatting
(setq comet-insert-separator t)  ; Add separator before responses

;; Custom comment prefixes for specific modes
(add-to-list 'comet-comment-prefix-alist '(my-custom-mode . "//"))

;; Change default backend
(setq comet-default-backend 'gptel)
```

## 🚀 Usage

### Basic Commands

| Command | Keybinding | Description |
|---------|-----------|-------------|
| `comet-send-prompt` | `C-c C-a` | Send a prompt to the LLM |
| `comet-continue` | `C-c C-c` | Continue previous conversation |
| `comet-clear-session` | `C-c C-k` | Clear session history |
| `comet-show-session-history` | — | View conversation history |
| `comet-select-backend` | — | Switch LLM backend |

### Prefix Arguments

`comet-send-prompt` supports prefix arguments to control how responses are inserted:

| Prefix | Behavior | Example |
|--------|----------|---------|
| None | Insert as comment | `;;; Comet: your prompt\n;; response` |
| `C-u` | Insert raw text | `response` |
| `C-u C-u` | Evaluate in REPL | Sends response as input |

### Example Workflow

1. **In a Clojure REPL (CIDER)**:
   ```
   M-x cider-jack-in
   C-c C-a → "Write a function to reverse a vector"
   ```
   Result:
   ```clojure
   ;; -----------------------------------------------------------
   ;; Comet: Write a function to reverse a vector
   ;; (defn reverse-vec [v]
   ;;   (vec (reverse v)))
   ```

2. **In a Shell**:
   ```
   M-x shell
   C-c C-a → "List all files modified in the last 24 hours"
   ```
   Result:
   ```bash
   # -----------------------------------------------------------
   # Comet: List all files modified in the last 24 hours
   # find . -type f -mtime -1 -ls
   ```

3. **With Evaluation** (`C-u C-u`):
   ```
   C-u C-u C-c C-a → "date +%Y-%m-%d"
   ```
   The command is executed directly in the shell.

## 🎯 Supported REPL Modes

Comet automatically enables for:

- **CIDER** (Clojure): `cider-repl-mode`
- **SLY** (Common Lisp): `sly-mrepl-mode`
- **Geiser** (Scheme): `geiser-repl-mode`
- **Shell**: `shell-mode`
- **IELM** (Emacs Lisp): `ielm-mode`
- **Python**: `inferior-python-mode`

To enable for other `comint` modes:

```elisp
(add-hook 'your-repl-mode-hook #'comet-mode)
```

## 🧩 Architecture

### Session Context

Each REPL buffer maintains a buffer-local `comet-session` variable that stores:
- Conversation history
- Model context
- Session metadata

Sessions persist for the lifetime of the REPL buffer.

### Backend Abstraction

The `comet--send-to-backend` function provides a clean interface for LLM backends:

```elisp
(defun comet--send-to-backend (prompt callback)
  "Send PROMPT to backend and call CALLBACK with response.")
```

This design allows easy extension to support:
- Claude API
- OpenAI API
- Local LLMs (Ollama, LLaMA.cpp)
- Custom endpoints

## 🛠️ Development

### Project Structure

```
comet/
├── comet.el            # Main implementation
├── README.md           # Documentation
└── tests/
    └── comet-tests.el  # Test suite (coming soon)
```

### Contributing

Contributions are welcome! Areas for enhancement:

- [ ] Streaming response buffer
- [ ] Context-aware prompt templates
- [ ] Integration with Embark/Consult
- [ ] Claude API backend implementation
- [ ] Multi-turn conversation refinement
- [ ] Export session to markdown

## 📄 License

MIT License - see LICENSE file for details.

## 🙏 Acknowledgments

Inspired by:
- **GPTEL**: Emacs integration for GPT models
- **Comint**: The foundation of all Emacs REPL modes
- Modern AI-assisted development workflows

---

**Comet** — Making every REPL conversational. ✨
