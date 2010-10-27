# Install the Aegir backend - provision

class aegir::backend {
  require aegir::drush
  require aegir::db
  require aegir::http

  # we need some form of MTA to send welcome mails.
  require aegir::includes::mail

  $aegir_host = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_host') %>")
  $aegir_master = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_master') %>")

  $aegir_user = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_user') %>")
  $aegir_group = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_group') %>")
  $aegir_home = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_home') %>")
  $aegir_version = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_version') %>")

  $aegir_db_user = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_db_user') %>")
  $aegir_db_pass = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_db_pass') %>")

  $keyfile = "${aegir_home}/.ssh/id_rsa"


  $keyshare = "/etc/puppet/files/keys"
  $gen_command = "ssh-keygen -q -t rsa -N \"\" -f $keyshare/$fqdn.key -C \"$aegir_user@$fqdn\" "
  $pubkey_command = "if [ -e '$keyshare/$fqdn.key.pub' ]; then cat '$keyshare/$fqdn.key.pub'; else $gen_command; cat '$keyshare/$fqdn.key.pub'; fi"
  $pvtkey_command = "if [ -e '$keyshare/$fqdn.key' ]; then cat '$keyshare/$fqdn.key'; else $gen_command; cat '$keyshare/$fqdn.key'; fi"
  $pubkey = inline_template("<%= `$pubkey_command` %>")
  $pvtkey = inline_template("<%= `$pvtkey_command` %>")

  file { 
    "$keyfile":
      ensure => present,
	owner => $aegir_user,
   group => $aegir_user,
mode => 600,
      content => $pvtkey;
    "${keyfile}.pub":
	owner => $aegir_user,
   group => $aegir_user,

      ensure => present,
      content => $pubkey,
      mode => 644; 
   }


  @@ssh_authorized_key { "$fqdn public key":     
    user => "${aegir_user}",
    ensure => present,  
    type => 'ssh-rsa',
    key => regsubst(regsubst($pubkey, '^ssh-rsa (.*) .*$', '\1'), "\n", ""), 
  }                       

  aegir::drush::dl { "drush_make" :
    package => "drush_make-6.x-2.0-beta9",
    destination => "$aegir_home/.drush",
    scope => $aegir_scope,
    require => File['.drush'],
    before => Exec['provision-verify server']
  }
 
 
  if $aegir_version == 'HEAD' {
    $provision_require = "checkout-provision"
 
    exec { "checkout-provision":
      cwd => "${aegir_home}/.drush",
      command => "/usr/bin/git clone git://git.aegirproject.org/provision.git",
      creates => "${aegir_home}/.drush/provision",
      require => [ File[".drush"] ],
        user => $aegir_user,
        group => $aegir_group,
    }   
  }
  else {
    $provision_require = 'extract-provision'

    exec { "download-provision":
      cwd => "${aegir_home}",
      command => "/usr/bin/wget http://files.aegirproject.org/provision-${aegir_version}.tgz",
      creates => "${aegir_home}/.drush/provision",
        user => $aegir_user,
        group => $aegir_group,
    }
    
    exec { "extract-provision":
      cwd => "${aegir_home}",
      command => "/bin/tar xvzf ${aegir_home}/provision-${aegir_version}.tgz -C ${aegir_home}/.drush",
      creates => "${aegir_home}/.drush/provision",
      require => [ File[".drush"], Exec["download-provision"] ],
        user => $aegir_user,
        group => $aegir_group,
    }
    
    file { "${aegir_home}/provision-${aegir_version}.tgz": 
      ensure => absent,
      require => File['provision'],
    }

  }

  file { "provision" : 
    path => "$aegir_home/.drush/provision",
    ensure => directory, 
    require => Exec[$provision_require],
    owner => $aegir_user,
    group => $aegir_group
  }

  Exec <<| tag == "remote-servers-$fqdn" |>> {
    before => Exec['provision-verify server'],
    require => File['provision'],
  }

  exec { "provision-verify server":
    cwd => "${aegir_home}",
    command => "/usr/bin/sudo -u$aegir_user ${aegir_home}/drush/drush @server_master provision-verify",
    require => [ File["provision"], Exec["grant-aegir-access host"] ],
    environment => [ "HOME=$aegir_home" ],
    logoutput => true,

  }

  file { "server_master.drushrc" :
    path => "${aegir_home}/.drush/server_master.alias.drushrc.php",
    require => Exec["provision-verify server"],
    ensure => present,
    owner => $aegir_user,
    group => $aegir_group,
    mode => 400,
  }

}
