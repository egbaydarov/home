{ lib, ... }:
let
  hidden = names: lib.genAttrs (builtins.attrNames names) (id: {
    name = names.${id};
    noDisplay = true;
  });
in
{
  # Launcher entries to hide
  xdg.desktopEntries = hidden {
    qvidcap = "qvidcap";
    qv4l2 = "qv4l2";
    "org.gtk.gtk4.NodeEditor" = "GTK4 Node Editor";
    "org.gtk.WidgetFactory4" = "GTK4 Widget Factory";
    "org.gtk.PrintEditor4" = "GTK4 Print Editor";
    "org.gtk.Demo4" = "GTK4 Demo";
    nvim = "Neovim";
    nvidia-settings = "Nvidia X";
    nixos-manual = "NixOS Manual";
  };
}
