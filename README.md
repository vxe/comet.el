# 🌠 Comet.el

> *Conversational intelligence for every REPL*

**Comet** is an Emacs extension that brings LLM-assisted interaction to any `comint`-derived REPL, including CIDER, SLY, Shell, IELM, and more.

## ✨ Features

- 🎯 **Universal REPL Integration**: Works with any `comint`-based REPL mode
- 🔀 **Smart Provider Switching**: Auto-discovers LLM providers from `~/.authinfo` and lets you switch with one command
- 🧠 **Session Context**: Maintains conversation history per REPL buffer
- 🔌 **Backend Agnostic**: Abstracted interface supports multiple LLM backends (GPTEL, Claude API, etc.)
- ⌨️ **Flexible Input Modes**: Insert as comment, raw text, or evaluate directly
- 📝 **Smart Comment Formatting**: Auto-detects language-appropriate comment syntax
- 🔄 **Conversation Continuity**: Continue previous discussions with follow-up prompts

## ⚡ Quick Start

1. **Install gptel** (if not already installed):
   ```elisp
   M-x package-install RET gptel RET
   ```

2. **Set up API keys in `~/.authinfo`** (add one or more providers):
   ```authinfo
   machine api.openai.com login apikey password YOUR-OPENAI-API-KEY-HERE
   machine api.anthropic.com login apikey password YOUR-ANTHROPIC-KEY-HERE
   ```

3. **Install Comet** (manual for now):
   ```bash
   git clone https://github.com/yourusername/comet.el.git
   ```

4. **Load Comet**:
   ```elisp
   (add-to-list 'load-path "/path/to/comet.el")
   (require 'comet)
   ```

5. **Use in any REPL**:
   - Start your REPL (e.g., `M-x cider-jack-in`, `M-x shell`)
   - Press `C-c C-a` and type your prompt!
   - Press `C-c C-s` to switch providers anytime!

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

Comet requires an LLM backend. Currently, **GPTEL** is the primary supported backend.

#### Step 1: Install GPTEL

```elisp
;; Install GPTEL (available on NonGNU ELPA)
(use-package gptel
  :ensure t)
```

#### Step 2: Configure API Keys (Recommended: `.authinfo`)

Comet uses gptel's configuration, which **by default reads API keys from `~/.authinfo`** (the secure method).

Add your API keys to `~/.authinfo`:

```authinfo
machine api.openai.com login apikey password YOUR-OPENAI-API-KEY-HERE
machine api.anthropic.com login apikey password YOUR-ANTHROPIC-API-KEY-HERE
```

**Alternative**: Set API key directly in Emacs config (less secure):

```elisp
(use-package gptel
  :ensure t
  :config
  (setq gptel-api-key "your-api-key-here"))
```

#### Step 3: (Optional) Configure Backend

ChatGPT (OpenAI) is configured by default. To use other backends:

**Claude/Anthropic:**
```elisp
;; Register Claude backend
(gptel-make-anthropic "Claude"
  :stream t
  :key 'gptel-api-key)  ; Uses authinfo by default

;; Set as default for both gptel and Comet
(setq gptel-backend (gptel-make-anthropic "Claude"
                      :stream t
                      :key 'gptel-api-key)
      gptel-model 'claude-3-5-sonnet-20241022)
```

**Ollama (Local):**
```elisp
;; Set Ollama as default backend
(setq gptel-backend (gptel-make-ollama "Ollama"
                      :host "localhost:11434"
                      :stream t
                      :models '(mistral:latest llama3:latest))
      gptel-model 'mistral:latest)
```

