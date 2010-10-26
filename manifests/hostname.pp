# Set up the required changes for the hostname to resolve correctly.

class aegir::hostname {
  $aegir_host = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_host') %>")
  $aegir_ip = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_ip') %>")
 $aegir_user = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_user') %>")
  $aegir_group = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_group') %>")
  $aegir_home = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_home') %>")

  file { "/etc/hostname":
    content => "$fqdn",
    ensure => present,
    subscribe => Exec["hostname"],
  }

  exec { "hostname":
   command => "/bin/hostname ${fqdn}",
  }

  host { $fqdn :
    ensure => present,
    ip => $ipaddress,
    host_aliases => [ $hostname, ]
  }

  if $aegir_host != $fqdn {
    host { "aegir hostmaster" :
      name => $aegir_host,
      ip => $aegir_ip,
    }

  $s_alias = regsubst( $fqdn, "[!\W\.\-]", "", 'G')
  @@exec { "import remote server : $fqdn":
						cwd => $aegir_home,
						user => $aegir_user,
						group => $aegir_group,
      	    environment => [ "HOME=$aegir_home" ],
						tag => "import-remote-servers-$aegir_host",
						command => "$aegir_home/drush/drush @hostmaster hosting-import @server_${s_alias}",
					logoutput => on_failure,
	  }

  }
}
