# Install Drush for the aegir user

class aegir::drush {
  include aegir::user

  $aegir_user = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_user') %>")
  $aegir_group = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_group') %>")
  $aegir_home = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_home') %>")
  $drush_version = inline_template("<%= scope.lookupvar(aegir_scope + '::drush_version') %>")

  exec { "download-drush":
    cwd => "${aegir_home}",
    command => "/usr/bin/wget http://ftp.drupal.org/files/projects/drush-${drush_version}.tar.gz",
    creates => "${aegir_home}/drush",
    user => "${aegir_user}",
  }
  
  exec { "install-drush":
    cwd => "${aegir_home}",
    command => "/bin/tar xvzf ${aegir_home}/drush-${drush_version}.tar.gz",
    creates => "${aegir_home}/drush",
    require => [ Exec["download-drush"] ],
    user => "${aegir_user}",
  }
  

  file { "${aegir_home}/drush-${drush_version}.tar.gz": 
    ensure => absent,
    require => File['drush_bin'],
  }


  file { "drush_bin":
    path => "${aegir_home}/drush/drush",
    ensure => present,
    require => Exec['install-drush'],
    owner => $aegir_user,
    group => $aegir_group
  }


  file { "bashrc" :
   path => "$aegir_home/.bashrc",
   owner => $aegir_user,
   group => $aegir_group,
   ensure => present,
  }

  line { "drush-path" :
    file => "$aegir_home/.bashrc",
    require => File['bashrc'],
    line => "export PATH=\$PATH:$aegir_home/drush"
  }

  # create the .drush directory

  file { ".drush" :
    path => "${aegir_home}/.drush/",
    ensure => directory,
    owner => "${aegir_user}",
    group => $aegir_group,
    mode => 700,
  }

  define dl($package, $destination, $scope = 'aegir::config') {
    $aegir_home = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_home') %>")
    $aegir_user = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_user') %>")
    $aegir_group = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_group') %>")
    
    exec { "drush-download-$name":
      cwd => "${aegir_home}",
      command => "${aegir_home}/drush/drush dl $package --destination='${destination}'",
      creates => "${destination}/${name}",
      user => $aegir_user,
      group => $aegir_group,
      environment => [ "HOME=$aegir_home" ],
      require => File['drush_bin']
    }
  }
}