**Other backends**: See [gptel documentation](https://github.com/karthink/gptel#setup) for Gemini, Groq, Azure, local models, and more.

**Note**: Comet uses the `gptel-request` API and inherits all gptel configuration (backends, models, API keys).

### Security: Using `.authinfo` for API Keys

Comet (via gptel) **reads API keys from `~/.authinfo` by default**. This is the recommended approach for security.

#### Setting up `.authinfo`

Create or edit `~/.authinfo` (or `~/.authinfo.gpg` for encryption):

```authinfo
machine api.openai.com login apikey password sk-proj-YOUR-KEY-HERE
machine api.anthropic.com login apikey password sk-ant-YOUR-KEY-HERE
```

**Important**:
- Set proper permissions: `chmod 600 ~/.authinfo`
- For encryption: Use `~/.authinfo.gpg` (Emacs will decrypt automatically)
- Each line format: `machine HOSTNAME login apikey password YOUR-API-KEY`

#### Supported Providers

| Provider | Hostname | Example |
|----------|----------|---------|
| OpenAI | `api.openai.com` | `machine api.openai.com login apikey password sk-proj-...` |
| Anthropic | `api.anthropic.com` | `machine api.anthropic.com login apikey password sk-ant-...` |
| Groq | `api.groq.com` | `machine api.groq.com login apikey password gsk_...` |
| Ollama | (local) | No key needed |

See [gptel authinfo documentation](https://github.com/karthink/gptel#optional-securing-api-keys-with-authinfo) for more providers.

### Customization Options

```elisp
;; Backend selection
(setq comet-default-backend 'gptel)  ; Default: 'gptel

;; System message sent to the LLM
(setq comet-system-message
      "You are a helpful AI assistant for a REPL environment.")

;; Comment formatting
(setq comet-insert-separator t)  ; Add separator line before responses

;; Enable streaming responses (if supported by backend)
(setq comet-use-stream nil)      ; Default: nil

;; Custom comment prefixes for specific modes
(add-to-list 'comet-comment-prefix-alist '(my-custom-mode . "//"))
```

#### Available Customization Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `comet-default-backend` | `'gptel` | LLM backend to use |
| `comet-system-message` | (predefined) | System prompt for the LLM |
| `comet-insert-separator` | `t` | Insert separator before responses |
| `comet-use-stream` | `nil` | Enable streaming responses |
| `comet-comment-prefix-alist` | (predefined) | Mode-specific comment prefixes |

## 🚀 Usage

### Basic Commands

| Command | Keybinding | Description |
|---------|-----------|-------------|
| `comet-send-prompt` | `C-c C-a` | Send a prompt to the LLM |
| `comet-switch-provider` | `C-c C-s` | **Switch LLM provider/model** |
| `comet-continue` | `C-c C-c` | Continue previous conversation |
| `comet-clear-session` | `C-c C-k` | Clear session history |
| `comet-show-session-history` | — | View conversation history |

### Switching Providers

**`comet-switch-provider` (`C-c C-s`)** is the easiest way to change your LLM provider:

1. **Auto-discovers** providers you have configured in `~/.authinfo`
2. Shows a **completing-read menu** with available providers
3. Lets you select a **specific model** from that provider
4. **Persists the selection** for all subsequent Comet interactions

**Example:**
```
C-c C-s  → Shows: [OpenAI, Anthropic, Groq]
         → Select: Anthropic
         → Shows: [claude-3-5-sonnet-20241022, claude-3-5-haiku-20241022, ...]
         → Select: claude-3-5-sonnet-20241022
         → Message: "Comet switched to Anthropic (claude-3-5-sonnet-20241022)"
```

**Supported Providers:**
- **OpenAI** (GPT-4, GPT-3.5)
- **Anthropic** (Claude 3.5 Sonnet, Claude 3 Opus)
- **Groq** (Llama 3, Mixtral, Gemma)
- **Gemini** (Gemini 1.5 Flash/Pro, 2.0 Flash)
- **Ollama** (Local models - no API key needed)

The switcher automatically registers backends if they're not already configured!

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

#### GPTEL Integration

Comet uses GPTEL's programmatic `gptel-request` API:

```elisp
(gptel-request prompt
  :system comet-system-message
  :stream comet-use-stream
  :callback (lambda (response info)
              ;; response is a string if successful
              ;; info is a plist with :status, :buffer, etc.
              ...))
```

The callback receives:
- `response`: String (success), `nil` (error), or `'abort` (aborted)
- `info`: Plist with `:status`, `:buffer`, `:position`, `:context`

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
