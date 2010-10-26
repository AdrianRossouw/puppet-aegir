Exec { path => '/usr/bin:/bin:/usr/sbin:/sbin' }


/**
 * Default configuration settings for aegir.
 */
class aegir::config {
  $aegir_user = "aegir"
  $aegir_group = "aegir"
  $aegir_home = "/var/aegir"

  $aegir_host = ''
  $aegir_ip = ''


  $aegir_master = 'aegir.example.com'
  $aegir_email = 'aegir@example.com'

  $aegir_db_user = 'aegir_root'
  $aegir_db_pass = 'a7vaKru0AQJ4Sb'

  $aegir_version = '0.4-alpha14'
  $drush_version = '6.x-3.3'

  $mysql_pass = "GQTInUA0n44Scp"

  $apache_ssl = false

  case $operatingsystem {
    Debian,Ubuntu:  { 
      $apache_group = "www-data"
      $apachectl_bin = '/usr/sbin/apache2ctl'
      $apache_etc_path = "/etc/apache2"
      $bind_bin = "/etc/init.d/bind9"
      $bind_conf = "/etc/bind/named.conf.local"
    }
    RedHat,CentOS:  { 
      $apache_group = "apache" 
      $apachectl_bin = '/usr/sbin/apachectl'
      $apache_etc_path = "/etc/httpd"
      # TODO - bind support for centos
    }
    default: {
      notice "Unsupported operatingsystem ${operatingsystem}"
    }
  }
}

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

class aegir::backend {
  Exec { path => '/usr/bin:/bin:/usr/sbin:/sbin' }
  include aegir::drush
  include aegir::db
  include aegir::http

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
    command => "sudo -u$aegir_user ${aegir_home}/drush/drush @server_master provision-verify",
    require => [ File["provision"] ],
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
    command => "a2enmod rewrite"
  }

  if $apache_ssl {
		exec { "enable apache openssl" :
			command => "a2enmod ssl",
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
    exec { "enable dns feature" : 
			cwd => $aegir_home,
			user => $aegir_user,
			environment => [ "HOME=$aegir_home" ],
			group => $aegir_group,
			command => "$aegir_home/drush/drush @hostmaster pm-enable hosting_dns -y",
      require => Exec['provision-verify server'],
			before => Exec['provision-verify site']
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
