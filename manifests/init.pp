# == Class: openhab
#
# Full description of class openhab here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { 'openhab':
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#  }
#
# === Authors
#
# Mans Matulewicz <mans.matulewicz@gmail.com>
#
# === Copyright
#
# Copyright 2015 Mans Matulewicz
#
class openhab (
  $version                        = $::openhab::params::version,
  $install_dir                    = $::openhab::params::install_dir,
  $sourceurl                      = $::openhab::params::sourceurl,
  $personalconfigmodule           = $::openhab::params::personalconfigmodule,
  $install_java                   = $::openhab::params::install_java,
  $install_habmin                 = $::openhab::params::install_habmin,

  $security_netmask               = $::openhab::params::security_netmask,
  $security_netmask_enable        = $::openhab::params::security_netmask_enable,

#action pushover
  $action_pushover_defaulttoken   = $::openhab::params::action_pushover_defaulttoken,
  $action_pushover_defaultuser    = $::openhab::params::action_pushover_defaultuser,

#denon binding
  $binding_denon_id               = $::openhab::params::binding_denon_id,
  $binding_denon_host             = $::openhab::params::binding_denon_host,
  $binding_denon_update           = $::openhab::params::binding_denon_update,

#mosquitto binding
  $binding_mqtt_id                = $::openhab::params::binding_mqtt_id,
  $binding_mqtt_url               = $::openhab::params::binding_mqtt_url,
  $binding_mqtt_clientId          = $::openhab::params::binding_mqtt_clientId, #todo-opt
  $binding_mqtt_user              = $::openhab::params::binding_mqtt_user, #todo-opt
  $binding_mqtt_password          = $::openhab::params::binding_mqtt_password, #todo-opt
  $binding_mqtt_qos               = $::openhab::params::binding_mqtt_qos, #todo-opt
  $binding_mqtt_retain            = $::openhab::params::binding_mqtt_retain, #todo-opt
  $binding_mqtt_async             = $::openhab::params::binding_mqtt_async, #todo-opt
  $binding_mqtt_lwt               = $::openhab::params::binding_mqtt_lwt, #todo-opt

#persistence mysql
  $persistence_mysql_url          = $::openhab::params::mysql_url,
  $persistence_mysql_user         = $::openhab::params::mysql_user,
  $persistence_mysql_password     = $::openhab::params::mysql_password,
  $persistence_mysql_reconnectCnt = $::openhab::params::mysql_reconnectCnt,
  $persistence_mysql_waitTimeout  = $::openhab::params::mysql_waitTimeout,

  ) inherits ::openhab::params{

    include ::archive
    ensure_packages(['unzip'])


    anchor {'openhab::begin':}
    anchor {'openhab::end':}

    if $openhab::install_java {
      include ::java
      Anchor['openhab::begin'] ->
        Class['java'] ->
        Service['openhab'] ->
      Anchor['openhab::end']
    }

    if $openhab::install_habmin {
        include ::openhab::habmin
      Anchor['openhab::begin'] ->
        Class['openhab::habmin'] ->
        Service['openhab'] ->
      Anchor['openhab::end']
    }
    if $openhab::install_greent {
        include ::openhab::greent
      Anchor['openhab::begin'] ->
        Archive['openhab-runtime']
        Class['openhab::greent'] ->
        Service['openhab'] ->
      Anchor['openhab::end']
    }

    file {'/opt/openhab':
    ensure => directory,
    path   => '/opt/openhab',
  } ->
  archive {'openhab-runtime':
    ensure       => present,
    path         => "/tmp/distribution-${version}-runtime.zip",
    source       => "${sourceurl}/distribution-${version}-runtime.zip",
    creates      => "${install_dir}/server/plugins/org.openhab.core_${version}.jar",
    extract      => true,
    cleanup      => false,
    extract_path => $install_dir,
    require      => Package['unzip'],
  } ->
  file {"${install_dir}/addons_repo":
  ensure => directory,
  path   => '/opt/openhab/addons_repo',
}

  archive {"openhab-addons-${version}":
    ensure       => present,
    path         => "/tmp/distribution-${version}-addons.zip",
    source       => "${sourceurl}/distribution-${version}-addons.zip",
    creates      => "${install_dir}/addons_repo/org.openhab.io.myopenhab-${version}.jar",
    extract      => true,
    cleanup      => false,
    extract_path => "${install_dir}/addons_repo",
  }

  $addons = hiera('openhab_addons', {})
  create_resources('addon', $addons)

  file {'openhab.initd':
    ensure => present,
    path   => '/etc/init.d/openhab',
    mode   => '0755',
    source => 'puppet:///modules/openhab/openhab.initd',
  } ->

  user { 'openhab':
      ensure  => present,
      groups  => [ 'dialout' ],
      require => Archive['openhab-runtime'],
    } ->
  file  {'openhab.cfg':
    ensure  => present,
    path    => "${install_dir}/configurations/openhab.cfg",
    content => template('openhab/openhab.cfg.erb'),
    require => Archive['openhab-runtime'],
    notify  => Service['openhab'],
} ->

  file {'openhab-items':
    ensure  => directory,
    path    => '/opt/openhab/configurations/items',
    recurse => 'remote',
    source  => "puppet:///modules/${personalconfigmodule}/items",

  } ->

  file {'openhab-rules':
    ensure  => directory,
    path    => '/opt/openhab/configurations/rules',
    recurse => 'remote',
    source  => "puppet:///modules/${personalconfigmodule}/rules",

  } ->

  file {'openhab-sitemaps':
    ensure  => directory,
    path    => '/opt/openhab/configurations/sitemaps',
    recurse => 'remote',
    source  => "puppet:///modules/${personalconfigmodule}/sitemaps",

  } ->

  service {'openhab':
    ensure    => running,
    enable    => true,
    subscribe => File['openhab.cfg'],
  }

}
