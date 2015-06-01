class drupal::console (
  $user = 'root',
  $group = 'root',
  $src_dir = "/opt/DrupalAppConsole-src",
  $bin_dir = "/usr/local/bin",
  $composer_bin = '/usr/local/bin/composer',
  $composer_home = '/root',
) {

  file { $src_dir:
    ensure => directory,
    owner => $user,
    group => $group,
  } ~>
  exec { 'drupal console install':
    command => "curl -LSs http://drupalconsole.com/installer | php",
    environment => "COMPOSER_HOME=${composer_home}",
    cwd => $src_dir,
    refreshonly => true,
    timeout => 600,
  } ->
  file { "${bin_dir}/drupal":
    ensure => link,
    target => "${src_dir}/console.phar",
  }
}
