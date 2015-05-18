<?php

/**
 * @file
 * Drupal generic configuration file.
 */

include dirname(__FILE__) . '../default/default.settings.php';

$local_settings = dirname(__FILE__) . '/settings.local.php';
if (file_exists($local_settings)) {
  include $local_settings;
}
