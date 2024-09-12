#!/bin/bash

set -e

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | xargs)
fi

# Check if required environment variables are set
if [ -z "$GITHUB_USERNAME" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_USERNAME and GITHUB_TOKEN must be set in .env file"
    exit 1
fi

# Set variables
REPOSITORY="ghcr.io/avunu/wordpress"
PHP_VERSIONS=("php82" "php83" "php84")
DEFAULT_PHP_VERSION="php83"

# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME -p $GITHUB_TOKEN

# Build and push images for each PHP version
for PHP_VERSION in "${PHP_VERSIONS[@]}"; do
    echo "Building wordpress-$PHP_VERSION..."
    nix build .#wordpress-$PHP_VERSION

    echo "Loading image into Docker..."
    docker load < result

    IMAGE_ID=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep wordpress-$PHP_VERSION)
    
    # Tag and push the image
    FULL_IMAGE_ID="$REPOSITORY:$PHP_VERSION"
    docker tag $IMAGE_ID $FULL_IMAGE_ID
    docker push $FULL_IMAGE_ID

    echo "Pushed $FULL_IMAGE_ID"

    # Tag and push as latest if it's the default version
    if [ "$PHP_VERSION" == "$DEFAULT_PHP_VERSION" ]; then
        LATEST_IMAGE_ID="$REPOSITORY:latest"
        docker tag $FULL_IMAGE_ID $LATEST_IMAGE_ID
        docker push $LATEST_IMAGE_ID
        echo "Pushed $LATEST_IMAGE_ID"
    fi
done

echo "All images built and pushed successfully!"