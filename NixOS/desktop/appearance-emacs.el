;;; appearance-emacs.el --- Follow the Linux desktop appearance -*- lexical-binding: t; -*-

(require 'subr-x)

(defun flakes-appearance-apply (&optional frame)
  "Apply the current Linux desktop palette without replacing Emacs."
  (let* ((file @STATE@)
         (target (file-symlink-p file))
         (flavor (if (and target (string-suffix-p "/light" target)) 'latte 'mocha)))
    (when (and target (or (daemonp) (display-graphic-p frame)))
      (unless (and (boundp 'catppuccin-flavor)
                   (eq catppuccin-flavor flavor)
                   (memq 'catppuccin custom-enabled-themes)
                   (flakes-appearance-emacs-matches-p flavor))
        ;; The running server may predate the theme's addition to its load path.
        (add-to-list 'custom-theme-load-path @THEME_DIR@)
        (unless (featurep 'catppuccin-theme)
          (let ((load-path (cons @THEME_DIR@ load-path)))
            (load (expand-file-name "catppuccin-theme.el" @THEME_DIR@) nil 'nomessage)))
        (let ((previous custom-enabled-themes)
              (old-flavor catppuccin-flavor))
          (condition-case err
              (progn
                (setq catppuccin-flavor flavor)
                (catppuccin-reload)
                (dolist (theme previous)
                  (unless (eq theme 'catppuccin) (disable-theme theme))))
            (error
             (setq catppuccin-flavor old-flavor)
             (dolist (theme (reverse previous)) (load-theme theme t))
             (signal (car err) (cdr err))))))
      (unless (flakes-appearance-emacs-matches-p flavor)
        (error "An Emacs graphical frame did not apply %s" flavor))
      flavor)))

(defun flakes-appearance-emacs-matches-p (flavor)
  "Check the rendered default face on existing graphical frames."
  (let ((expected (if (eq flavor 'latte) "#eff1f5" "#1e1e2e")))
    (catch 'mismatch
      (dolist (frame (frame-list) t)
        (when (display-graphic-p frame)
          (let ((background (face-background 'default frame t)))
            (unless (and (stringp background) (string-equal-ignore-case background expected))
              (throw 'mismatch nil))))))))

(add-hook 'after-make-frame-functions #'flakes-appearance-apply)
