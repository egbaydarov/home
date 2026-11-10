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
    # Show C# auto-property fields "<X>k__BackingField" as "X", so watch
    # expressions on them parse.
    ./csharp-backing-field-names.patch
    # Absolute paths (/home/...) were treated as Windows-style /flags, so
    # `raddbg /path/to/exe` silently got no target.
    ./unix-absolute-target-path.patch
    # Step-into at launch: stop at main.main (Go) / <Main>$, Main (C#) instead
    # of the runtime's native `main`, which has no source; and stop after the
    # prologue (first statement) so locals and the call stack are valid.
    ./language-entry-points.patch
    # PTRACE_GETEVENTMSG writes an unsigned long into a 4-byte pid_t, smashing
    # the stack on every thread creation (crashes on Go / .NET programs).
    ./ptrace-geteventmsg-overflow.patch
    # DWARF 5 units sharing one .debug_addr (Go): honor DW_AT_addr_base inside
    # the table, otherwise every unit resolves the first unit's addresses.
    ./dwarf5-shared-offset-tables.patch
    # Target arguments kept their quote characters in argv ("hello world"
    # arrived with the quotes); split them like a shell on Linux.
    ./posix-target-arguments.patch
    # The FreeType rasterizer's bounds check ran on a wrapped unsigned offset, so
    # glyphs overhanging the atlas wrote 0xFF before it, corrupting unrelated
    # memory ("Fatal Allocation Failure" when showing source).
    ./freetype-raster-bounds.patch
    # Resolving ".." left the removed path segment linked in the list, so joining
    # it overflowed the output buffer.
    ./path-resolve-dots-unlink.patch
    # char_is_digit indexed a 128-entry table with any byte (UTF-8 in sources).
    ./char-is-digit-ascii.patch
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
