{ lib, ... }:
let
  browserTypes = [
    "text/html"
    "application/xhtml+xml"
    "application/x-extension-htm"
    "application/x-extension-html"
    "application/x-extension-shtml"
    "application/x-extension-xhtml"
    "application/x-extension-xht"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
    "x-scheme-handler/chrome"
    "x-scheme-handler/about"
    "x-scheme-handler/unknown"
  ];
in
{
  myuser.hm = {
    xdg.mimeApps = {
      enable = true;
      defaultApplications = lib.genAttrs browserTypes (_: [ "google-chrome.desktop" ]);
      associations.added = lib.genAttrs browserTypes (_: [ "google-chrome.desktop" ]);
    };
    xdg.configFile."mimeapps.list".force = true;
    # HM also installs a compatibility link at the pre-XDG location. The Deck
    # has an empty regular file there; manage both paths during migration.
    xdg.dataFile."applications/mimeapps.list".force = true;
  };
}
