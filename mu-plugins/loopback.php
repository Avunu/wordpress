<?php
/**
 * Plugin Name: Internal URL Rewrite
 * Description: Rewrites internal URLs for proper loopback and REST API functionality behind a reverse proxy
 * Version: 1.0
 * Author: Avunu LLC
 * Author URI: https://avu.nu
 * License: GPL2
 * License URI: https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain: internal-url-rewrite
 *
 * This plugin rewrites internal URLs to ensure proper functionality
 * of WordPress when running behind a reverse proxy or in a containerized
 * environment. It handles loopback requests, REST API calls, and other
 * internal communications.
 */

// Ensure this file is being included by WordPress
if (!defined('ABSPATH')) {
    exit;
}

// Define allowed hosts for internal requests
define('WP_ACCESSIBLE_HOSTS', 'localhost,127.0.0.1');

// Function to rewrite URLs for internal requests
function rewrite_internal_url($url) {
    if ((defined('DOING_AJAX') && DOING_AJAX) || 
        (defined('REST_REQUEST') && REST_REQUEST) ||
        wp_doing_cron()) {
        
        $site_url = parse_url(get_site_url());
        $url_parts = parse_url($url);
        
        // Only rewrite if the host matches the site's host
        if (isset($url_parts['host']) && $url_parts['host'] === $site_url['host']) {
            $url = set_url_scheme($url, 'http');
            $url = str_replace($url_parts['host'], 'localhost', $url);
        }
    }
    return $url;
}

// Apply URL rewriting to various WordPress URL functions
add_filter('site_url', 'rewrite_internal_url', 10, 1);
add_filter('home_url', 'rewrite_internal_url', 10, 1);
add_filter('admin_url', 'rewrite_internal_url', 10, 1);
add_filter('includes_url', 'rewrite_internal_url', 10, 1);
add_filter('content_url', 'rewrite_internal_url', 10, 1);
add_filter('plugins_url', 'rewrite_internal_url', 10, 1);
add_filter('wp_get_attachment_url', 'rewrite_internal_url', 10, 1);

// Force WordPress to use HTTP for loopback requests
add_filter('http_request_args', function($args, $url) {
    if (strpos($url, 'localhost') !== false || strpos($url, '127.0.0.1') !== false) {
        $args['sslverify'] = false;
        $args['curl'][CURLOPT_SSL_VERIFYPEER] = false;
        $args['curl'][CURLOPT_SSL_VERIFYHOST] = false;
    }
    return $args;
}, 10, 2);

// Optionally, set the site URL for the REST API
add_filter('rest_url', 'rewrite_internal_url', 10, 1);