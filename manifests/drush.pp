define drupal::drush (
  $bin = $title,
  $revision = '7.x',
  $default = false,
  $user = 'root',
  $group = 'root',
  $src_path = "/usr/local/src",
  $bin_path = "/usr/local/bin",
  $modules = [],
) {

  vcsrepo { "${src_path}/${bin}":
    ensure => $ensure,
    provider => git,
    source => 'https://github.com/drush-ops/drush.git',
    revision => $revision,
    require => Package['git'],
    user => $user,
    owner => $user,
    group => $group,
    notify => Exec["${bin} initial run"],
  } ~>
  exec { "${bin} composer install":
    command => "composer install > composer.log",
    environment => 'COMPOSER_HOME=/root',
    cwd => "${src_path}/${bin}",
    onlyif => "test -f ${src_path}/${bin}/composer.json",
    refreshonly => true,
    user => $user,
    notify => Exec["${bin} initial run"],
    timeout => 600,
  }

  exec { "${bin} initial run":
    command => "${src_path}/${bin}/drush cache-clear drush",
    user => $user,
    refreshonly => true,
    require => File[$drush_dir],
  }

  file { "${bin_path}/${bin}":
    ensure  => link,
    target  => "${src_path}/${bin}/drush",
    require => Vcsrepo["${src_path}/${bin}"],
  }

  if $default {
    file { "${bin_path}/drush":
      ensure  => link,
      target  => "${src_path}/${bin}/drush",
      require => Vcsrepo["${src_path}/${bin}"],
    }
  }

  $modules.each |$module| {
    ::drupal::drush::module { "${bin} ${module}": bin => $bin }
  }
}

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

  $destination = "${src_path}/${bin}/commands"

  if $version {
    $cmd = "${bin} -y dl ${module}-${version} --destination=${destination}"
  }
  else {
    $cmd = "${bin} -y dl ${module} --destination=${destination}"
  }

  exec { "${bin} dl ${module}":
    command => $cmd,
    user => $user,
    creates => "${destination}/${module}",
    notify => Exec["${bin} initial run"],
    require => File["${bin_path}/${bin}"],
  }
}
