class drupal::console (
  $user = 'root',
  $group = 'root',
  $src_path = "/usr/local/src",
  $bin_path = "/usr/local/bin",
) {

  $console_dir = "${src}/DrupalAppConsole"
  php::ini_setting { 'drupal console php cli phar.readonly':
    setting => 'phar.readonly',
    value => 'Off',
    section => 'phar',
    sapi => 'cli',
  }
  file { $console_dir:
    ensure => directory,
    owner => $user,
    group => $group,
  } ~>
  exec { "curl -LSs http://drupalconsole.com/installer | php":
    environment => "COMPOSER_HOME=/root",
    cwd => $console_dir,
    creates => "${console_dir}/console.phar",
    refreshonly => true,
    require => [
      Php::Ini_setting['drupal console php cli phar.readonly'],
      Php::Module['curl'],
    ],
    timeout => 600,
  } ->
  file { "${bin_path}/drupal":
    ensure => link,
    target => "${console_dir}/console.phar",
  }
}
