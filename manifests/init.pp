# - key
#   used for file directories.
# - version
#   drupal version
# - vcsroot
#   the checkout path relative to $drupal::sitesdir
# - drupalroot
#   the drupal path relative to $vcsroot
# - repo
#   git url
# - sites
#   key values unique in namespace of all drupal sites on server - value passed
#   directly to ::drupal::site::multisite
# - use_local_sites
#   write sites/sites.local.php in place of default sites.php, assumes sites.php
#   contains an include statement.
define drupal::site (
  $key = $name,
  $version = 8,
  $vcsroot = "/var/www/${name}",
  $drupalroot = '',
  $repo = 'http://git.drupal.org/project/drupal.git',
  $repo_revision = undef,
  $sites = { "${name}" => {} },
  $use_local_sites = false,
) {

  # configure sites directory
  if $use_local_sites {
    $sites_file = "${drupalroot}/sites/sites.local.php"
  }
  else {
    $sites_file = "${drupalroot}/sites/sites.php"
  }
  file { $sites_file:
    ensure => present,
    content => template('drupal/sites.php.erb'),
    mode => 644,
    owner => $drupal::user,
    group => $drupal::group,
  }
  create_resources(::drupal::site::multisite, $sites, {
    version => $version,
    drupalroot => $drupalroot,
    user => $::drupal::user,
    group => $::drupal::group,
    subscribe => Vcsrepo["${vcsroot}"],
  })

  # codebase.
  vcsrepo { $vcsroot:
    ensure => present,
    provider => git,
    source => $repo,
    revision => $repo_revision,
    user => $drupal::user,
    owner => $drupal::user,
    group => $drupal::group,
  }

}

# - site
#   sites dir
# - sites_key
#   sites.php key, port.domain.subdir
# - drush_uri
#   drush alias uri
# - write_settings
#   write a settings.php see files/settings.php
# - settings
#   settings.local.php values, gets written as php
define drupal::site::multisite (
  $site = 'default',
  $sites_key,
  $drush_uri = "http://${title}.dev",
  $write_settings = true,
  $settings = {
    'databases' => {
      'default' => {
        'default' => {
          'driver' => 'mysql',
          'database' => $title,
          'username' => 'root',
          'password' => '',
          'host' => 'localhost',
          'prefix' => '',
          'collation' => 'utf8_general_ci',
        },
      },
    },
    'conf' => {
      'file_temporary_path' => '/tmp',
      'file_private_path' => 'sites/default/private',
    },
  },
  $version = 8,
  $drupalroot = "/var/www/${title}",
  $user => 'root',
  $group => 'root',
) {

  require drupal

  $sites_dir = "${drupalroot}/sites/${site}"
  case $version {
    8: {
      $settings_template = "drupal/d8.settings.local.php.erb"
    }
    default: {
      $settings_template = "drupal/settings.local.php.erb"
    }
  }

  # configure site directory
  file { $sites_dir:
    ensure => directory,
    owner => $user,
    group => $group,
    mode => 755,
  }
  file { "${sites_dir}/settings.local.php":
    ensure => file,
    content => template($settings_template),
    owner => $user,
    group => $group,
    mode => 644,
    require => File[$sites_dir],
  }
  if $write_settings {
    $settings_source = 'puppet:///modules/drupal/settings.php'
  }
  else {
    $settings_source = undef
  }
  file { "${sites_dir}/settings.php":
    ensure => file,
    source => $settings_source,
    owner => $user,
    group => $group,
    mode => 444,
    require => File[$sites_dir],
  }
  file {[
      "${sites_dir}/files",
      "${sites_dir}/private",
    ]:
    ensure => directory,
    mode => 770,
    owner => $user,
    group => $group,
    require => File[$sites_dir],
  }

  # drush
  $local_alias = "local.${name}"
  $local_alias_values = {
    uri => $drush_uri,
    root => $drupalroot,
  }
  file { "drush alias for ${name}":
    path => "${drupal::home}/.drush/${local_alias}.alias.drushrc.php",
    ensure => 'file',
    content => template('drupal/local.alias.drushrc.php.erb'),
    owner => $user,
  }
}
