# Configure a GitLab server (gitlab.domain.tld)
node /gitlab_server/ {

  stage { 'first': before => Stage['main'] }
  stage { 'last': require => Stage['main'] }

  $gitlab_dbname  = 'gitlab_prod'
  $gitlab_dbuser  = 'labu'
  $gitlab_dbpwd   = 'labpass'


  class { 'apt': stage => first; }

  # Manage redis and nginx server
  class { 'redis': stage => main; }
  class { 'nginx': stage => main; }

  class {
    'ruby':
      stage           => main,
      version         => $ruby_version,
      rubygems_update => false;
  }

  class {
    'ruby::dev':
      stage   => main,
      require => Class['ruby']
  }

  if $::lsbdistcodename == 'precise' {
    package {
      ['build-essential','libssl-dev','libgdbm-dev','libreadline-dev',
      'libncurses5-dev','libffi-dev','libcurl4-openssl-dev']:
        ensure => installed;
    }

    $ruby_version = '4.9'

    exec {
      'ruby-version':
        command     => '/usr/bin/update-alternatives --set ruby /usr/bin/ruby1.9.1',
        user        => root,
        logoutput   => 'on_failure';
      'gem-version':
        command     => '/usr/bin/update-alternatives --set gem /usr/bin/gem1.9.1',
        user        => root,
        logoutput   => 'on_failure';
    }
  } else {
    $ruby_version = '1:1.9.3'
  }

  # git://github.com/puppetlabs/puppetlabs-mysql.git
  class { 'mysql::server': stage   => main; }

  mysql::db {
    $gitlab_dbname:
      ensure   => 'present',
      charset  => 'utf8',
      user     => $gitlab_dbuser,
      password => $gitlab_dbpwd,
      host     => 'localhost',
      grant    => ['all'],
      # See http://projects.puppetlabs.com/issues/17802 (thanks Elliot)
      require  => Class['mysql::config'],
  }

  class {
    'gitlab':
      stage             => last,
      git_user          => 'git',
      git_home          => '/home/git',
      git_email         => 'notifs@foobar.fr',
      git_comment       => 'GitLab',
      # Setup gitlab sources and branch (default to GIT proto)
      gitlab_sources    => 'https://github.com/gitlabhq/gitlabhq.git',
      gitlab_domain     => 'gitlab.localdomain.local',
      gitlab_dbtype     => 'mysql',
      gitlab_dbname     => $gitlab_dbname,
      gitlab_dbuser     => $gitlab_dbuser,
      gitlab_dbpwd      => $gitlab_dbpwd,
      ldap_enabled      => false,
  }
}
