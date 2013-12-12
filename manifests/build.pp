define docker::build(
  $dockerfile_path,
  $build_base = "/root/docker/build_base",
  $extra_files = [],
  $no_cache = false, # Do not use cache when building the image if set to true
) {
  
  # Example:
  #docker::build { 'nginx':
  #  dockerfile_path => 'puppet:///modules/dockerfiles/nginx',
  #  extra_files     => [ { source => "puppet:///modules/dockerfiles/nginx/Dockerfile",
  #                         target => "test1" }, 
  #                       { source => "puppet:///modules/dockerfiles/nginx/Dockerfile", 
  #                         target => "test2" } ],
  #}
  
  #validate_re($dockerfile_path, '^[\S]*$')
  
  #notify { "This is docker-build!":  }
  
  exec { "create directory ${build_base}/${title}":
    command => "/bin/bash -c 'umask 077 && /bin/mkdir -p ${build_base}/${title}'",
    creates => "${build_base}/${title}",
    before  => File["${build_base}/${title}/Dockerfile"],
    require => Service['docker'],
  }
  
  #[ { source => "${dockerfile_path}/Dockerfile",
  #                  target => "test1" }, 
  #                { source => "${dockerfile_path}/Dockerfile", 
  #                  target => "test2" } ]
  prepare_extra_files { $extra_files: 
    build_base      => "${build_base}",
    build_title     => "${title}",
    require         => Exec["create directory ${build_base}/${title}"],
    notify          => [ File["${build_base}/${title}/Dockerfile"],
                         Exec["Build ${build_base}/${title} as ${title}"], ],
  }
  
  file { "${build_base}/${title}/Dockerfile":
    ensure => present,
    source => "${dockerfile_path}/Dockerfile",
    owner  => 'root',
    group  => 'root',
    mode   => '0600',
    notify => Exec["Build ${build_base}/${title} as ${title}"],
  }
  
  if $no_cache {
    $no_cache_flag = "-no-cache"
  } else {
    $no_cache_flag = ""
  }
  #notify {"${title}: '${no_cache_flag}'": }
  # "docker build" currently returns 0 as exit code even when failing, 
  # currently work-around is an ugly hack.
  # "tee build.log" gives a log of the build process
  # "tail -n 1" makes sure we only grep the LAST line.
  # "grep -q" fails with exitcode 1 if 'Successfully built' is not on the last line.
  # On failure we delete "Dockerfile" to make sure we will run again next time Puppet
  # runs. We then lastly exit with exitcode 2.
  exec { "Build ${build_base}/${title} as ${title}":
    command => "/bin/sh -c \"/usr/bin/docker build ${no_cache_flag} -t='${title}' . | tee build.log | tail -n 1 | grep -q 'Successfully built' || (rm Dockerfile && exit 2)\"",
    cwd     => "${build_base}/${title}",
    refreshonly => true,
    timeout     => 3600, # A build can take a VERY long time...
  }
  
}

define prepare_extra_files (
  $build_base,
  $build_title,
) {
  #notify { "prepare_extra_files_1: ${build_title} ${settings::confdir} ${name[target]}": }
  if "${name[target]}" =~ /^(.*\/)?.+$/ {
    $new_path = "$1"
    #notify("prepare_extra_files_2: ${build_title} ${name[target]}")
    exec { "create all directories for ${build_title}/${name[target]}-${new_path}":
      command => "/bin/bash -c 'umask 077 && /bin/mkdir -p ${build_base}/${build_title}/${new_path}'",
      creates => "${build_base}/${build_title}/${new_path}",
      before  => File["${build_base}/${build_title}/${name[target]}"],
    }
    file { "${build_base}/${build_title}/${name[target]}":
      ensure  => present,
      source  => "${name[source]}",
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
    }
  }
}