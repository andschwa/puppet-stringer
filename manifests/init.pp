# == Class: stringer
#
# Full description of class stringer here.
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
#  class { stringer:
  #  }
#
# === Authors
#
# Andrew Schwartzmeyer <andrew@schwartzmeyer.com>
#
# === Copyright
#
# Copyright 2014 Andrew Schwartzmeyer, unless otherwise noted.
#
class stringer(
  $user        = 'stringer',
  $group       = 'stringer',
  $home        = '/home/stringer',
  $source      = 'https://github.com/swanson/stringer.git',
  $ensure      = latest,
  $ruby        = '2.0.0-p451',
  $db_name     = 'stringer_live',
  $db_user     = 'stringer',
  $db_password = 'override-privately-through-hiera',
)
{

  # package dependencies?
  # git libxml2-dev libxslt-dev libcurl4-openssl-dev libpq-dev libsqlite3-dev build-essential postgresql libreadline-dev

  # user setup
  group { $group:
    ensure => present,
  }

  user { $user:
    ensure     => present,
    gid        => $group,
    home       => $home,
    managehome => true,
    require    => Group[$group]
  }

  # pull stringer repository
  vcsrepo { "${home}/stringer":
    ensure   => $ensure,
    source   => $source,
    provider => git,
    require  => User[$user],
  }

  # rbenv installation, compilation, and bundle
  rbenv::install { $user:
    group => $group,
    home  => $home,
  }

  rbenv::compile { 'stringer':
    user   => $user,
    home   => $home,
    ruby   => $ruby,
    global => true
  }

  rbenv::bundle { 'stringer':
    user    => $user,
    group   => $group,
    home    => $home,
    content => "${home}/stringer/Gemfile",
    require => Vcsrepo["${home}/stringer"],
  }

  Exec {
    user => $user,
    cwd  => "${home}/stringer",
    path => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
  }

  # there has to be a cleaner way to do this
  exec {
    "echo 'export STRINGER_DATABASE=${db_name}' >> ${home}/.bash_profile":
      unless => "grep -q ${db_name} ${home}/.bash_profile";

    "echo 'export STRINGER_DATABASE_USERNAME=${db_user}' >> ${home}/.bash_profile":
      unless => "grep -q ${db_user} ${home}/.bash_profile";

    "echo 'export STRINGER_DATABASE_PASSWORD=${db_password}' >> ${home}/.bash_profile":
      unless => "grep -q ${db_password} ${home}/.bash_profile";

    "echo 'export RACK_ENV=production' >> ${home}/.bash_profile":
      unless => "grep -q RACK_ENV ${home}/.bash_profile";
  }
  # these need to be done afterward
  ->
  exec { "source ${home}/.bash_profile && rake db:migrate RACK_ENV=production": }
  ->
  exec { "source ${home}/.bash_profile && bundle exec foreman start": }

  # cron resource to update feeds
  cron { 'stringer':
    user        => $user,
    environment => 'SHELL=/bin/bash',
    command     => 'source $HOME/.bash_profile; cd $HOME/stringer/; bundle exec rake fetch_feeds;',
    minute      => '*/10'
  }

  # postgres setup (should probably be handled independently)
}
