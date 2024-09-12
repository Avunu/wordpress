#!/bin/sh

# test for the presence of the openssl command, install via nix-shell if not found
if ! command -v openssl &> /dev/null
then
	nix-shell -p openssl --command "bash test.sh"
else
	# build the latest image
	nix build
	docker load < result
	# Generate random keys and salts
	export WORDPRESS_AUTH_KEY=$(openssl rand -base64 32)
	export WORDPRESS_SECURE_AUTH_KEY=$(openssl rand -base64 32)
	export WORDPRESS_LOGGED_IN_KEY=$(openssl rand -base64 32)
	export WORDPRESS_NONCE_KEY=$(openssl rand -base64 32)
	export WORDPRESS_AUTH_SALT=$(openssl rand -base64 32)
	export WORDPRESS_SECURE_AUTH_SALT=$(openssl rand -base64 32)
	export WORDPRESS_LOGGED_IN_SALT=$(openssl rand -base64 32)
	export WORDPRESS_NONCE_SALT=$(openssl rand -base64 32)

	# Run docker-compose
	docker-compose up
fi
