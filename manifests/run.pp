# == Define: docker:run
#
# A define which manages an upstart managed docker container
#
define docker::run(
  $image,
  $imagetag = undef,
  $command,
  $memory_limit = '0',
  $ports = [],
  $volumes = [],
  $links = [],
  $use_name = true,  # Without this Upstart won't be able to stop the docker container properly
  $running = true,
  $volumes_from = false,
  $username = '',
  $hostname = '',
  $env = [],
  $dns = [],
) {

  validate_re($image, '^[\S]*$')
  validate_re($imagetag, '^[\S]*$')
  validate_re($title, '^[\S]*$')
  validate_re($memory_limit, '^[\d]*$')
  validate_string($command, $username, $hostname)
  validate_bool($running)

  $ports_array = any2array($ports)
  $volumes_array = any2array($volumes)
  $env_array = any2array($env)
  $dns_array = any2array($dns)
  $links_array = any2array($links)

  file { "/etc/init/docker-${title}.conf":
    ensure  => present,
    content => template('docker/etc/init/docker-run.conf.erb'),
    notify  => Service["docker-${title}"],
  }

  service { "docker-${title}":
    ensure     => $running,
    enable     => true,
    hasstatus  => true,
    hasrestart => false, # With this set to false changes to a job will be loaded directly
    require    => Service[docker],
#    require    => File["/etc/init/docker-${title}.conf"],
  }

}
