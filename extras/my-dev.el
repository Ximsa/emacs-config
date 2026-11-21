;;; my-dev.el --- Languages, REPLs and Git on top of Emacs Bedrock -*- lexical-binding: t; -*-
 
;;; Commentary:
;;
;; Put this file in ~/.emacs.d/extras/ and load it from init.el AFTER
;; Bedrock's base.el and dev.el:
;;
;;   (load-file (expand-file-name "extras/base.el" user-emacs-directory))
;;   (load-file (expand-file-name "extras/dev.el" user-emacs-directory))
;;   (load-file (expand-file-name "extras/my-dev.el" user-emacs-directory))
;;
;; Everything here uses the standard Emacs keybindings.  Keys marked
;; "(stock)" are the packages' own defaults, listed so you can find them.
 
;;; Code:
 
;;;; Package archives -------------------------------------------------
;; Several packages below (cider, julia-snail, eglot-jl, lua-mode, diff-hl)
;; live in MELPA.  add-to-list is a no-op if Bedrock already added it.
(with-eval-after-load 'package
  (add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t))
 
;;;; Encoding: UTF-8 everywhere -----------------------------------------
;; On Windows, Emacs defaults to the legacy code page (cp1252 on German
;; systems).  Text from Claude often contains characters outside it (❯,
;; arrows, emoji), so Emacs stops and asks "Select coding system" when
;; saving or sending it.  Using UTF-8 for files and processes avoids that.
(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8-unix)
(setq-default buffer-file-coding-system 'utf-8-unix)
(setq default-process-coding-system '(utf-8-unix . utf-8-unix))
 
;;;; Font and window size ----------------------------------------------
;; Font size in 1/10 pt: 140 = 14 pt.  Adjust to taste (120-180 is typical).
(set-face-attribute 'default nil :height 140)
;; Use JetBrains Mono (IntelliJ's font) when it's installed.
(when (find-font (font-spec :family "JetBrains Mono"))
  (set-face-attribute 'default nil :family "JetBrains Mono"))
;; Fallback fonts for symbols and emoji the main font lacks (e.g. the ❯
;; prompt in agent-shell, arrows, box drawing).  Without this, Emacs shows
;; such characters as a small box with their hex code.
(when (eq system-type 'windows-nt)
  (set-fontset-font t 'symbol "Segoe UI Symbol" nil 'append)
  (set-fontset-font t 'unicode "Segoe UI Symbol" nil 'append)
  (set-fontset-font t 'emoji "Segoe UI Emoji" nil 'prepend))
 
;; Start every Emacs window maximized.
(add-to-list 'default-frame-alist '(fullscreen . maximized))
 
;; Ultrawide monitor: when only one window is open, keep the text in a
;; centered column instead of stretching it to the screen edges.  As soon
;; as you split (C-x 3, Magit, a REPL, the agent), windows fill the width
;; normally, so the extra width is used for side-by-side panes.
(use-package perfect-margin
  :ensure t
  :custom
  (perfect-margin-visible-width 120)   ; width of the centered column, in characters
  (perfect-margin-hide-fringes nil)    ; keep fringes, yascroll draws there
  :config
  (perfect-margin-mode 1))
 
;; Scroll bar: hide the thin Windows scroll bar and draw a solid bar in
;; the right fringe instead (the strip right next to the text).
(scroll-bar-mode -1)
(add-to-list 'default-frame-alist '(vertical-scroll-bars . nil))
(use-package yascroll
  :ensure t
  :custom
  (yascroll:scroll-bar '(right-fringe))
  (yascroll:delay-to-hide nil)         ; always visible; e.g. 1.0 = hide after 1 s
  :config
  (global-yascroll-bar-mode 1))
;; To make the bar thicker, widen the right fringe (pixels):
;; (fringe-mode '(8 . 14))
 
;;;; Everyday editing defaults ------------------------------------------
;; Picked from Emacs 31's newcomers-presets theme (minus auto-closing
;; brackets).
(delete-selection-mode 1)   ; typing or pasting replaces the selected text
(repeat-mode 1)             ; e.g. C-x o o o cycles windows without C-x again
(save-place-mode 1)         ; reopen files where you left off
(context-menu-mode 1)       ; right-click menu with relevant actions
 
;;;; Jump to definition (all languages) -------------------------------
;; Keyboard:  M-.  go to definition      (stock)
;;            M-,  jump back             (stock)
;;            M-?  find references       (stock)
;; Mouse:     Ctrl+click a symbol to jump, like IntelliJ.
(global-unset-key (kbd "C-<down-mouse-1>"))   ; frees Ctrl+click (was buffer menu)
(global-set-key (kbd "C-<mouse-1>") #'xref-find-definitions-at-mouse)
;; Mouse "back" button (if your mouse has one) jumps back.
(global-set-key (kbd "<mouse-8>") #'xref-go-back)
(global-set-key (kbd "<mouse-9>") #'xref-go-forward)
 
;;;; Eglot (language server client, built in) -------------------------
(use-package eglot
  :custom
  (eglot-autoshutdown t)          ; stop servers when their last buffer closes
  (eglot-connect-timeout 120)     ; Julia's server is slow on first start
  (eglot-events-buffer-config '(:size 0))  ; less logging, faster
  :bind (:map eglot-mode-map
              ("C-c l r" . eglot-rename)
              ("C-c l a" . eglot-code-actions)
              ("C-c l f" . eglot-format-buffer)
              ("C-c l d" . flymake-show-buffer-diagnostics)))
 
;;;; Git ---------------------------------------------------------------
;; Magit is installed by Bedrock's dev.el (C-c g opens status).  Daily use:
;;   C-c g        status: see changes, stage with s, unstage with u
;;                (put the cursor on a hunk or select lines to stage part of it)
;;   c c          commit;  P p push;  F p pull
;;   l a          commit graph of all branches  (l b = local branches only)
;;   d r          diff a range, e.g. main..HEAD or two commit hashes
;;   RET          on a commit in the log: show its diff
;;   e            on a file: side-by-side diff (ediff), like IntelliJ
;;   C-c M-g      file-level actions for the current file (blame, log, ...)
(use-package magit
  :ensure t
  :bind (("C-c g" . magit-status)
         ("C-c G" . magit-file-dispatch))
  :custom
  (magit-diff-refine-hunk 'all)   ; word-level highlighting inside diffs
  (magit-log-section-commit-count 20)
  (ediff-window-setup-function #'ediff-setup-windows-plain) ; no extra frame
  (ediff-split-window-function #'split-window-horizontally)) ; side by side
 
;; Changed-line markers in the margin, like IntelliJ's gutter.
;;   C-x v [ / ]   previous / next change      C-x v =   show this hunk
;;   C-x v n       revert this hunk
(use-package diff-hl
  :ensure t
  :hook ((after-init . global-diff-hl-mode)
         (dired-mode . diff-hl-dired-mode)
         (magit-pre-refresh . diff-hl-magit-pre-refresh)
         (magit-post-refresh . diff-hl-magit-post-refresh))
  :config
  (diff-hl-flydiff-mode 1))       ; update markers as you type, not on save
 
;;;; Python --------------------------------------------------------------
;; Install a language server:  pip install basedpyright   (or: pyright)
;;   C-c C-p   start the REPL           (stock)
;;   C-c C-c   send buffer              (stock)
;;   C-c C-r   send region              (stock)
;;   C-M-x     send current function    (stock)
;;   C-c C-z   switch to the REPL       (stock)
(use-package python
  :hook (python-mode . eglot-ensure)
  :custom
  (python-shell-interpreter (if (eq system-type 'windows-nt) "python" "python3"))
  (python-indent-guess-indent-offset-verbose nil))
 
;;;; Lua -----------------------------------------------------------------
;; Install a language server:  lua-language-server  (package manager or GitHub)
;;   C-c C-z   start / show the Lua REPL
;;   C-c C-c   send buffer
;;   C-c C-r   send region
;;   C-M-x     send current function
;;   C-c C-e   send current line
(use-package lua-mode
  :ensure t
  :mode "\\.lua\\'"
  :hook (lua-mode . eglot-ensure)
  :custom
  (lua-default-application "lua")   ; or "luajit"
  (lua-indent-level 2)
  :bind (:map lua-mode-map
              ("C-c C-z" . lua-show-process-buffer)
              ("C-c C-c" . lua-send-buffer)
              ("C-c C-r" . lua-send-region)
              ("C-M-x"   . lua-send-defun)
              ("C-c C-e" . lua-send-current-line)))
 
;;;; Clojure -------------------------------------------------------------
;; Needs a JDK and the Clojure CLI (deps.edn) or Leiningen (project.clj).
;; CIDER provides the REPL *and* jump-to-definition (also into library jars).
;;   C-c M-j   start a REPL for this project ("jack in")   (stock)
;;   C-c C-k   load the whole buffer                       (stock)
;;   C-c C-e   eval the expression before the cursor        (stock)
;;   C-M-x     eval the current top-level form              (stock)
;;   C-c C-z   switch to the REPL                           (stock)
;;   C-c C-d d show docs for the symbol at point            (stock)
(use-package clojure-mode
  :ensure t)
 
(use-package cider
  :ensure t
  :hook (clojure-mode . cider-mode)
  :custom
  (cider-repl-display-help-banner nil)
  (cider-repl-pop-to-buffer-on-connect 'display-only) ; keep focus in your code
  (cider-save-file-on-load t)
  (cider-eval-result-duration 'change)) ; inline results stay until you edit
 
;; Optional: clojure-lsp adds static analysis (unused vars, rename across
;; files, find references without a running REPL).  Install clojure-lsp,
;; then uncomment.  CIDER still handles M-. while a REPL is connected.
;; (add-hook 'clojure-mode-hook #'eglot-ensure)
 
;;;; Julia ---------------------------------------------------------------
;; REPL keys (same on Windows and Linux):
;;   C-c C-z   start / switch to the REPL
;;   C-c C-k   send the whole file
;;   C-c C-c   send the current top-level block
;;   C-c C-r   send region
;;   C-c C-l   send current line
(use-package julia-mode
  :ensure t)
 
(if (eq system-type 'windows-nt)
    ;; Windows: julia-snail needs a Unix terminal, so use the plain REPL
    ;; that julia-mode provides (`inferior-julia') plus a few send commands.
    (progn
      (defun my/julia-process ()
        "Return the Julia REPL process, starting it if needed."
        (get-buffer-process
         (save-window-excursion (inferior-julia) (current-buffer))))
 
      (defun my/julia-repl ()
        "Start the Julia REPL or switch to it."
        (interactive)
        (pop-to-buffer (process-buffer (my/julia-process))))
 
      (defun my/julia-send-region (beg end)
        "Send the region to the Julia REPL.
The code goes through a temporary file and `include', so multi-line
blocks arrive intact."
        (interactive "r")
        (let ((file (make-temp-file "emacs-julia-" nil ".jl"
                                    (buffer-substring-no-properties beg end))))
          (comint-send-string
           (my/julia-process)
           (format "include(%s);\n" (prin1-to-string file)))
          (display-buffer (process-buffer (my/julia-process)))))
 
      (defun my/julia-send-file ()
        "Save the file and `include' it in the Julia REPL."
        (interactive)
        (save-buffer)
        (my/julia-send-region (point-min) (point-max)))
 
      (defun my/julia-send-block ()
        "Send the current top-level block (function, struct, ...)."
        (interactive)
        (save-excursion
          (end-of-defun)
          (let ((end (point)))
            (beginning-of-defun)
            (my/julia-send-region (point) end))))
 
      (defun my/julia-send-line ()
        "Send the current line."
        (interactive)
        (my/julia-send-region (line-beginning-position) (line-end-position)))
 
      (with-eval-after-load 'julia-mode
        (define-key julia-mode-map (kbd "C-c C-z") #'my/julia-repl)
        (define-key julia-mode-map (kbd "C-c C-k") #'my/julia-send-file)
        (define-key julia-mode-map (kbd "C-c C-c") #'my/julia-send-block)
        (define-key julia-mode-map (kbd "C-c C-r") #'my/julia-send-region)
        (define-key julia-mode-map (kbd "C-c C-l") #'my/julia-send-line)))
 
  ;; Linux / macOS: julia-snail, a richer REPL integration (inline plots,
  ;; completion from the running session).  Runs inside Eat, a terminal
  ;; written in Elisp.
  (use-package eat
    :ensure t)
  (use-package julia-snail
    :ensure t
    :after eat
    :hook (julia-mode . julia-snail-mode)
    :custom
    (julia-snail-terminal-type :eat)
    (julia-snail-multimedia-enable t)))
 
;; Language server for Julia: eglot-jl installs and runs LanguageServer.jl
;; for you.  The first start downloads and indexes packages and can take a
;; few minutes; later starts are much faster.
(use-package eglot-jl
  :ensure t
  :defer t)
 
(defun my/julia-eglot ()
  "Register the Julia language server with Eglot, then start it."
  (eglot-jl-init)
  (eglot-ensure))
(add-hook 'julia-mode-hook #'my/julia-eglot)
 
;;;; Agentic coding ----------------------------------------------------
;; agent-shell: a native Emacs chat buffer for coding agents (Claude,
;; Codex, Gemini CLI, Goose, ...) via the Agent Client Protocol.  The
;; buffer is ordinary text, so normal search, copy and movement work, and
;; it needs no terminal emulator, so it works on native Windows.
;;
;; One-time setup (PowerShell; needs Node.js):
;;   npm install -g @agentclientprotocol/claude-agent-acp
;;   claude        <- run once to log in with your Claude subscription
;;
;;   C-c c a   start an agent (asks which one)
;; Review what the agent changed with Magit (C-c g), like any other change.
(use-package agent-shell
  :ensure t
  :bind ("C-c c a" . agent-shell)
  :config
  ;; Use your Claude subscription login instead of an API key.
  (setq agent-shell-anthropic-authentication
        (agent-shell-anthropic-make-authentication :login t)))
 
(provide 'my-dev)
;;; my-dev.el ends here
 
