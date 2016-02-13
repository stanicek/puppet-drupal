# Installs http://drupalconsole.com/
class drupal::console (
  $user = 'root',
  $group = 'root',
  $src_dir = '/opt/DrupalAppConsole-src',
  $bin_dir = '/usr/local/bin',
  $composer_bin = '/usr/local/bin/composer',
  $composer_home = '/root',
) {

  file { $src_dir:
    ensure => directory,
    owner  => $user,
    group  => $group,
  }
  ~>
  exec { 'drupal console install':
    command => 'curl https://drupalconsole.com/installer -L -o drupal.phar; chmod 0755 drupal.phar',
    provider => 'shell',
    environment => "COMPOSER_HOME=${composer_home}",
    cwd         => $src_dir,
    refreshonly => true,
    timeout     => 600,
  } ->
  file { "${bin_dir}/drupal":
    ensure => link,
    mode => '0755',
    target => "${src_dir}/drupal.phar",
  }
}
