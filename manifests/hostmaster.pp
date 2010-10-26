# aegir front end - hostmaster

class aegir::hostmaster {
  include aegir::backend

  $aegir_host = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_host') %>")
  $aegir_master = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_master') %>")
  $aegir_email = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_email') %>")
  $aegir_user = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_user') %>")
  $aegir_group = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_group') %>")
  $aegir_version = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_version') %>")
  $aegir_home = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_home') %>")

  exec { "provision-save platform":
    cwd => "${aegir_home}",
    command => "${aegir_home}/drush/drush provision-save @platform_hostmaster \
      --context_type=platform \
      --server=@server_master \
      --web_server=@server_master \
      --root=${aegir_home}/hostmaster-${aegir_version} \
      --makefile=${aegir_home}/.drush/provision/aegir.make",
    require => [ File['provision'], File['server_master.drushrc'] ],
    environment => [ "HOME=$aegir_home" ],
    creates => "$aegir_home/.drush/platform_hostmaster.alias.drushrc.php",
      user => $aegir_user,
      group => $aegir_group,
    logoutput => on_failure,
  }

  exec { "provision-verify platform":
    cwd => "${aegir_home}",
    command => "sudo -u$aegir_user ${aegir_home}/drush/drush @platform_hostmaster provision-verify",
    require => [ Exec["provision-save platform"] ],
    environment => [ "HOME=$aegir_home" ],
    creates => "${aegir_home}/hostmaster-${aegir_version}",
    logoutput => on_failure,
  }

  exec { "provision-save site":
    cwd => "${aegir_home}",
    command => "${aegir_home}/drush/drush provision-save @hostmaster \
      --context_type=site \
      --platform=@platform_hostmaster \
      --db_server=@server_master \
      --uri=${aegir_master} \
      --client_email=${aegir_email} \
      --profile=hostmaster",
    require => [ Exec["provision-verify platform"] ],
    environment => [ "HOME=$aegir_home" ],
    creates => "$aegir_home/.drush/hostmaster.alias.drushrc.php",
      user => $aegir_user,
      group => $aegir_group,
    logoutput => on_failure,
  }

  file { "${aegir_home}/hostmaster-${aegir_version}/sites/$aegir_master/settings.php":
    ensure => present,
    require => Exec["provision-install site"]
  }

  exec { "provision-install site":
    cwd => "${aegir_home}",
    command => "sudo -u$aegir_user ${aegir_home}/drush/drush @hostmaster provision-install",
    require => [ Exec["provision-save site"] ],
    environment => [ "HOME=$aegir_home" ],
    creates => "${aegir_home}/hostmaster-${aegir_version}/sites/$aegir_master/settings.php",
    logoutput => on_failure,
  }

  exec { "provision-verify site":
    cwd => "${aegir_home}",
    command => "sudo -u$aegir_user ${aegir_home}/drush/drush @hostmaster provision-verify",
    require => [ Exec["provision-install site"] ],
    environment => [ "HOME=$aegir_home" ],
    logoutput => true,
  }

  exec { "provision-import server":
						cwd => $aegir_home,
						user => $aegir_user,
						group => $aegir_group,
      	    environment => [ "HOME=$aegir_home" ],
	 					require => Exec['provision-verify site'],
						command => "$aegir_home/drush/drush @hostmaster hosting-import @server_master",
					logoutput => on_failure,
	  }


  Exec <<| tag == "import-remote-servers-$fqdn" |>> {
	 	require => Exec['provision-verify site']
  }

  exec { "hosting-setup":
    cwd => "${aegir_home}",
    command => "${aegir_home}/drush/drush @hostmaster hosting-setup -y",
    require => [ Exec["provision-verify site"] ],
    environment => [ "HOME=$aegir_home" ],
      user => $aegir_user,
      group => $aegir_group,
    logoutput => on_failure,
  }
}
