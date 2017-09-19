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

(when window-system
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

(use-package ivy
  :ensure t
  :diminish ivy-mode
  :init (ivy-mode 1)
  :config (setq ivy-use-virtual-buffers t
                ivy-virtual-abbreviate 'full
                ivy-height 20
                ivy-initial-inputs-alist nil  ;; no regexp by default
                ivy-re-builders-alist  ;; allow input not in order
                '((t . ivy--regex-ignore-order))))

(defun my-counsel-ag ()
  (interactive)
  (counsel-ag (if (use-region-p)
                (buffer-substring-no-properties (region-beginning) (region-end))
                (thing-at-point 'symbol t))))

(use-package counsel
  :bind (("M-x" . counsel-M-x)
         ("C-x C-f" . counsel-find-file)
         ("C-h a" . counsel-apropos)
         ("M-y" . counsel-yank-pop)
         ("M-G" . my-counsel-ag)))

;;(define-key counsel-find-file-map (kbd "C-l") 'counsel-up-directory)

(use-package projectile
  :diminish projectile-mode
  :init (setq projectile-enable-caching t)
        (projectile-global-mode)
  :config (setq projectile-completion-system 'ivy))

(use-package counsel-projectile
  :init (counsel-projectile-on)
  :config (setq counsel-projectile-ag-initial-input
            '(projectile-symbol-or-selection-at-point))
  :bind (("C-x C-p" . counsel-projectile-find-file)
         ("M-g" . counsel-projectile-ag)))

(defun my-swiper ()
  (interactive)
  (swiper (thing-at-point 'symbol t)))

(use-package swiper
  :bind (("C-s" . my-swiper)))

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

(use-package cider
  :defer t)

(use-package hy-mode
  :defer t)

(use-package elpy)

(setq python-shell-interpreter "ipython"
      python-shell-interpreter-args "-i --simple-prompt --pprint")

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
	(remove-hook 'elpy-modules 'elpy-module-yasnippet)))

(add-hook 'pascal-mode-hook
  (lambda ()
    (setq indent-tabs-mode nil)
	(setq tab-width 2)
	(setq pascal-indent-level 2)
	(setq pascal-auto-lineup nil)))

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
  (save-excursion
    (goto-char (point-min))
    (while (search-forward (string ?\C-m) nil t)
      (replace-match "" nil t))))

; yeah, i know, it sucks. but hey, it's my first function ever! ;-)
(defun update-packages ()
  (interactive)
  (save-excursion
    (let ((package-menu-async nil))
	  (package-list-packages)
	  (package-menu-mark-upgrades)
      (package-menu-execute t)
	  (kill-buffer))))

; well, this is the second one. i know, still sucky... ;-)
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
	(counsel swiper smartparens avy inf-clojure darkokai-theme monokai-theme highlight-symbol parinfer smooth-scrolling ivy ggtags cider package-utils ag use-package spacemacs-theme smart-mode-line rainbow-mode rainbow-delimiters pkgbuild-mode magit hy-mode guide-key expand-region elpy dumb-jump))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

