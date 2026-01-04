{
  lib,
  fetchFromGitHub,
  fetchurl,
  fetchFromGitLab,
  runCommand,
}:
let
  # List of all the dependencies that get fetched via CPM during the configure phase
  # This was obtained by repeatedly running `nix build` and looking for
  # messages like these in the logs:
  # CPM: Adding package zstd@1.5.7 (v1.5.7 to /build/source/cpm_source_cache/zstd/dfd2e0b6e613dcf44911302708e636a8aee527d2)
  #
  # If we pass git into nativeBuildDependencies, then the build logs also tell us
  # the repository that CPM tries to download the sources from
  #
  # Dependencies names for CPM are case-sensitive.
  cpmDeps = [
    {
      name = "zstd";
      src = fetchFromGitHub {
        owner = "facebook";
        repo = "zstd";
        rev = "v1.5.7";
        hash = "sha256-tNFWIT9ydfozB8dWcmTMuZLCQmQudTFJIkSr0aG7S44=";
      };
    }
    {
      name = "ImGui";
      src = fetchFromGitHub {
        owner = "ocornut";
        repo = "imgui";
        rev = "v1.91.9b-docking";
        hash = "sha256-mQOJ6jCN+7VopgZ61yzaCnt4R1QLrW7+47xxMhFRHLQ=";
      };
    }
    {
      name = "nfd";
      src = fetchFromGitHub {
        owner = "btzy";
        repo = "nativefiledialog-extended";
        rev = "v1.2.1";
        hash = "sha256-GwT42lMZAAKSJpUJE6MYOpSLKUD5o9nSe9lcsoeXgJY=";
      };
    }
    {
      name = "PPQSort";
      src = fetchFromGitHub {
        owner = "GabTux";
        repo = "PPQSort";
        rev = "v1.0.5";
        hash = "sha256-EMZVI/uyzwX5637/rdZuMZoql5FTrsx0ESJMdLVDmfk=";
      };
    }
    {
      name = "capstone";
      src = fetchFromGitHub {
        owner = "capstone-engine";
        repo = "capstone";
        rev = "6.0.0-Alpha1";
        hash = "sha256-oKRu3P1inWueEMIpL0uI2ayCMHZ9FIVotil4sqwLqH4=";
      };
    }
    {
      # Transitive from PPQSort
      name = "PackageProject.cmake";
      src = fetchFromGitHub {
        owner = "TheLartians";
        repo = "PackageProject.cmake";
        rev = "v1.11.1";
        hash = "sha256-E7WZSYDlss5bidbiWL1uX41Oh6JxBRtfhYsFU19kzIw=";
      };
    }
    {
      name = "wayland-protocols";
      src = fetchFromGitLab {
        owner = "wayland";
        repo = "wayland-protocols";
        rev = "1.37";
        domain = "gitlab.freedesktop.org";
        hash = "sha256-ryyv1RZqpwev1UoXRlV8P1ujJUz4m3sR89iEPaLYSZ4=";
      };
    }
  ];
in
runCommand "cpm-dependencies" { } (
  lib.strings.concatMapStringsSep "\n" (dep: ''
    mkdir -p $out/${dep.name}
    cp --no-preserve=mode -r ${dep.src}/. $out/${dep.name}/
  '') cpmDeps
)
