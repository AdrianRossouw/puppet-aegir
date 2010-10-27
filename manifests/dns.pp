## Configure server to act as a DNS server for aegir.
# bind only for now

class aegir::dns {
  require aegir::user
  require aegir::hostname
  require aegir::includes::dns
 
  $aegir_host = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_host') %>")
  $aegir_user = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_user') %>")
  $aegir_group = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_group') %>")
  $aegir_home = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_home') %>")
  $bind_bin = inline_template("<%= scope.lookupvar(aegir_scope + '::bind_bin') %>")
  $bind_conf = inline_template("<%= scope.lookupvar(aegir_scope + '::bind_conf') %>")

  $sudo_aegir = "${aegir_user} ALL=NOPASSWD: ${bind_bin}"

  line { "aegir bind sudo" :
    file => '/etc/sudoers',
    line => $sudo_aegir
  }

  line { "include aegir bind" :
    file => $bind_conf,
    line => "include \"${aegir_home}/config/bind.conf\";",
  }


  user { bind : 
    groups => [ $aegir_group ],
    ensure => present,
  }

  if $aegir_host != $fqdn {
    $s_alias = regsubst( $fqdn, "[!\W\.\-]", "", 'G')
    $service_type = 'bind_slave'
  }
  else {
    $s_alias = 'master'
    @exec { "enable dns feature" : 
			cwd => $aegir_home,
			user => $aegir_user,
			environment => [ "HOME=$aegir_home" ],
      tag => 'hostmaster-features-enable',
			group => $aegir_group,
			command => "$aegir_home/drush/drush @hostmaster pm-enable hosting_dns -y",
		}
    $service_type = 'bind'
  }
  $restart_cmd = "sudo $bind_bin reload"

 	@@exec { "remote dns server : $fqdn":
			cwd => $aegir_home,
			user => $aegir_user,
			environment => [ "HOME=$aegir_home" ],
			group => $aegir_group,
			tag => "remote-servers-$aegir_host",
			command => "$aegir_home/drush/drush provision-save @server_${s_alias} \
		--context_type=server \
		--remote_host=$fqdn \
		--dns_restart_cmd='$restart_cmd' \
		--dns_service_type=$service_type",
			logoutput => on_failure;
	}
 
}
