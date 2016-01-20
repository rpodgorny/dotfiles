(require 'package)
(package-initialize)

(add-to-list 'package-archives '("org" . "http://orgmode.org/elpa/"))
(add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/"))
(add-to-list 'package-archives '("melpa-stable" . "http://stable.melpa.org/packages/"))

(if (not (package-installed-p 'use-package))
  (progn
    (package-refresh-contents)
    (package-install 'use-package)
  )
)

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

(global-auto-revert-mode t)
(desktop-save-mode 1)
(delete-selection-mode t)
(show-paren-mode t)
(which-function-mode t)

(menu-bar-mode -1)
(global-linum-mode 1)

(when window-system
  (scroll-bar-mode -1)
  (tool-bar-mode -1)
)

(setq scroll-step 1)
(setq scroll-conservatively 10000)
(setq auto-window-vscroll nil)
(setq scroll-margin 5)

(defalias 'yes-or-no-p 'y-or-n-p)

(global-set-key (kbd "M-o") 'other-window)
(global-set-key (kbd "C-c C-g") 'goto-line)

;(use-package evil)
;(require 'evil)
;(evil-mode t)

;(use-package solarized-theme)
;(load-theme 'solarized-dark t)
(use-package spacemacs-theme)
(load-theme 'spacemacs-dark t)

(semantic-mode 1)

(use-package saveplace
  :init (setq-default save-place t)
)

(use-package helm
  :diminish helm-mode
  :init (helm-mode 1)
  :config
    (require 'helm-config)
    (setq helm-split-window-in-side-p t)
    (setq helm-ff-file-name-history-use-recentf t)
	(helm-push-mark-mode 1)
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
    ("C-c <SPC>" . helm-all-mark-rings)
  )
)

(use-package helm-ag
  :defer t
;;  :init
;;  (setq helm-ag-fuzzy-match t)
  :config
    (use-package ag)
    (setq helm-ag-base-command "ag --smart-case --nocolor --nogroup")
    (setq helm-ag-insert-at-point 'symbol)
    (add-hook 'helm-ag-mode-hook (lambda () (grep-mode)))
)

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
                   helm-source-recentf
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
    (setq guide-key/popup-window-position 'bottom)
)

;(use-package smart-tabs-mode)
;(smart-tabs-insinuate 'c 'javascript 'python)

(use-package projectile
  :diminish projectile-mode
  :config
    (projectile-global-mode)
)

;(use-package auto-complete)
;(global-auto-complete-mode)
;(setq ac-show-menu-immediately-on-auto-complete t)

;(use-package company)
;(global-company-mode)

;(use-package flycheck)
;(global-flycheck-mode)

(use-package magit)

(use-package elpy
  :commands (eply-enable)
)

(use-package whitespace
  :diminish whitespace-mode
  :config
    (setq whitespace-line-column 80)
    (setq whitespace-style '(face trailing newline))
    (add-hook 'prog-mode-hook 'whitespace-mode)
)

(add-hook 'python-mode-hook
  (lambda ()
    (setq indent-tabs-mode t)
    (setq tab-width 4)
    (setq python-indent-offset 4)
  )
)

;(autoload 'jedi:setup "jedi" nil t)
;(add-hook 'python-mode-hook 'jedi:setup)
;(setq jedi:setup-keys t)
;(setq jedi:complete-on-dot t)

(use-package rainbow-mode
  :defer t
;;  :diminish rainbow-mode
)

(use-package smart-mode-line
  :config
    (setq sml/no-confirm-load-theme t)
    (sml/setup)
)

(use-package pkgbuild-mode
  :defer t
  :config (setq auto-mode-alist (append '(("/PKGBUILD$" . pkgbuild-mode)) auto-mode-alist))
)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   (quote
	("3c83b3676d796422704082049fc38b6966bcad960f896669dfc21a7a37a748fa" "fa2b58bb98b62c3b8cf3b6f02f058ef7827a8e497125de0254f56e373abee088" "bffa9739ce0752a37d9b1eee78fc00ba159748f50dc328af4be661484848e476" "d677ef584c6dfc0697901a44b885cc18e206f05114c8a3b7fde674fce6180879" "a8245b7cc985a0610d71f9852e9f2767ad1b852c2bdea6f4aadc12cce9c4d6d0" "8aebf25556399b58091e533e455dd50a6a9cba958cc4ebb0aab175863c25b9a4" default)))
 '(indent-tabs-mode t))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

