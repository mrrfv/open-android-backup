{
  description = "Open Android Backup development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Core dependencies for open-android-backup
            p7zip                    # For compression/decompression
            android-tools            # Provides adb
            curl                     # For downloading files
            newt                     # Provides whiptail for dialogs
            pv                       # Progress viewer
            bc                       # Calculator for shell scripts
            srm                      # Secure file deletion (replaces secure-delete)
            zenity                   # GUI dialogs
            gnutar                   # GNU tar
            coreutils                # Essential utilities (ls, cp, mv, etc.)
            findutils                # find, xargs, etc.
            dos2unix                 # Convert line endings

            # Additional useful tools
            bash                     # Ensure we have bash
            wget                     # Alternative to curl
            unzip                    # For extracting archives
            file                     # File type detection
            which                    # Locate commands

            # Development tools (optional but useful)
            git                      # Version control
            tree                     # Directory structure visualization
          ];

          shellHook = ''
            echo "Open Android Backup Nix shell ready."
            echo ""
            echo "Usage:"
            echo "  1. Enable USB debugging on your Android device"
            echo "  2. Run: ./backup.sh"
            echo ""
            echo "For automation options and advanced usage, see README.md"
          '';
        };
      }
    );
}
