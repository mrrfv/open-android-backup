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
            # Set environment variables
            export OAB_COMPRESSION_LEVEL="5"
            export TMPDIR="/tmp"

            echo "🚀 Open Android Backup Nix shell ready!"
            echo ""
            echo "Available tools:"
            echo "  - adb (Android Debug Bridge)"
            echo "  - p7zip (compression/decompression)"
            echo "  - whiptail (dialog boxes)"
            echo "  - pv (progress viewer)"
            echo "  - srm (secure file deletion)"
            echo "  - zenity (GUI dialogs)"
            echo ""
            echo "Usage:"
            echo "  1. Enable USB debugging on your Android device"
            echo "  2. Run: ./backup.sh"
            echo ""
            echo "Environment variables for automation:"
            echo "  - unattended_mode=yes"
            echo "  - selected_action=Backup|Restore"
            echo "  - archive_path=<path>"
            echo "  - archive_password=<password>"
            echo "  - mode=Wired|Wireless"
            echo "  - export_method=tar|adb"
            echo ""

            # Check if adb is working
            if command -v adb >/dev/null 2>&1; then
              echo "✅ ADB is available"
            else
              echo "❌ ADB not found"
            fi

            # Check if device is connected
            if adb devices 2>/dev/null | grep -q "device$"; then
              echo "✅ Android device detected"
            else
              echo "⚠️  No Android device detected (make sure USB debugging is enabled)"
            fi
          '';
        };
      }
    );
}
