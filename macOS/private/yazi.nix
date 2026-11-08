_: {
  myuser.hm.programs.yazi.settings = {
    opener.vid = [
      {
        run = "open -a IINA %s";
        orphan = true;
        for = "macos";
      }
    ];
    open.rules = [
      {
        mime = "video/*";
        use = "vid";
      }
    ];
  };
}
