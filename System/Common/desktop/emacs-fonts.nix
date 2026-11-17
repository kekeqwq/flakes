{ ... }:
let
  fonts = import ./font-policy.nix;
in
{
  # Home Manager loads default.el after the user's init. Keep size/theme choices,
  # but give fresh machines and subsequent daemon frames the same font policy.
  myuser.hm.programs.emacs.extraConfig = ''
    (setq my/cjk-font-family "${fonts.cjkRegular}")
    (defun flakes-apply-desktop-fonts (&optional selected-frame)
      (dolist (frame (if (framep selected-frame) (list selected-frame) (frame-list)))
        (when (display-graphic-p frame)
          (set-face-attribute 'default frame :family "${fonts.latin}")
          (dolist (characters '(han cjk-misc bopomofo (#x3000 . #x303f) (#xff00 . #xffef)))
            (set-fontset-font t characters
                              (font-spec :family "${fonts.cjkRegular}") frame)))))
    (add-hook 'after-make-frame-functions #'flakes-apply-desktop-fonts)
    (add-hook 'enable-theme-functions #'flakes-apply-desktop-fonts t)
    (add-hook 'disable-theme-functions #'flakes-apply-desktop-fonts t)
    (flakes-apply-desktop-fonts)
  '';
}
