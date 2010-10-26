## Configure a server to act as a web server for aegir.
# Apache only for now.

class aegir::user::http inherits aegir::user {
  # this is a rather ridiculous workaround to add the aegir user to the apache group
  $aegir_user = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_user') %>")
  $apache_group = inline_template("<%= scope.lookupvar(aegir_scope + '::apache_group') %>")

  User[$aegir_user] { groups +> $apache_group }

}

class aegir::http {
  include aegir::user::http
  require aegir::includes::http

  $aegir_user = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_user') %>")
  $aegir_group = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_group') %>")
  $aegir_master = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_master') %>")
  $aegir_home = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_home') %>")
  $aegir_host = inline_template("<%= scope.lookupvar(aegir_scope + '::aegir_host') %>")
  $apachectl_bin = inline_template("<%= scope.lookupvar(aegir_scope + '::apachectl_bin') %>")
  $apache_etc_path = inline_template("<%= scope.lookupvar(aegir_scope + '::apache_etc_path') %>")
  $apache_group = inline_template("<%= scope.lookupvar(aegir_scope + '::apache_group') %>")
  $apache_ssl = inline_template("<%= scope.lookupvar(aegir_scope + '::apache_ssl') %>")

  group { "$apache_group" : 
    ensure => present,
    before => User[$aegir_user],
  }

  # symlink to aegir's apache.conf
  file { "${apache_etc_path}/conf.d":
    ensure => directory,
  }

  file { "${aegir_home}/config":
    ensure => directory,
    owner => $aegir_user,
    group => "$aegir_group",
    mode => 711,
    require => User[$aegir_user],
  }

  file { "${aegir_home}/config/apache.conf":
    ensure => present,
    owner => $aegir_user,
    group => "$aegir_group",
    mode => 644,
    require => File["${aegir_home}/config"]
  }

  file { "apache-conf-file":
    path => "${apache_etc_path}/conf.d/aegir.conf",
    ensure => "${aegir_home}/config/apache.conf",
    require => File["${aegir_home}/config/apache.conf"],
  }

  exec { "enable mod rewrite" :
    command => "/usr/sbin/a2enmod rewrite"
  }

  if $apache_ssl {
    exec { "enable apache openssl" :
      command => "/usr/sbin/a2enmod ssl",
    }
    $service_type = 'apache_ssl'

  	if $aegir_host == $fqdn {
			exec { "enable ssl feature" : 
				cwd => $aegir_home,
				user => $aegir_user,
				environment => [ "HOME=$aegir_home" ],
				group => $aegir_group,
				command => "$aegir_home/drush/drush @hostmaster pm-enable hosting_ssl -y",
				require => Exec['provision-verify server'],
				before => Exec['provision-verify site']
			}

		}
  }
  else {
    $service_type = 'apache'
  }
  
  # set up apache.conf and sudo line

  $sudo_aegir = "${aegir_user} ALL=NOPASSWD: ${apachectl_bin}"

  line { "aegir sudo" :
    file => '/etc/sudoers',
    line => $sudo_aegir
  }
  

  if $aegir_host != $fqdn {
    $s_alias = regsubst( $fqdn, "[!\W\.\-]", "", 'G')
  }
  else {
    $s_alias = 'master'
  }

  @@exec { "remote web server : $fqdn":
					cwd => $aegir_home,
					user => $aegir_user,
					group => $aegir_group,
    environment => [ "HOME=$aegir_home" ],
					tag => "remote-servers-$aegir_host",
					command => "$aegir_home/drush/drush provision-save @server_${s_alias} \
				--context_type=server \
				--remote_host=$fqdn \
				--master_url='http://$aegir_master/' \
				--http_service_type=$service_type \
				--script_user=$aegir_user \
				--http_restart_cmd='sudo $apachectl_bin graceful' \
				--web_group=$apache_group \
				--aegir_root=$aegir_home --debug",
					logoutput => on_failure;
			}
}
