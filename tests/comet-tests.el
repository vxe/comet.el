;;; comet-tests.el --- Tests for comet.el -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;;; Commentary:

;; Test suite for Comet - LLM-assisted REPL interaction

;;; Code:

(require 'ert)
(require 'comet)

;;; Session Management Tests

(ert-deftest comet-test-init-session ()
  "Test that session initialization creates proper structure."
  (with-temp-buffer
    (comet-init-session)
    (should comet-session)
    (should (plist-get comet-session :created))
    (should (listp (plist-get comet-session :history)))
    (should (equal '() (plist-get comet-session :history)))))

(ert-deftest comet-test-add-to-session-history ()
  "Test adding entries to session history."
  (with-temp-buffer
    (comet-init-session)
    (comet-add-to-session-history "test prompt" "test response")
    (let ((history (plist-get comet-session :history)))
      (should (= 1 (length history)))
      (should (equal "test prompt" (plist-get (car history) :prompt)))
      (should (equal "test response" (plist-get (car history) :response))))))

;;; Comment Prefix Tests

(ert-deftest comet-test-comment-prefix-elisp ()
  "Test comment prefix detection for Emacs Lisp."
  (with-temp-buffer
    (emacs-lisp-mode)
    (should (equal ";;" (comet--get-comment-prefix)))))

(ert-deftest comet-test-comment-prefix-python ()
  "Test comment prefix detection for Python."
  (with-temp-buffer
    (python-mode)
    (should (equal "#" (comet--get-comment-prefix)))))

(ert-deftest comet-test-comment-prefix-default ()
  "Test comment prefix default fallback."
  (with-temp-buffer
    (fundamental-mode)
    (should (equal "#" (comet--get-comment-prefix)))))

;;; Response Formatting Tests

(ert-deftest comet-test-format-response-comment ()
  "Test response formatting as comment (default)."
  (with-temp-buffer
    (emacs-lisp-mode)
    (let ((comet-insert-separator nil)
          (result (comet--format-response "test" "response line" nil)))
      (should (string-match-p ";; Comet: test" result))
      (should (string-match-p ";; response line" result)))))

(ert-deftest comet-test-format-response-raw ()
  "Test response formatting as raw text (C-u prefix)."
  (let ((result (comet--format-response "test" "response" '(4))))
    (should (string-match-p "^\\s-*response" result))
    (should-not (string-match-p ";;" result))))

(ert-deftest comet-test-format-response-eval ()
  "Test response formatting for evaluation (C-u C-u prefix)."
  (let ((result (comet--format-response "test" "response" '(16))))
    (should (equal "response" result))))

;;; Integration Tests (require mock backend)

;; Note: These tests require a mock backend to avoid actual API calls
;; Future enhancement: Add mock backend for testing

(provide 'comet-tests)

;;; comet-tests.el ends here
