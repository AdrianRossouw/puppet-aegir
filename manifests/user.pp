# Install the aegir user

class aegir::user {
	require aegir::hostname
  # This should put server level ssh keys into all the known hosts files.
  @@sshkey { $fqdn: type => rsa, key => $sshrsakey }
  Sshkey <<| |>>

  file { '/etc/ssh/ssh_known_hosts' :
    mode => 644,
  }

  # Create Aegir user
  $aegir_host = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_host') %>")
  $aegir_user = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_user') %>")
  $aegir_group = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_group') %>")
  $aegir_home = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_home') %>")

  group { "$aegir_group" : 
    ensure => present,
  }
 
  if $fqdn != $aegir_host {
    # instantiate the exported ssh key from the relevant front end
    Ssh_authorized_key <<| title == "${aegir_host} public key" |>>
   
    $aegir_shell = "/bin/bash"
  }
  else {
    $aegir_shell = '/bin/false'
  }

  user { "$aegir_user" :
    ensure => present,
    comment => "Aegir System Account",
    managehome => true,
    home => $aegir_home,
    shell => $aegir_shell,
    gid => $aegir_group,
  }

  # RHEL apache will squeal "pcfg_openfile: unable to check htaccess file"
  # if mode is not 0755
  file { $aegir_home:
    ensure => directory,
    owner => $aegir_user,
    group => $aegir_group,
    mode => 755,
    require => User[$aegir_user],
  }

  file { ".ssh" :
    path => "$aegir_home/.ssh",
    ensure => directory,
    owner => $aegir_user,
    group => $aegir_group,
  }
   }
