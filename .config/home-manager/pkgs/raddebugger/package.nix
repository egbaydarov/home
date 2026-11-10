# Based on https://github.com/NixOS/nixpkgs/pull/569274, pinned to upstream master.
{
  lib,
  clangStdenv,
  fetchFromGitHub,
  bash,
  pkg-config,
  llvmPackages,
  freetype,
  libx11,
  libxext,
  libxfixes,
  libxrandr,
  libglvnd,
  makeWrapper,
  zenity,
  makeDesktopItem,
  copyDesktopItems,
}:

clangStdenv.mkDerivation (finalAttrs: {
  pname = "raddebugger";
  version = "0.9.29-alpha-unstable-2026-11-04";

  strictDeps = true;
  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "EpicGames";
    repo = "raddebugger";
    rev = "5b0d5f67a46af5fffa52322e95a116dabf393103";
    hash = "sha256-fmFGAI2MCvvWAJ1GgmQ3rZOw5ocU+FzRpYSQeUH/z0o=";
  };

  nativeBuildInputs = [
    bash
    pkg-config
    llvmPackages.bintools # llvm-ar
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = [
    freetype
    libx11
    libxext
    libxfixes
    libxrandr
    libglvnd # libGL + libEGL
  ];

  # The codebase relies on its own flags; nixpkgs hardening only breaks things.
  hardeningDisable = [ "all" ];

  patches = [
    # Name procedures whose DWARF definition only points at a declaration via
    # DW_AT_specification / DW_AT_abstract_origin (.NET NativeAOT, C++ methods).
    ./dwarf-specification-names.patch
  ];

  postPatch = ''
    patchShebangs build.sh
  '';

  buildPhase = ''
    runHook preBuild
    ./build.sh clang release raddbg radbin
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 -t "$out/bin" build/{raddbg,radbin}
    install -Dm644 data/logo.png "$out/share/icons/hicolor/256x256/apps/raddbg.png"
    runHook postInstall
  '';

  # A debugger is easier to debug with its own symbols.
  dontStrip = true;

  postFixup = ''
    for prog in "$out/bin/"*; do
      wrapProgram "$prog" --prefix PATH : "${lib.makeBinPath [ zenity llvmPackages.libllvm ]}"
    done
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "raddbg";
      desktopName = "RAD Debugger";
      genericName = "Debugger";
      comment = "Graphical debugger";
      icon = "raddbg";
      exec = "raddbg %U";
      terminal = false;
      categories = [ "Development" "Debugger" ];
      startupNotify = true;
      startupWMClass = "RADDBG";
    })
  ];

  meta = {
    homepage = "https://github.com/EpicGames/raddebugger";
    description = "Native, user-mode, multi-process, graphical debugger";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "raddbg";
  };
})
