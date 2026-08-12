{ config, pkgs, ... }:
{
  myuser.hm.home.packages = [ pkgs.starship ];
  myuser.hm.programs.fish = {
    enable = true;
    interactiveShellInit = ''
              set fish_greeting # Disable greeting
              starship init fish | source
              alias ls="exa"
              alias sc="screen /dev/cu.usbmodem5B162124901 9600"
              function switchscreen
          set deck "$HOME/Downloads/deck.kdl"

          if not test -f $deck
              echo "deck.kdl not found: $deck"
              return 1
          end

          if grep -qE '^[[:space:]]*off[[:space:]]*$' $deck
              sed -i 's/^[[:space:]]*off[[:space:]]*$/        \/\/ off/' $deck
              echo "eDP-1 disabled"
          else if grep -qE '^[[:space:]]*//[[:space:]]*off[[:space:]]*$' $deck
              sed -i 's/^[[:space:]]*\/\/[[:space:]]*off[[:space:]]*$/        off/' $deck
              echo "eDP-1 enabled"
          else
              echo "Cannot find eDP-1 off entry in deck.kdl"
              return 1
          end
      end
    '';
  };
}
