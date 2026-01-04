{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchFromGitLab,
  runCommand,
  fetchurl,
  coreutils,

  cmake,
  ninja,
  pkg-config,
  wayland-scanner,

  dbus,
  freetype,
  glfw,
  onetbb,

  withGtkFileSelector ? false,
  gtk3,

  withWayland ? stdenv.hostPlatform.isLinux,
  libglvnd,
  libxkbcommon,
  wayland,
  libffi,
}:

assert withGtkFileSelector -> stdenv.hostPlatform.isLinux;

let
  cpmDependencies = import ./cpm-dependencies.nix {
    inherit
      lib
      fetchFromGitHub
      fetchurl
      fetchFromGitLab
      runCommand
      ;
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = if withWayland then "tracy-wayland" else "tracy-glfw";
  version = "0.12.2";

  src = fetchFromGitHub {
    owner = "wolfpld";
    repo = "tracy";
    tag = "v${finalAttrs.version}";
    hash = "sha256-voHql8ETnrUMef14LYduKI+0LpdnCFsvpt8B6M/ZNmc=";
  };

  postUnpack =
    # Copy the CPM dependencies to a directory where it can patch them
    # Set a CPM flag to absolute path for each so it can find them
    # Replace PPQSort's CPM with a local copy so it doesn't download it
    ''
      cpm_deps=$(realpath cpm-deps)
      cp -r --no-preserve=mode ${cpmDependencies} $cpm_deps
      for dep in $cpm_deps/*; do
        appendToVar cmakeFlags -DCPM_$(basename $dep)_SOURCE=$dep
      done
      cp $sourceRoot/cmake/CPM.cmake $cpm_deps/PPQSort/cmake/CPM.cmake
    ''
    # Darwin's sandbox requires explicit write permissions for CPM to patch
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      chmod -R u+w $cpm_deps
    '';

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ wayland-scanner ]
  ++ lib.optionals stdenv.cc.isClang [ stdenv.cc.cc.libllvm ];

  buildInputs = [
    freetype
    libffi
    onetbb
  ]
  ++ lib.optionals (stdenv.hostPlatform.isLinux && withGtkFileSelector) [ gtk3 ]
  ++ lib.optionals (stdenv.hostPlatform.isLinux && !withGtkFileSelector) [ dbus ]
  ++ lib.optionals (stdenv.hostPlatform.isLinux && withWayland) [
    libglvnd
    libxkbcommon
    wayland
  ]
  ++ lib.optionals (stdenv.hostPlatform.isDarwin || (stdenv.hostPlatform.isLinux && !withWayland)) [
    glfw
  ];

  cmakeFlags = [
    (lib.cmakeBool "DOWNLOAD_CAPSTONE" false)
    (lib.cmakeBool "TRACY_STATIC" false)
    (lib.cmakeBool "CPM_LOCAL_PACKAGES_ONLY" true)
  ]
  ++ lib.optional (stdenv.hostPlatform.isLinux && withGtkFileSelector) "-DGTK_FILESELECTOR=ON"
  ++ lib.optional (stdenv.hostPlatform.isLinux && !withWayland) "-DLEGACY=on";

  env.NIX_CFLAGS_COMPILE = toString (lib.optional stdenv.hostPlatform.isLinux "-ltbb");

  dontUseCmakeBuildDir = true;

  # CPM_<package>_SOURCE flags prevent downloads but cause each of the sub-projects
  # to apply the same patches to the same source. The patch tool will return a
  # non-zero status, failing the build, even if configured to ignore patch re-application.
  #
  # The workaround is to first configure the profiler since it includes all of the
  # dependencies and then short-circuit the patch command for the remaining projects.
  postConfigure = ''
    cmake -B profiler/build -S profiler $cmakeFlags

    appendToVar cmakeFlags -DPATCH_EXECUTABLE=${coreutils}/bin/true
    cmake -B capture/build -S capture $cmakeFlags
    cmake -B csvexport/build -S csvexport $cmakeFlags
    cmake -B import/build -S import $cmakeFlags
    cmake -B update/build -S update $cmakeFlags
  '';

  postBuild = ''
    ninja -C capture/build
    ninja -C csvexport/build
    ninja -C import/build
    ninja -C profiler/build
    ninja -C update/build
  '';

  postInstall = ''
    install -D -m 0555 capture/build/tracy-capture -t $out/bin
    install -D -m 0555 csvexport/build/tracy-csvexport $out/bin
    install -D -m 0555 import/build/{tracy-import-chrome,tracy-import-fuchsia} -t $out/bin
    install -D -m 0555 profiler/build/tracy-profiler $out/bin/tracy
    install -D -m 0555 update/build/tracy-update -t $out/bin
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    substituteInPlace extra/desktop/tracy.desktop \
      --replace-fail Exec=/usr/bin/tracy Exec=tracy

    install -D -m 0444 extra/desktop/application-tracy.xml $out/share/mime/packages/application-tracy.xml
    install -D -m 0444 extra/desktop/tracy.desktop $out/share/applications/tracy.desktop
    install -D -m 0444 icon/application-tracy.svg $out/share/icons/hicolor/scalable/apps/application-tracy.svg
    install -D -m 0444 icon/icon.png $out/share/icons/hicolor/256x256/apps/tracy.png
    install -D -m 0444 icon/icon.svg $out/share/icons/hicolor/scalable/apps/tracy.svg
  '';

  meta = with lib; {
    description = "Real time, nanosecond resolution, remote telemetry frame profiler for games and other applications";
    homepage = "https://github.com/wolfpld/tracy";
    license = licenses.bsd3;
    mainProgram = "tracy";
    maintainers = with maintainers; [
      mpickering
      nagisa
    ];
    platforms = platforms.linux ++ lib.optionals (!withWayland) platforms.darwin;
  };
})
