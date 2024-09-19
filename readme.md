# WordPress FrankenPHP NixOS Containers

This project provides Nix flakes for building optimized WordPress containers using FrankenPHP for multiple PHP versions. It leverages Nix for reproducible builds and includes GitHub Actions for automated building and pushing to GitHub Container Registry (ghcr.io).

## Features

* Currently building PHP 8.2, 8.3, and 8.4
* Uses [FrankenPHP](https://frankenphp.dev/) as a modern PHP process manager.
* Optimized builds with CPU-specific flags
* Automated builds and pushes to ghcr.io
* Easily extensible for custom configurations

## Prerequisites

* Nix with flakes enabled
* Docker (for local testing and pushing)
* GitHub account (for pushing to ghcr.io)

## Local Development

### Building Images

To build images locally:

```bash
# Build all images
nix build

# Build a specific PHP version
nix build .#wordpress-php83
```

### Testing Locally

There’s a script you can use to test locally:

```bash
./scripts/test.sh
```

Visit `http://localhost:8080` in your browser to test.

### Pushing to ghcr.io



1. Create a `.env` file in the project root:

```
GITHUB_USERNAME=your_github_username
GITHUB_TOKEN=your_personal_access_token
```


2\. Run the build and push script:

```bash
./scripts/build-and-push.sh
```

## GitHub Actions

The included GitHub Actions workflow automatically builds and pushes images to ghcr.io on pushes to the main branch.

## Contributing

Contributions are welcome! Please submit pull requests with any improvements or bug fixes.

## License

MIT