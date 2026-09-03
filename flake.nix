{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { 
    self, 
    nixpkgs,
    ... 
  }: 
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    depends = with pkgs; [
      libpng
      vulkan-loader
      freetype
      pipewire
      libx11
      stdenv.cc.cc.lib
      lilv
      zstd
      ncurses
    ];
    version = "0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1-alpha-beta-gamma-delta";

    llvm-and-stuff = pkgs.fetchurl { 
      # Unofficial link. the actual library is unobtainable (custom format archive)
      url = "https://ubq323.website/files/libseptabee-jit-runtime.so";
      sha256 = "sha256-utsRjtNDr0CiVDeS7974jjMXPz/GmYC6GIVrI80y0hM=";
    };

    septabee-pkg = pkgs.stdenv.mkDerivation {
        name = "septabee-${version}";
        version = version;
        src = pkgs.fetchurl {
          url = "https://septabee.nekoweb.org/important_stuff/SEPTABEE_DOWNLOADS/version_B/septabee_linux_B_T1.7z";
          sha256 = "sha256-JlWmeDnMTjBNwLTADvSswbtfhJK6t1bu0xHkmBgLtvA=";
        };

        nativeBuildInputs = with pkgs; [
          p7zip
          autoPatchelfHook
          makeWrapper
        ];

        buildInputs = depends;

        unpackPhase = ''
          runHook preUnpack
          7z x "$src"
          runHook postUnpack
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p "$out/bin" "$out/lib" # "exec" "$out/lib/llvm-stuffs/abi-8"
          cp -r ./linux/* "$out/bin/"
          install -Dm755 "${llvm-and-stuff}" \
            "$out/lib/llvm-stuffs/abi-8/libseptabee-jit-runtime.so"
          runHook postInstall
        '';

        postFixup = ''
          wrapProgram "$out/bin/septabee" \
            --chdir "$out" \
            --run "
              data_home=\"\''\${XDG_DATA_HOME:-\$HOME/.local/share}\"
              abi_dir=\"\$data_home/Septabee/llvm-stuffs/abi-8\"

              mkdir -p \"\$abi_dir\"

              ln -sfn \
                \"$out/lib/llvm-stuffs/abi-8/libseptabee-jit-runtime.so\" \
                \"\$abi_dir/libseptabee-jit-runtime.so\"
            "
        '';
    };
  in
  {
    packages.${system} = {
      default = septabee-pkg;
    };
    
    nixosModules.${system}.default = { ... }: {
      security.wrappers.septabee = {
        owner = "root";
        group = "root";
        permissions = "u-rwx,g=rx,o=rx";
        capabilities = "cap_sys_nice+ep";
        source = "${septabee-pkg}/bin/septabee";
      };

      security.wrappers.septabee-sounds = {
        owner = "root";
        group = "root";
        permissions = "u-rwx,g=rx,o=rx";
        capabilities = "cap_sys_nice+ep";
        source = "${septabee-pkg}/bin/septabee-sounds";
      };
    };
  };
}
