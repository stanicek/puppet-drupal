# Base class, set to user/group that will own the file structure..
class drupal (
  $user = 'root',
  $group = 'root',
  $home = '/root',
) {}

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
  $key             = $title,
  $version         = 8,
  $vcsroot         = "/var/www/${title}",
  $drupalroot      = '',
  $repo            = 'http://git.drupal.org/project/drupal.git',
  $repo_revision   = undef,
  $sites           = { $title => {} },
  $use_local_sites = false,
) {

  require ::drupal

  # codebase.
  vcsrepo { $vcsroot:
    ensure   => present,
    provider => git,
    source   => $repo,
    revision => $repo_revision,
    user     => $::drupal::user,
    owner    => $::drupal::user,
    group    => $::drupal::group,
  }

  if $drupalroot {
    $_drupalroot = "${vcsroot}/${drupalroot}"
  } else {
    $_drupalroot = $vcsroot
  }

  # configure sites directory
  if $use_local_sites {
    $sites_file = "${_drupalroot}/sites/sites.local.php"
  }
  else {
    $sites_file = "${_drupalroot}/sites/sites.php"
  }
  file { $sites_file:
    ensure  => present,
    content => template('drupal/sites.php.erb'),
    mode    => '0644',
    owner   => $::drupal::user,
    group   => $::drupal::group,
    require => Vcsrepo[$vcsroot],
  }
  create_resources(::drupal::site::multisite, $sites, {
    version    => $version,
    drupalroot => $_drupalroot,
    user       => $::drupal::user,
    group      => $::drupal::group,
    subscribe  => Vcsrepo[$vcsroot],
    require    => Vcsrepo[$vcsroot],
  })

}

# - sites_key
#   sites.php key, port.domain.subdir
# - site
#   sites dir
# - drush_uri
#   drush alias uri
# - write_settings
#   write a settings.php see files/settings.php
# - settings
#   settings.local.php values, gets written as php
# - settings_template
#   use in place of default settings file template (use to modify
#   templates/*settings.local.php.erb)
# - version
#   major drupal core version
# - drupalroot
#   absolute path to drupal codebase
# - user
#   system user to assign file ownership
# - group
#   system group to assign file ownership
define drupal::site::multisite (
  $sites_key,
  $site               = 'default',
  $drush_uri          = "http://${title}.dev",
  $write_settings     = true,
  $settings           = {},
  $settings_tempalate = undef,
  $version            = 8,
  $drupalroot         = "/var/www/${title}",
  $user               = 'root',
  $group              = 'root',
) {

  require ::drupal

  $sites_dir = "sites/${site}"
  $site_hostname = regsubst($drush_uri, '^https?://(.*)/?$', '^\1$')

  case $version {
    8: {
      $_settings_template = $settings_template ? { # lint:ignore:variable_scope
        undef => 'drupal/d8.settings.local.php.erb',
        default => $settings_template, # lint:ignore:variable_scope
      }
      $_settings = merge({
        'databases' => {
          'default' => {
            'default' => {
              'driver'    => 'mysql',
              'database'  => $title,
              'username'  => 'root',
              'password'  => '',
              'host'      => 'localhost',
              'prefix'    => '',
              'collation' => 'utf8_general_ci',
            },
          },
        },
        'settings' => {
          'file_temporary_path'   => '/tmp',
          'file_public_path'      => "${sites_dir}/files",
          'file_private_path'     => "${sites_dir}/private",
          'trusted_host_patterns' => [
            regsubst($site_hostname, '\.', '\.'),
          ],
        },
        'config_directories' => {
          'active'  => "${sites_dir}/config/active",
          'staging' => "${sites_dir}/config/staging",
        },
        'config' => {
        },
      }, $settings)
    }
    default: {
      $_settings_template = $settings_template ? { # lint:ignore:variable_scope
        undef => 'drupal/settings.local.php.erb',
        default => $settings_template, # lint:ignore:variable_scope
      }
      $_settings = merge({
        'databases' => {
          'default' => {
            'default' => {
              'driver'    => 'mysql',
              'database'  => $title,
              'username'  => 'root',
              'password'  => '',
              'host'      => 'localhost',
              'prefix'    => '',
              'collation' => 'utf8_general_ci',
            },
          },
        },
        'settings' => {
          'file_temporary_path' => '/tmp',
          'file_public_path'    => "${sites_dir}/files",
          'file_private_path'   => "${sites_dir}/private",
        },
      }, $settings)
    }
  }

  # configure site directory
  file { "${drupalroot}/${sites_dir}":
    ensure => directory,
    owner  => $user,
    group  => $group,
    mode   => '0755',
  }
  file { "${drupalroot}/${sites_dir}/settings.local.php":
    ensure  => file,
    content => template($_settings_template),
    owner   => $user,
    group   => $group,
    mode    => '0644',
    require => File["${drupalroot}/${sites_dir}"],
  }
  if $write_settings {
    $settings_source = 'puppet:///modules/drupal/settings.php'
  }
  else {
    $settings_source = undef
  }
  file { "${drupalroot}/${sites_dir}/settings.php":
    ensure  => file,
    source  => $settings_source,
    owner   => $user,
    group   => $group,
    mode    => '0444',
    require => File["${drupalroot}/${sites_dir}"],
  }
  file {[
      "${drupalroot}/${sites_dir}/files",
      "${drupalroot}/${sites_dir}/private",
    ]:
    ensure  => directory,
    mode    => '0770',
    owner   => $user,
    group   => $group,
    require => File["${drupalroot}/${sites_dir}"],
  }

  # drush
  $dotdrush_dir = "${::drupal::home}/.drush"
  if ! defined(File[$dotdrush_dir]) {
    file { "${::profile::home}/.drush":
      ensure => directory,
      owner  => $::drupal::user,
      group  => $::drupal::user,
    }
  }
  $local_alias = "local.${title}"
  $local_alias_values = {
    uri  => $drush_uri,
    root => $drupalroot,
  }
  file { "drush alias for ${title}":
    ensure  => 'file',
    path    => "${::drupal::home}/.drush/${local_alias}.alias.drushrc.php",
    content => template('drupal/local.alias.drushrc.php.erb'),
    owner   => $::drupal::user,
    group   => $::drupal::user,
  }
}
