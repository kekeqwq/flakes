{ config, pkgs, ... }:

let
  dutiConfig = pkgs.writeText "duti-config" ''
    # Default Browser: Safari
    com.apple.Safari http
    com.apple.Safari https
    com.apple.Safari html all
    com.apple.Safari htm all
    com.apple.Safari public.html all
    com.apple.Safari public.xhtml all

    # Default PDF: Preview
    com.apple.Preview pdf all
    com.apple.Preview com.adobe.pdf all

    # Default Image: ImageGlass
    com.duongdieuphap.imageglass png all
    com.duongdieuphap.imageglass jpg all
    com.duongdieuphap.imageglass jpeg all
    com.duongdieuphap.imageglass gif all
    com.duongdieuphap.imageglass webp all
    com.duongdieuphap.imageglass bmp all
    com.duongdieuphap.imageglass svg all
    com.duongdieuphap.imageglass heic all
    com.duongdieuphap.imageglass heif all
    com.duongdieuphap.imageglass avif all
    com.duongdieuphap.imageglass tiff all
    com.duongdieuphap.imageglass tif all
    com.duongdieuphap.imageglass ico all
    com.duongdieuphap.imageglass public.image all
    com.duongdieuphap.imageglass public.jpeg all
    com.duongdieuphap.imageglass public.png all
    com.duongdieuphap.imageglass com.compuserve.gif all
    com.duongdieuphap.imageglass com.microsoft.bmp all
    com.duongdieuphap.imageglass public.tiff all
    com.duongdieuphap.imageglass com.microsoft.ico all
    com.duongdieuphap.imageglass public.heic all
    com.duongdieuphap.imageglass public.heif all
    com.duongdieuphap.imageglass public.avif all
    com.duongdieuphap.imageglass public.svg-image all

    # Default Video: mpv
    io.mpv mp4 all
    io.mpv mkv all
    io.mpv mov all
    io.mpv avi all
    io.mpv webm all
    io.mpv flv all
    io.mpv wmv all
    io.mpv m4v all
    io.mpv ts all
    io.mpv rmvb all
    io.mpv 3gp all
    io.mpv mpeg all
    io.mpv mpg all
    io.mpv public.movie all
    io.mpv public.video all
    io.mpv public.avi all
    io.mpv public.mpeg all
    io.mpv public.mpeg-4 all
    io.mpv com.apple.quicktime-movie all
    io.mpv org.matroska.mkv all
    io.mpv io.mpv.webm all
    io.mpv com.apple.m4v-video all
    io.mpv com.adobe.flash.video all
  '';
in
{
  nix.settings.sandbox = "relaxed";
  myuser.name = "keke";
  myuser.users.home = /Users/keke;
  myuser.hm.home.stateVersion = "25.11";
  networking.hostName = "mba";
  system.stateVersion = 6;
  system.primaryUser = "keke";
  system.defaults = {
    screencapture = {
      location = "/tmp";
    };
    finder = {
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = false;
    };
    NSGlobalDomain = {
      _HIHideMenuBar = false;
      AppleTemperatureUnit = "Celsius";
      NSAutomaticSpellingCorrectionEnabled = false;
      InitialKeyRepeat = 11;
      KeyRepeat = 1;
    };
  };
  nix-homebrew = {
    enable = true;
    enableRosetta = false;
    user = config.myuser.name;
    autoMigrate = true;
  };
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "zap";
    };
    casks = [
      "anki"
      "baidunetdisk"
      "bilibili"
      "calibre"
      "discord"
      "google-chrome"
      "grok-bot"
      "hammerspoon"
      "karabiner-elements"
      "marginnote"
      "pikpak"
      "qq"
      "quarkclouddrive"
      "raycast"
      "snipaste"
      "surge"
      "volanta"
      "wechat"
    ];
  };
  system.activationScripts.postActivation.text = ''
    echo "Configuring default application handlers via duti..." >&2
    launchctl asuser "$(${pkgs.coreutils}/bin/id -u ${config.myuser.name})" sudo -u ${config.myuser.name} --set-home ${pkgs.duti}/bin/duti ${dutiConfig}
  '';
  fonts.packages = with pkgs; [
    nerd-fonts.symbols-only
  ];
  myuser.hm.programs.emacs = {
    enable = true;
    package = pkgs.emacs-head;
    extraPackages = epkgs: [
      epkgs.ghostel
    ];
  };
  environment.systemPackages = with pkgs; [
    _7zz
    antigravity-cli
    kikibridge
    kikieye
    kikinavmap
    iina
    mihomo
    typst
    git
    clang
    scrcpy
    cinny-desktop
    telegram-desktop
    ffmpeg
    wezterm
    mpv
    moonlight-qt
    duti
    # PR: https://github.com/NixOS/nixpkgs/pull/552646 (待 PR 合并后删除)
    localsend-cli
  ];
}
