
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
