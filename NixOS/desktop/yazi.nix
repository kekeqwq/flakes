_: {
  myuser.hm.programs.yazi = {
    settings = {
      opener = {
        img = [
          {
            run = "qimgv %s";
            desc = "qimgv";
            orphan = true;
            for = "linux";
          }
        ];
        vid = [
          {
            run = "mpv %s";
            desc = "mpv";
            orphan = true;
            for = "linux";
          }
        ];
        send = [
          {
            run = "localsend_app %s";
            desc = "Send with LocalSend";
            orphan = true;
            for = "linux";
          }
        ];
      };
      # Keep a useful default action for each type; LocalSend is an additional
      # interactive action, not the default opener for arbitrary files.
      open.rules = [
        {
          mime = "folder/*";
          use = [
            "edit"
            "open"
            "reveal"
            "send"
          ];
        }
        {
          mime = "image/*";
          use = [
            "img"
            "reveal"
            "send"
          ];
        }
        {
          mime = "video/*";
          use = [
            "vid"
            "reveal"
            "send"
          ];
        }
        {
          mime = "audio/*";
          use = [
            "play"
            "reveal"
            "send"
          ];
        }
        {
          mime = "text/*";
          use = [
            "edit"
            "reveal"
            "send"
          ];
        }
        {
          mime = "application/{json,ndjson,javascript,wine-extension-ini}";
          use = [
            "edit"
            "reveal"
            "send"
          ];
        }
        {
          mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
          use = [
            "extract"
            "reveal"
            "send"
          ];
        }
        {
          mime = "inode/empty";
          use = [
            "edit"
            "reveal"
            "send"
          ];
        }
        # Remote files must be downloaded before they can be sent locally.
        {
          mime = "vfs/{absent,stale}";
          use = "download";
        }
        {
          mime = "trash/**";
          use = [
            "open"
            "trash"
            "send"
          ];
        }
        {
          url = "*";
          use = [
            "open"
            "reveal"
            "send"
          ];
        }
      ];
    };
    keymap.mgr.prepend_keymap = [
      {
        on = [
          "g"
          "s"
        ];
        run = "shell 'localsend_app %s' --orphan";
        desc = "Send selected files with LocalSend";
      }
    ];
  };
}
