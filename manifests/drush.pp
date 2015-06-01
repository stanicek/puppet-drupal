# Install drush
# - bin
#   directory/file name for source and executable.
# - revision
#   git revision
# - default
#   link $bin_dir/drush to this instance
# - user
#   user for file ownership
# - group
#   group for file ownership
# - src_dir
#   directory to checkout source
# - bin_dir
#   directory to symlink executable from
# - composer_bin
#   path to composer executable
# - composer_home
#   https://getcomposer.org/doc/03-cli.md#composer-home)
# - modules
#   list of modules to install for this instance only
define drupal::drush (
  $bin = $title,
  $revision = '7.x',
  $default = false,
  $user = 'root',
  $group = 'root',
  $src_dir = "/opt/drush-src",
  $bin_dir = "/usr/local/bin",
  $composer_bin = '/usr/local/bin/composer',
  $composer_home = '/root',
  $modules = [],
) {

  $src_path = "${src_dir}/${bin}"
  $bin_path = "${src_path}/drush"

  vcsrepo { $src_path:
    ensure => $ensure,
    provider => git,
    source => 'https://github.com/drush-ops/drush.git',
    revision => $revision,
    require => Package['git'],
    user => $user,
    owner => $user,
    group => $group,
  } ~>
  exec { "${bin} composer install":
    command => "${composer_bin} install > composer.log",
    environment => "COMPOSER_HOME=${composer_home}",
    cwd => $src_path,
    refreshonly => true,
    user => $user,
    timeout => 600,
  } ~>
  exec { "${bin} initial run":
    command => "${bin_path} -vd",
    user => $user,
    refreshonly => true,
  }

  file { "${bin_dir}/${bin}":
    ensure  => link,
    target  => $bin_path,
    require => Vcsrepo[$src_path],
  }

  if $default {
    file { "${bin_dir}/drush":
      ensure  => link,
      target  => $bin_path,
      require => Vcsrepo[$src_path],
    }
  }

  $modules.each |$module| {
    ::drupal::drush::module { "${bin} ${module}":
      module => $module,
      bin => $bin,
      require => Exec["${bin} initial run"],
    }
  }

  exec { "${bin} cache-clear drush":
    command => "${bin_path} cache-clear drush",
    user => $user,
    refreshonly => true,
    require => Exec["${bin} initial run"],
  }
}

# Install a drush module on a single instance, using `drush pm-download`
# - module
#   the drush module name
# - bin
#   the ::drupal::drush instance
# - version
#   drush module version
define drupal::drush::module (
  $module,
  $bin,
  $version = false,
) {

  if ! defined(::Drupal::Drush[$bin]) {
    fail("missing ::drupal::drush{'${bin}'}")
  }

  $src_path = getparam(::Drupal::Drush[$bin], 'src_path')
  $bin_path = getparam(::Drupal::Drush[$bin], 'bin_path')
  $user = getparam(::Drupal::Drush[$bin], 'user')

  $destination = "${src_path}/commands"

  if $version {
    $cmd = "${bin_path} -y dl ${module}-${version} --destination=${destination}"
  }
  else {
    $cmd = "${bin_path} -y dl ${module} --destination=${destination}"
  }

  exec { "${bin} dl ${module}":
    command => $cmd,
    user => $user,
    creates => "${destination}/${module}",
    notify => Exec["${bin} cache-clear drush"],
    require => File["${bin_path}"],
  }
}
