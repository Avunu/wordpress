{
  description = "FrankenPHP with latest PHP versions using nix2container and skopeo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, nix2container, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              phpCommonConfig = {
                embedSupport = true;
                ztsSupport = true;
                apxs2Support = false;
                systemdSupport = false;
                phpdbgSupport = false;
                cgiSupport = false;
                fpmSupport = false;
              };

              optimizePhp = phpPackage: (phpPackage.override final.phpCommonConfig).withExtensions 
                ({ all, ... }: with all; [
                  curl dom exif fileinfo gd iconv imagick intl
                  mbstring mysqli opcache openssl sodium xml zip
                ]);

              php81Optimized = final.optimizePhp prev.php81;
              php82Optimized = final.optimizePhp prev.php82;
              php83Optimized = final.optimizePhp prev.php83;

              buildWordpressPhp = { php, name }:
                let
                  busyboxWithApps = pkgs.busybox.override {
                    enableStatic = true;
                    enableAppletSymlinks = true;
                  };
                  image = nix2container.packages.${system}.nix2container.buildImage {
                    inherit name;
                    tag = "latest";
                    copyToRoot = pkgs.buildEnv {
                      name = "root";
                      paths = [
                        busyboxWithApps
                        pkgs.coreutils
                        pkgs.curl
                        pkgs.frankenphp
                        php
                        pkgs.cacert
                        pkgs.ghostscript
                        pkgs.libxml2
                        pkgs.mariadb.client
                        pkgs.unzip
                        (pkgs.writeTextFile {
                          name = "wp-config.php";
                          text = builtins.readFile ./wp-config.php;
                          destination = "/opt/wp-config.php";
                        })
                        (pkgs.writeScriptBin "docker-entrypoint.sh" (builtins.readFile ./docker-entrypoint.sh))
                        (pkgs.runCommand "shell-setup" {} ''
                          mkdir -p $out/bin
                          ln -s ${busyboxWithApps}/bin/sh $out/bin/sh
                        '')
                      ];
                      pathsToLink = [ "/bin" "/etc" "/lib" "/opt" "/usr" ];
                    };
                    config = {
                      Entrypoint = [ "/bin/docker-entrypoint.sh" ];
                      Cmd = [ "frankenphp" "php-server" "--root" "/var/www/html" "--listen" "0.0.0.0:80" ];
                      ExposedPorts = {
                        "80/tcp" = {};
                      };
                      Env = [
                        "WORDPRESS_SOURCE_URL=https://wordpress.org/latest.zip"
                        "WORDPRESS_DB_HOST=localhost"
                        "WORDPRESS_DB_USER=wordpress"
                        "WORDPRESS_DB_PASSWORD=wordpress"
                        "WORDPRESS_DB_NAME=wordpress"
                        "WORDPRESS_AUTH_KEY=key"
                        "WORDPRESS_SECURE_AUTH_KEY=key"
                        "WORDPRESS_LOGGED_IN_KEY=key"
                        "WORDPRESS_NONCE_KEY=key"
                        "WORDPRESS_AUTH_SALT=key"
                        "WORDPRESS_SECURE_AUTH_SALT=key"
                        "WORDPRESS_LOGGED_IN_SALT=key"
                        "WORDPRESS_NONCE_SALT=key"
                      ];
                    };
                  };
                in pkgs.buildPackages.runCommand "docker-image-${name}"
                  {
                    nativeBuildInputs = [ pkgs.buildPackages.skopeo pkgs.buildPackages.bubblewrap ];
                  }
                  ''
                    mkdir -p $out
                    # Create a fake /var/tmp directory for skopeo
                    mkdir -p $TMPDIR/fake-var/tmp
                    args=(--unshare-user --bind "$TMPDIR/fake-var" /var)
                    for dir in /*; do
                      args+=(--dev-bind "/$dir" "/$dir")
                    done
                    bwrap ''${args[@]} -- ${pkgs.lib.getExe image.copyTo} docker-archive:$out/${name}.tar
                    gzip $out/${name}.tar
                    echo "${name}" > $out/image-name
                  '';
            })
          ];
        };
      in {
        packages = {
          wordpress-php81 = pkgs.buildWordpressPhp {
            php = pkgs.php81Optimized;
            name = "wordpress-php81";
          };
          wordpress-php82 = pkgs.buildWordpressPhp {
            php = pkgs.php82Optimized;
            name = "wordpress-php82";
          };
          wordpress-php83 = pkgs.buildWordpressPhp {
            php = pkgs.php83Optimized;
            name = "wordpress-php83";
          };
        };
      }
    );
}