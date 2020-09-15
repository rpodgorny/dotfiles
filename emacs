; this is cut-n-pasted from libor, hopefully it improves something
(setq my-gc-threshold (* 64 1024 1024))
(setq gc-cons-threshold most-positive-fixnum)
(add-hook 'emacs-startup-hook
  (lambda () (setq gc-cons-threshold my-gc-threshold)))
(add-hook 'minibuffer-setup-hook
  (lambda () (setq gc-cons-threshold most-positive-fixnum)))
(add-hook 'minibuffer-exit-hook
  (lambda () (setq gc-cons-threshold my-gc-threshold)))


(require 'package)
(package-initialize)

(add-to-list 'package-archives '("org" . "http://orgmode.org/elpa/"))
(add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/"))
(add-to-list 'package-archives '("melpa-stable" . "http://stable.melpa.org/packages/"))

(if (not (package-installed-p 'use-package))
  (progn
    (package-refresh-contents)
    (package-install 'use-package)))

(eval-when-compile (require 'use-package))
(setq use-package-always-ensure t)

;(setq package-enable-at-startup nil)
;(package-initialize)

; not working?
(setq-default indent-tabs-mode t)
(setq indent-tabs-mode t)
(setq-default tab-width 4)
(setq tab-width 4)
(setq-default indent-line-function 'insert-tab)
(defvaralias 'c-basic-offset 'tab-width)
(defvaralias 'cperl-indent-level 'tab-width)
(defvaralias 'python-indent-offset 'tab-width)

(setq inhibit-startup-message t)
(setq initial-scratch-message nil)
(setq make-backup-files nil)
(setq auto-save-default nil)
(setq delete-auto-save-files t)
(setq column-number-mode t)
(setq vc-diff-switches "-u")
(setq echo-keystrokes 0.1)
(setq use-dialog-box nil)
(setq compilation-always-kill t)
(setq compilation-scroll-output 'first-error)

(global-auto-revert-mode t)
(desktop-save-mode 1)
(delete-selection-mode t)
(show-paren-mode t)
(which-function-mode t)

(menu-bar-mode -1)
;(global-linum-mode 1)

(when (display-graphic-p)
  (scroll-bar-mode -1)
  (tool-bar-mode -1)
  ;(set-frame-font "mononoki-12")
  (set-frame-font "-*-terminus-bold-*-*-*-18-*-*-*-*-*-iso10646-1")
  ;(set-face-attribute 'default nil :family "Terminus" :weight 'bold :height 120)
)

(setq scroll-step 1)
(setq scroll-conservatively 10000)
(setq auto-window-vscroll nil)
(setq scroll-margin 5)

(defalias 'yes-or-no-p 'y-or-n-p)

(defadvice kill-ring-save (before slick-copy activate compile)
  "When called interactively with no active region, copy a single line instead."
  (interactive
   (if mark-active (list (region-beginning) (region-end))
     (message "Copied line")
     (list (line-beginning-position)
           (line-beginning-position 2)))))

(defadvice kill-region (before slick-cut activate compile)
  "When called interactively with no active region, kill a single line instead."
  (interactive
   (if mark-active (list (region-beginning) (region-end))
     (list (line-beginning-position)
           (line-beginning-position 2)))))

(global-set-key (kbd "M-o") 'other-window)
(global-set-key (kbd "C-:") 'goto-line)
(global-set-key (kbd "C-x C-k") 'kill-this-buffer)

(use-package afternoon-theme)
(load-theme 'afternoon t)

(semantic-mode 1)

(use-package saveplace
  :init (setq-default save-place t))

(use-package expand-region
  :bind (("C-=" . er/expand-region)))

(use-package dtrt-indent
  :defer t)

(use-package helm
  :diminish helm-mode
  :init (helm-mode 1)
  :config
    (require 'helm-config)
    (setq helm-split-window-in-side-p t)
    (setq helm-ff-file-name-history-use-recentf t)
	(define-key global-map [remap list-buffers] 'helm-buffers-list)
    (define-key helm-map (kbd "<tab>") 'helm-execute-persistent-action) ; rebind tab to do persistent action
    (define-key helm-map (kbd "C-i") 'helm-execute-persistent-action) ; make TAB works in terminal
    (define-key helm-map (kbd "C-z") 'helm-select-action) ; list actions using C-z
    (add-hook 'helm-grep-mode-hook (lambda () (grep-mode)))
  :bind (
    ("M-x" . helm-M-x)
    ("C-x b" . helm-buffers-list)  ;; same as helm-mini?
    ("C-x C-f" . helm-find-files)
    ("C-h a" . helm-apropos)
    ("C-." . helm-imenu-in-all-buffers)
    ("M-y" . helm-show-kill-ring)
    ("C-c h" . helm-command-prefix)
    ("C-c <SPC>" . helm-all-mark-rings)))

(use-package helm-ag
  :defer t
;;  :init
;;  (setq helm-ag-fuzzy-match t)
  :config
    (use-package ag)
    ;(setq helm-ag-base-command "ag --smart-case --nocolor --nogroup")
    (setq helm-ag-base-command "ag --smart-case --nocolor --nogroup --width=100")  ; added the --width param so minified js does not fuck the output
    (setq helm-ag-insert-at-point 'symbol)
    (add-hook 'helm-ag-mode-hook (lambda () (grep-mode))))

(global-set-key (kbd "M-g") (lambda ()
                              (interactive)
                              (helm-do-ag (projectile-project-root))))

(global-set-key (kbd "M-G") (lambda ()
                              (interactive)
                              (helm-do-ag (helm-current-directory))))

(use-package helm-projectile)
(setq helm-projectile-fuzzy-match nil)
(setq projectile-completion-system 'helm)
(helm-projectile-on)

(defun my-helm-projectile-buffers-list ()
  (interactive)
  (unless helm-source-buffers-list
    (setq helm-source-buffers-list
          (helm-make-source "Buffers" 'helm-source-buffers)))
  (helm :sources '(helm-source-buffers-list
                   helm-source-projectile-recentf-list
                   helm-source-projectile-files-list
                   ;helm-source-recentf
                   helm-source-buffer-not-found)
        :buffer "*helm buffers*"
        :keymap helm-buffer-map
        :truncate-lines helm-buffers-truncate-lines))

(global-set-key (kbd "C-c C-f") 'helm-projectile-find-file)
(global-set-key (kbd "C-x b") 'my-helm-projectile-buffers-list)

(use-package guide-key
  :diminish guide-key-mode
  :init (guide-key-mode 1)
  :config
    (setq guide-key/guide-key-sequence t)
    (setq guide-key/popup-window-position 'bottom))

(use-package projectile
  :diminish projectile-mode
  :config
    (projectile-global-mode))

(use-package whitespace
  :diminish whitespace-mode
  :config
    (setq whitespace-line-column 80)
    (setq whitespace-style '(face trailing newline))
    (add-hook 'prog-mode-hook 'whitespace-mode))

(use-package magit
  :defer t)

(use-package parinfer
  :ensure t
  :bind
  (("C-," . parinfer-toggle-mode))
  :init
  (progn
    (setq parinfer-extensions
          '(defaults       ; should be included.
            pretty-parens  ; different paren styles for different modes.
            ;;evil           ; If you use Evil.
            ;;lispy          ; If you use Lispy. With this extension, you should install Lispy and do not enable lispy-mode directly.
            paredit        ; Introduce some paredit commands.
            smart-tab      ; C-b & C-f jump positions and smart shift with tab & S-tab.
            smart-yank))   ; Yank behavior depend on mode.
    (add-hook 'clojure-mode-hook #'parinfer-mode)
    (add-hook 'emacs-lisp-mode-hook #'parinfer-mode)
    (add-hook 'common-lisp-mode-hook #'parinfer-mode)
    (add-hook 'scheme-mode-hook #'parinfer-mode)
    (add-hook 'lisp-mode-hook #'parinfer-mode)))

(use-package inf-clojure
  :ensure t)

(add-hook 'clojure-mode-hook #'inf-clojure-minor-mode)

(use-package elpy)
  ;;:bind (
    ;;("C-c C-c" . elpy-shell-send-top-statement)
    ;;("C-c C-e" . elpy-shell-send-statement)))


;(setq python-shell-interpreter "ipython"
;      python-shell-interpreter-args "-i --simple-prompt --pprint")

(add-hook 'python-mode-hook
          '(lambda ()
             (setq-local eldoc-mode nil)))

(add-hook 'python-mode-hook
  (lambda ()
    (setq indent-tabs-mode t)
    (setq tab-width 4)
    (setq python-indent-offset 4)
	(setq elpy-eldoc-show-current-function nil)
	(elpy-enable)
    ;;(local-set-key (kdb "C-c C-c") 'elpy-shell-send-top-statement)
    ;;(local-set-key (kbd "C-c C-e") 'elpy-shell-send-statement)
	(remove-hook 'elpy-modules 'elpy-module-yasnippet)))

(add-hook 'pascal-mode-hook
  (lambda ()
    (setq indent-tabs-mode nil)
	(setq tab-width 2)
	(setq pascal-indent-level 2)
	(setq pascal-auto-lineup nil)))

(add-hook 'opascal-mode-hook
  (lambda ()
    (setq indent-tabs-mode nil)
	(setq tab-width 2)
	(setq opascal-indent-level 2)
	(setq opascal-auto-lineup nil)))

;;(add-hook 'clojure-mode-hook
;;  (lambda ()
;;    (setq parinfer-mode t)))

;;(add-hook 'clojurescript-mode-hook
;;  (lambda ()
;;    (setq parinfer-mode t)))

;;(add-hook 'lisp-mode-hook
;;  (lambda ()
;;	(setq parinfer-mode t)))

(autoload 'opascal-mode "opascal")
(add-to-list 'auto-mode-alist
             '("\\.\\(pas\\|dpr\\|dpk\\)\\'" . opascal-mode))

(use-package rainbow-mode
  :defer t
  :diminish rainbow-mode)

(use-package rainbow-delimiters
  :defer t
  :diminish rainbow-delimiters-mode)

(use-package smart-mode-line
  :config
    (setq sml/no-confirm-load-theme t)
    (sml/setup))

(use-package pkgbuild-mode
  :defer t
  :config (setq auto-mode-alist (append '(("/PKGBUILD$" . pkgbuild-mode)) auto-mode-alist)))

(use-package dumb-jump
  :config (dumb-jump-mode))

; stolen from libor
(defun dos2unix ()
  (interactive)
  (set-buffer-file-coding-system 'unix))

(defun update-packages ()
  (interactive)
  (save-excursion
    (let ((package-menu-async nil))
	  (package-list-packages)
	  (package-menu-mark-upgrades)
      (package-menu-execute t)
	  (kill-buffer))))

(defun downcase-word-or-region ()
  (interactive)
  (if mark-active
    (downcase-region (region-beginning) (region-end))
    (call-interactively 'downcase-word)))

(defun upcase-word-or-region ()
  (interactive)
  (if mark-active
    (upcase-region (region-beginning) (region-end))
    (call-interactively 'upcase-word)))

; TODO: use dtrt-indent-mode - it seems to be smarter
; stolen from https://www.emacswiki.org/emacs/NoTabs
(defun infer-indentation-style ()
  (interactive)
  ;; if our source file uses tabs, we use tabs, if spaces spaces, and if neither, we use the current indent-tabs-mode
  (let ((space-count (how-many "^  " (point-min) (point-max)))
        (tab-count (how-many "^\t" (point-min) (point-max))))
    (if (> space-count tab-count) (setq indent-tabs-mode nil))
    (if (> tab-count space-count) (setq indent-tabs-mode t))))

(global-set-key (kbd "M-l") 'downcase-word-or-region)
(global-set-key (kbd "M-u") 'upcase-word-or-region)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   (quote
	("70403e220d6d7100bae7775b3334eddeb340ba9c37f4b39c189c2c29d458543b" "f78de13274781fbb6b01afd43327a4535438ebaeec91d93ebdbba1e3fba34d3c" "28ec8ccf6190f6a73812df9bc91df54ce1d6132f18b4c8fcc85d45298569eb53" "04dd0236a367865e591927a3810f178e8d33c372ad5bfef48b5ce90d4b476481" "3c83b3676d796422704082049fc38b6966bcad960f896669dfc21a7a37a748fa" "fa2b58bb98b62c3b8cf3b6f02f058ef7827a8e497125de0254f56e373abee088" "bffa9739ce0752a37d9b1eee78fc00ba159748f50dc328af4be661484848e476" "d677ef584c6dfc0697901a44b885cc18e206f05114c8a3b7fde674fce6180879" "a8245b7cc985a0610d71f9852e9f2767ad1b852c2bdea6f4aadc12cce9c4d6d0" "8aebf25556399b58091e533e455dd50a6a9cba958cc4ebb0aab175863c25b9a4" default)))
 '(indent-tabs-mode t)
 '(package-selected-packages
   (quote
	(inf-clojure dtrt-indent rg pipenv helpful smartparens avy darkokai-theme monokai-theme highlight-symbol parinfer smooth-scrolling ggtags package-utils ag use-package spacemacs-theme smart-mode-line rainbow-mode rainbow-delimiters pkgbuild-mode magit guide-key expand-region elpy dumb-jump))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

