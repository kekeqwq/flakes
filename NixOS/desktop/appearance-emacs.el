;;; appearance-emacs.el --- Follow the Linux desktop appearance -*- lexical-binding: t; -*-

(defun flakes-appearance-apply (&optional frame)
  "Apply the current Linux desktop palette without replacing Emacs."
  (let* ((file @STATE@)
         (target (file-symlink-p file))
         (flavor (if (and target (string-suffix-p "/light" target)) 'latte 'mocha)))
    (when (and target
               (or (daemonp) (display-graphic-p frame))
               (or (not (boundp 'catppuccin-flavor))
                   (not (eq catppuccin-flavor flavor))
                   (not (memq 'catppuccin custom-enabled-themes))))
      ;; An already-running server may have started before the new package
      ;; entered its load-path. The Nix-supplied .el is backward compatible.
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
           (signal (car err) (cdr err))))))))

(add-hook 'after-make-frame-functions #'flakes-appearance-apply)
