{ lib, fetchzip }:
let
  version = "1.1";
in
fetchzip {
  name = "style-detector";
  url = "https://gitlab.com/haveagoodtime/style-detector/uploads/72ac6dc64942b308bee3be24083a1585/style-detector.zip";
  sha256 = "sha256-Hr4Q86aCnUfjF2E32VwLPY5iHeqMFZ3iIY4FzuZXPgM=";
  stripRoot = false;
  postFetch = ''
    # mkdir $out
    # unzip $downloadedFile -d $out/
  '';
  meta = with lib; {
    description = ''
      Detect the current theme of macos and execute the command.
    '';
    homepage = "https://gitlab.com/haveagoodtime/style-detector";
    platforms = platforms.all;
    maintainers = with maintainers; [ self ];
  };
}
