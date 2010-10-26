## Configure server for use as a database server by aegir
# mysql only for now

class aegir::db {
  require aegir::includes::db
  require aegir::hostname

  $aegir_user = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_user') %>")
  $aegir_group = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_group') %>")

  $aegir_db_user = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_db_user') %>")
  $aegir_db_pass = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_db_pass') %>")
  $aegir_host = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_host') %>")
  $aegir_home = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_home') %>")
  $aegir_ip = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_ip') %>")
  $mysql_pass = inline_template("<%= scope.lookupvar(aegir_scope + '::mysql_pass') %>")

  $content = "[mysqld] \n bind-address = $ipaddress \n"

  file { '/etc/mysql/conf.d/aegir.cnf':
        content => $content,
 	notify => Service["mysql"],
        owner => "root",
        group => "root",
        mode => "0644",
	ensure => present
  }

  exec { "grant-aegir-access host":
      command => "/usr/bin/mysql -uroot -p$mysql_pass -e \"grant all on *.* to ${aegir_db_user}@${aegir_host} identified by '${aegir_db_pass}' with grant option;grant all on *.* to ${aegir_db_user}@${aegir_ip} identified by '${aegir_db_pass}' with grant option;\"",
      require => Service["mysql"],
    }

  if $aegir_host != $fqdn {
    $s_alias = regsubst( $fqdn, "[!\W\.\-]", "", 'G')
  }
  else {
    $s_alias = 'master'
  }


	@@exec { "remote db server : $fqdn":
			cwd => $aegir_home,
			user => $aegir_user,
			environment => [ "HOME=$aegir_home" ],
			group => $aegir_group,
			tag => "remote-servers-$aegir_host",
			command => "$aegir_home/drush/drush provision-save @server_${s_alias} \
		--context_type=server \
		--remote_host=$fqdn \
		--db_service_type=mysql \
		--master_db='mysql://$aegir_db_user:$aegir_db_pass@$fqdn'",
			logoutput => on_failure;
	}
}
