_: {
  myuser.hm.programs.yazi.settings = {
    opener = {
      img = [
        {
          run = "qimgv %s";
          orphan = true;
          for = "linux";
        }
        {
          run = "localsend_app %s";
          orphan = true;
          for = "linux";
        }
      ];
      vid = [
        {
          run = "mpv %s";
          orphan = true;
          for = "linux";
        }
      ];
    };
    open.rules = [
      {
        mime = "image/*";
        use = "img";
      }
      {
        mime = "video/*";
        use = "vid";
      }
    ];
  };
}
