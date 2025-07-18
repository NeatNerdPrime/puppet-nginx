# frozen_string_literal: true

require 'spec_helper'

describe 'nginx' do
  on_supported_os.each do |os, facts|
    context "on #{os} with Facter #{facts[:facterversion]} and Puppet #{facts[:puppetversion]}" do
      let(:facts) do
        facts
      end

      let :params do
        {
          nginx_upstreams: { 'upstream1' => { 'members' => { 'localhost' => { 'port' => 3000 } } } },
          nginx_servers: { 'test2.local' => { 'www_root' => '/' } },
          nginx_servers_defaults: { 'listen_options' => 'default_server' },
          nginx_locations: { 'test2.local' => { 'server' => 'test2.local', 'www_root' => '/' } },
          nginx_locations_defaults: { 'expires' => '@12h34m' },
          mail: true,
          nginx_mailhosts: { 'smtp.test2.local' => { 'auth_http' => 'server2.example/cgi-bin/auth', 'protocol' => 'smtp', 'listen_port' => 587 } },
          nginx_mailhosts_defaults: { 'listen_options' => 'default_server_smtp' },
          nginx_streamhosts: { 'streamhost1' => { 'proxy' => 'streamproxy' } }
        }
      end

      describe 'with defaults' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('nginx') }
        it { is_expected.to contain_class('nginx::config').that_requires('Class[nginx::package]') }
        it { is_expected.to contain_class('nginx::service').that_subscribes_to('Class[nginx::package]') }
        it { is_expected.to contain_class('nginx::service').that_subscribes_to('Class[nginx::config]') }
        it { is_expected.to contain_nginx__resource__upstream('upstream1') }
        it { is_expected.to contain_nginx__resource__server('test2.local') }
        it { is_expected.to contain_nginx__resource__server('test2.local').with_listen_options('default_server') }
        it { is_expected.to contain_nginx__resource__location('test2.local') }
        it { is_expected.to contain_nginx__resource__location('test2.local').with_expires('@12h34m') }
        it { is_expected.to contain_nginx__resource__mailhost('smtp.test2.local') }
        it { is_expected.to contain_nginx__resource__mailhost('smtp.test2.local').with_listen_options('default_server_smtp') }
        it { is_expected.to contain_nginx__resource__streamhost('streamhost1').with_proxy('streamproxy') }
      end

      context 'nginx::package' do
        it { is_expected.to compile.with_all_deps }

        case facts[:os]['family']
        when 'RedHat'
          context 'using defaults' do
            it { is_expected.to contain_package('nginx') }

            it do
              is_expected.to contain_yumrepo('nginx-release').with(
                'baseurl'  => "https://nginx.org/packages/#{%w[CentOS VirtuozzoLinux OracleLinux].include?(facts[:os]['name']) ? 'centos' : 'rhel'}/#{facts[:os]['release']['major']}/$basearch/",
                'descr'    => 'nginx repo',
                'enabled'  => '1',
                'gpgcheck' => '1',
                'priority' => '1',
                'gpgkey'   => 'https://nginx.org/keys/nginx_signing.key'
              )
            end

            it do
              is_expected.to contain_yumrepo('passenger').with(
                'ensure' => 'absent'
              )
            end

            it { is_expected.to contain_yumrepo('nginx-release').that_comes_before('Package[nginx]') }
            it { is_expected.to contain_yumrepo('passenger').that_comes_before('Package[nginx]') }
          end

          context 'using default repo without passenger' do
            let(:params) { { purge_passenger_repo: false } }

            it { is_expected.to contain_package('nginx') }

            it do
              is_expected.to contain_yumrepo('nginx-release').with(
                'baseurl'  => "https://nginx.org/packages/#{%w[CentOS VirtuozzoLinux OracleLinux].include?(facts[:os]['name']) ? 'centos' : 'rhel'}/#{facts[:os]['release']['major']}/$basearch/",
                'descr'    => 'nginx repo',
                'enabled'  => '1',
                'gpgcheck' => '1',
                'priority' => '1',
                'gpgkey'   => 'https://nginx.org/keys/nginx_signing.key'
              )
            end

            it { is_expected.not_to contain_yumrepo('passenger') }
          end

          context 'package_source => nginx-mainline' do
            let(:params) { { package_source: 'nginx-mainline' } }

            it do
              is_expected.to contain_yumrepo('nginx-release').with(
                'baseurl' => "https://nginx.org/packages/mainline/#{%w[CentOS VirtuozzoLinux OracleLinux].include?(facts[:os]['name']) ? 'centos' : 'rhel'}/#{facts[:os]['release']['major']}/$basearch/"
              )
            end

            it do
              is_expected.to contain_yumrepo('passenger').with(
                'ensure' => 'absent'
              )
            end

            it { is_expected.to contain_yumrepo('nginx-release').that_comes_before('Package[nginx]') }
            it { is_expected.to contain_yumrepo('passenger').that_comes_before('Package[nginx]') }
          end

          context 'package_source => passenger', unless: facts[:os]['release']['major'] == '8' do
            let(:params) { { package_source: 'passenger' } }

            it do
              is_expected.to contain_yumrepo('passenger').with(
                'baseurl'       => "https://oss-binaries.phusionpassenger.com/yum/passenger/el/#{facts[:os]['release']['major']}/$basearch",
                'gpgcheck'      => '0',
                'repo_gpgcheck' => '1',
                'gpgkey'        => 'https://oss-binaries.phusionpassenger.com/auto-software-signing-gpg-key.txt'
              )
            end

            it do
              is_expected.to contain_yumrepo('nginx-release').with(
                'ensure' => 'absent'
              )
            end

            it { is_expected.to contain_yumrepo('passenger').that_comes_before('Package[nginx]') }
            it { is_expected.to contain_yumrepo('nginx-release').that_comes_before('Package[nginx]') }
            it { is_expected.to contain_package('passenger').with('ensure' => 'installed') }
          end

          describe 'installs the requested passenger package version', unless: facts[:os]['release']['major'] == '8' do
            let(:params) { { package_source: 'passenger', passenger_package_ensure: '4.1.0-1.el9' } }

            it 'installs specified version exactly' do
              is_expected.to contain_package('passenger').with('ensure' => '4.1.0-1.el9')
            end
          end

          context 'manage_repo => false' do
            let(:params) { { manage_repo: false } }

            it { is_expected.to contain_package('nginx') }
            it { is_expected.not_to contain_yumrepo('nginx-release') }
          end

          describe 'installs the requested package version' do
            let(:params) { { package_ensure: '3.0.0' } }

            it 'installs 3.0.0 exactly' do
              is_expected.to contain_package('nginx').with('ensure' => '3.0.0')
            end
          end

        when 'Debian'
          context 'using defaults' do
            it { is_expected.to contain_package('nginx') }
            it { is_expected.not_to contain_package('passenger') }

            it do
              is_expected.to contain_apt__source('nginx').with(
                'location' => "https://nginx.org/packages/#{facts[:os]['name'].downcase}",
                'repos'    => 'nginx',
                'key'      => {
                  'source' => 'https://nginx.org/keys/nginx_signing.key',
                  'name' => 'nginx.asc'
                }
              )
            end
          end

          context 'repo_source' do
            let(:params) { { repo_source: 'https://example.com/nginx' } }

            it do
              is_expected.to contain_apt__source('nginx').with(
                'location' => 'https://example.com/nginx'
              )
            end
          end

          context 'package_source => nginx-mainline' do
            let(:params) { { package_source: 'nginx-mainline' } }

            it do
              is_expected.to contain_apt__source('nginx').with(
                'location' => "https://nginx.org/packages/mainline/#{facts[:os]['name'].downcase}"
              )
            end
          end

          context "package_source => 'passenger'" do
            let(:params) { { package_source: 'passenger' } }

            it { is_expected.to contain_package('nginx') }
            it { is_expected.to contain_package('libnginx-mod-http-passenger') }

            it do
              is_expected.to contain_apt__source('nginx').with(
                'location' => 'https://oss-binaries.phusionpassenger.com/apt/passenger',
                'repos'    => 'main',
                'key'      => {
                  'source' => 'https://oss-binaries.phusionpassenger.com/auto-software-signing-gpg-key.txt',
                  'name' => 'phusionpassenger.asc'
                }
              )
            end
          end

          context 'manage_repo => false' do
            let(:params) { { manage_repo: false } }

            it { is_expected.to contain_package('nginx') }
            it { is_expected.not_to contain_apt__source('nginx') }
            it { is_expected.not_to contain_package('passenger') }
          end
        when 'Archlinux'
          context 'using defaults' do
            it { is_expected.to contain_package('nginx-mainline') }
          end
        else
          it { is_expected.to contain_package('nginx') }
        end
      end

      context 'nginx::service' do
        let :params do
          {
            service_ensure: 'running',
            service_enable: true,
            service_name: 'nginx',
            service_manage: true
          }
        end

        context 'using default parameters' do
          it do
            is_expected.to contain_service('nginx').with(
              ensure: 'running',
              enable: true
            )
          end

          it { is_expected.to contain_service('nginx').without_restart }
        end

        context "when service_restart => 'a restart command'" do
          let :params do
            {
              service_restart: 'a restart command',
              service_ensure: 'running',
              service_enable: true,
              service_name: 'nginx'
            }
          end

          it { is_expected.to contain_service('nginx').with_restart('a restart command') }
        end

        describe "when service_name => 'nginx14" do
          let :params do
            {
              service_name: 'nginx14'
            }
          end

          it { is_expected.to contain_service('nginx14') }
        end

        describe 'when service_manage => false' do
          let :params do
            {
              service_manage: false
            }
          end

          it { is_expected.not_to contain_service('nginx') }
        end
      end

      # nginx::config
      context 'nginx::config' do
        context 'with defaults' do
          it do
            is_expected.to contain_file('/etc/nginx').only_with(
              path: '/etc/nginx',
              ensure: 'directory',
              owner: 'root',
              group: 'root',
              mode: '0644'
            )
          end

          it do
            is_expected.to contain_file('/etc/nginx/conf.d').only_with(
              path: '/etc/nginx/conf.d',
              ensure: 'directory',
              owner: 'root',
              group: 'root',
              mode: '0644'
            )
          end

          it do
            is_expected.to contain_file('/etc/nginx/conf.stream.d').only_with(
              path: '/etc/nginx/conf.stream.d',
              ensure: 'directory',
              owner: 'root',
              group: 'root',
              mode: '0644'
            )
          end

          it do
            is_expected.to contain_file('/etc/nginx/conf.mail.d').only_with(
              path: '/etc/nginx/conf.mail.d',
              ensure: 'directory',
              owner: 'root',
              group: 'root',
              mode: '0644'
            )
          end

          it do
            is_expected.to contain_file('/etc/nginx/nginx.conf').with(
              ensure: 'file',
              owner: 'root',
              group: 'root',
              mode: '0644'
            )
          end

          it do
            is_expected.to contain_file('/etc/nginx/mime.types').with(
              ensure: 'file',
              owner: 'root',
              group: 'root',
              mode: '0644'
            )
          end

          it do
            is_expected.to contain_file('/tmp/nginx.d').with(
              ensure: 'absent',
              purge: true,
              recurse: true
            )
          end

          it do
            is_expected.to contain_file('/tmp/nginx.mail.d').with(
              ensure: 'absent',
              purge: true,
              recurse: true
            )
          end

          context 'manage_log_dir => false' do
            let(:params) { { manage_log_dir: false } }

            it do
              is_expected.to contain_file('/var/log/nginx').with(
                replace: false
              )
            end
          end

          case facts[:os]['family']
          when 'RedHat'
            it { is_expected.to contain_file('/etc/nginx/nginx.conf').with_content %r{^user nginx;} }

            it do
              is_expected.to contain_file('/var/log/nginx').with(
                ensure: 'directory',
                owner: 'nginx',
                group: 'nginx',
                mode: '0750',
                replace: true
              )
            end
          when 'Debian'
            it { is_expected.to contain_file('/etc/nginx/nginx.conf').with_content %r{^user www-data;} }

            it do
              is_expected.to contain_file('/var/log/nginx').with(
                ensure: 'directory',
                owner: 'root',
                group: 'adm',
                mode: '0755',
                replace: true
              )
            end
          end

          describe 'nginx.conf template content' do
            [
              {
                title: 'should not set load_module',
                attr: 'dynamic_modules',
                value: :undef,
                notmatch: %r{load_module}
              },
              {
                title: 'should not set user',
                attr: 'super_user',
                value: false,
                notmatch: %r{user}
              },
              {
                title: 'should not set group',
                attr: 'daemon_group',
                value: :undef,
                notmatch: %r{^user \S+ \S+;}
              },
              {
                title: 'should set user',
                attr: 'daemon_user',
                value: 'test-user',
                match: 'user test-user;'
              },
              {
                title: 'should not set daemon',
                attr: 'daemon',
                value: :undef,
                notmatch: %r{^\s*daemon\s+}
              },
              {
                title: 'should set daemon on',
                attr: 'daemon',
                value: 'on',
                match: %r{^daemon\s+on;$}
              },
              {
                title: 'should set daemon off',
                attr: 'daemon',
                value: 'off',
                match: %r{^daemon\s+off;$}
              },
              {
                title: 'should set worker_processes',
                attr: 'worker_processes',
                value: 4,
                match: 'worker_processes 4;'
              },
              {
                title: 'should set worker_processes',
                attr: 'worker_processes',
                value: 'auto',
                match: 'worker_processes auto;'
              },
              {
                title: 'should set worker_rlimit_nofile',
                attr: 'worker_rlimit_nofile',
                value: 10_000,
                match: 'worker_rlimit_nofile 10000;'
              },
              {
                title: 'should set pcre_jit',
                attr: 'pcre_jit',
                value: 'on',
                match: %r{^\s*pcre_jit\s+on;}
              },
              {
                title: 'should set error_log',
                attr: 'nginx_error_log',
                value: '/path/to/error.log',
                match: '  error_log /path/to/error.log error;'
              },
              {
                title: 'should set multiple error_logs',
                attr: 'nginx_error_log',
                value: ['/path/to/error.log', 'syslog:server=localhost'],
                match: [
                  '  error_log /path/to/error.log error;',
                  '  error_log syslog:server=localhost error;'
                ]
              },
              {
                title: 'should set error_log severity level',
                attr: 'nginx_error_log_severity',
                value: 'warn',
                match: '  error_log /var/log/nginx/error.log warn;'
              },
              {
                title: 'should set limit_req_zone',
                attr: 'limit_req_zone',
                value: [
                  '$binary_remote_addr zone=myzone1:10m rate=5r/s',
                  '$binary_remote_addr zone=myzone2:10m rate=5r/s'
                ],
                match: [
                  '  limit_req_zone $binary_remote_addr zone=myzone1:10m rate=5r/s;',
                  '  limit_req_zone $binary_remote_addr zone=myzone2:10m rate=5r/s;'
                ]
              },
              {
                title: 'should set pid',
                attr: 'pid',
                value: '/path/to/pid',
                match: 'pid        /path/to/pid;'
              },
              {
                title: 'should not set pid',
                attr: 'pid',
                value: false,
                notmatch: %r{pid}
              },
              {
                title: 'should not set absolute_redirect',
                attr: 'absolute_redirect',
                value: :undef,
                notmatch: %r{absolute_redirect}
              },
              {
                title: 'should set absolute_redirect off',
                attr: 'absolute_redirect',
                value: 'off',
                match: '  absolute_redirect off;'
              },
              {
                title: 'should set accept_mutex on',
                attr: 'accept_mutex',
                value: 'on',
                match: '  accept_mutex on;'
              },
              {
                title: 'should set accept_mutex off',
                attr: 'accept_mutex',
                value: 'off',
                match: '  accept_mutex off;'
              },
              {
                title: 'should set accept_mutex_delay',
                attr: 'accept_mutex_delay',
                value: '500s',
                match: '  accept_mutex_delay 500s;'
              },
              {
                title: 'should set worker_connections',
                attr: 'worker_connections',
                value: 100,
                match: '  worker_connections 100;'
              },
              {
                title: 'should set log formats',
                attr: 'log_format',
                value: {
                  'format1' => 'FORMAT1',
                  'format2' => 'FORMAT2',
                  'format3' => {
                    'format' => 'FORMAT3',
                  },
                  'format4' => {
                    'escape' => 'json',
                    'format' => '{"response": $status, "verb": "$request_method"}',
                  },
                },
                match: [
                  '  log_format format1 "FORMAT1";',
                  '  log_format format2 "FORMAT2";',
                  '  log_format format3 "FORMAT3";',
                  '  log_format format4 escape=json "{\\"response\\": $status, \\"verb\\": \\"$request_method\\"}";'
                ]
              },
              {
                title: 'should not set log formats',
                attr: 'log_format',
                value: {},
                notmatch: %r{log_format}
              },
              {
                title: 'should set multi_accept',
                attr: 'multi_accept',
                value: 'on',
                match: %r{\s*multi_accept\s+on;}
              },
              {
                title: 'should not set multi_accept',
                attr: 'multi_accept',
                value: 'off',
                notmatch: %r{multi_accept}
              },
              {
                title: 'should set etag',
                attr: 'etag',
                value: 'off',
                match: '  etag off;'
              },
              {
                title: 'should set events_use',
                attr: 'events_use',
                value: 'eventport',
                match: %r{\s*use\s+eventport;}
              },
              {
                title: 'should set access_log',
                attr: 'http_access_log',
                value: '/path/to/access.log',
                match: '  access_log /path/to/access.log;'
              },
              {
                title: 'should set multiple access_logs',
                attr: 'http_access_log',
                value: ['/path/to/access.log', 'syslog:server=localhost'],
                match: [
                  '  access_log /path/to/access.log;',
                  '  access_log syslog:server=localhost;'
                ]
              },
              {
                title: 'should set custom log format',
                attr: 'http_format_log',
                value: 'mycustomformat',
                match: '  access_log /var/log/nginx/access.log mycustomformat;'
              },
              {
                title: 'should set sendfile',
                attr: 'sendfile',
                value: 'on',
                match: '  sendfile on;'
              },
              {
                title: 'should not set sendfile',
                attr: 'sendfile',
                value: 'off',
                notmatch: %r{sendfile}
              },
              {
                title: 'should set server_tokens',
                attr: 'server_tokens',
                value: 'on',
                match: '  server_tokens on;'
              },
              {
                title: 'should set types_hash_max_size',
                attr: 'types_hash_max_size',
                value: 10,
                match: '  types_hash_max_size 10;'
              },
              {
                title: 'should set types_hash_bucket_size',
                attr: 'types_hash_bucket_size',
                value: 10,
                match: '  types_hash_bucket_size 10;'
              },
              {
                title: 'should set server_names_hash_bucket_size',
                attr: 'names_hash_bucket_size',
                value: 10,
                match: '  server_names_hash_bucket_size 10;'
              },
              {
                title: 'should set server_names_hash_max_size',
                attr: 'names_hash_max_size',
                value: 10,
                match: '  server_names_hash_max_size 10;'
              },
              {
                title: 'should set map_hash_bucket_size',
                attr: 'map_hash_bucket_size',
                value: 32,
                match: '  map_hash_bucket_size 32;'
              },
              {
                title: 'should set map_hash_max_size',
                attr: 'map_hash_max_size',
                value: 2048,
                match: '  map_hash_max_size 2048;'
              },
              {
                title: 'should set keepalive_timeout',
                attr: 'keepalive_timeout',
                value: '123',
                match: '  keepalive_timeout   123;'
              },
              {
                title: 'should set keepalive_requests',
                attr: 'keepalive_requests',
                value: 345,
                match: '  keepalive_requests  345;'
              },
              {
                title: 'should set client_body_timeout',
                attr: 'client_body_timeout',
                value: '888',
                match: '  client_body_timeout 888;'
              },
              {
                title: 'should set send_timeout',
                attr: 'send_timeout',
                value: '963',
                match: '  send_timeout        963;'
              },
              {
                title: 'should set lingering_close',
                attr: 'lingering_close',
                value: 'always',
                match: '  lingering_close      always;'
              },
              {
                title: 'should set lingering_time',
                attr: 'lingering_time',
                value: '30s',
                match: '  lingering_time      30s;'
              },
              {
                title: 'should set lingering_timeout',
                attr: 'lingering_timeout',
                value: '385',
                match: '  lingering_timeout   385;'
              },
              {
                title: 'should set tcp_nodelay',
                attr: 'http_tcp_nodelay',
                value: 'on',
                match: '  tcp_nodelay         on;'
              },
              {
                title: 'should set tcp_nopush',
                attr: 'http_tcp_nopush',
                value: 'on',
                match: '  tcp_nopush on;'
              },
              {
                title: 'should not set gzip',
                attr: 'gzip',
                value: 'off',
                notmatch: %r{gzip}
              },
              {
                title: 'should set proxy_cache_path',
                attr: 'proxy_cache_path',
                value: '/path/to/proxy.cache',
                match: %r{\s+proxy_cache_path\s+/path/to/proxy.cache levels=1 keys_zone=d2:100m max_size=500m inactive=20m;}
              },
              {
                title: 'should set proxy_cache_path from hash',
                attr: 'proxy_cache_path',
                value: { '/path/to/proxy.cache' => 'd2:100m' },
                match: %r{\s+proxy_cache_path\s+/path/to/proxy.cache levels=1 keys_zone=d2:100m max_size=500m inactive=20m;}
              },
              {
                title: 'should set fastcgi_cache_path',
                attr: 'fastcgi_cache_path',
                value: '/path/to/proxy.cache',
                match: %r{\s*fastcgi_cache_path\s+/path/to/proxy.cache levels=1 keys_zone=d3:100m max_size=500m inactive=20m;}
              },
              {
                title: 'should set fastcgi_cache_use_stale',
                attr: 'fastcgi_cache_use_stale',
                value: 'invalid_header',
                match: '  fastcgi_cache_use_stale invalid_header;'
              },
              {
                title: 'should contain http_raw_prepend directives',
                attr: 'http_raw_prepend',
                value: [
                  'if (a) {',
                  '  b;',
                  '}'
                ],
                match: %r{^\s+if \(a\) \{\n\s++b;\n\s+\}}
              },
              {
                title: 'should contain ordered appended directives from hash',
                attr: 'http_cfg_prepend',
                value: { 'test1' => 'test value 1', 'test2' => 'test value 2', 'allow' => 'test value 3' },
                match: [
                  '  allow test value 3;',
                  '  test1 test value 1;',
                  '  test2 test value 2;'
                ]
              },
              {
                title: 'should contain duplicate appended directives from list of hashes',
                attr: 'http_cfg_prepend',
                value: [['allow', 'test value 1'], ['allow', 'test value 2']],
                match: [
                  '  allow test value 1;',
                  '  allow test value 2;'
                ]
              },
              {
                title: 'should contain duplicate appended directives from array values',
                attr: 'http_cfg_prepend',
                value: { 'test1' => ['test value 1', 'test value 2', 'test value 3'] },
                match: [
                  '  test1 test value 1;',
                  '  test1 test value 2;'
                ]
              },
              {
                title: 'should contain http_raw_append directives',
                attr: 'http_raw_append',
                value: [
                  'if (a) {',
                  '  b;',
                  '}'
                ],
                match: %r{^\s+if \(a\) \{\n\s++b;\n\s+\}}
              },
              {
                title: 'should contain ordered appended directives from hash',
                attr: 'http_cfg_append',
                value: { 'test1' => 'test value 1', 'test2' => 'test value 2', 'allow' => 'test value 3' },
                match: [
                  '  allow test value 3;',
                  '  test1 test value 1;',
                  '  test2 test value 2;'
                ]
              },
              {
                title: 'should contain duplicate appended directives from list of hashes',
                attr: 'http_cfg_append',
                value: [['allow', 'test value 1'], ['allow', 'test value 2']],
                match: [
                  '  allow test value 1;',
                  '  allow test value 2;'
                ]
              },
              {
                title: 'should contain duplicate appended directives from array values',
                attr: 'http_cfg_append',
                value: { 'test1' => ['test value 1', 'test value 2', 'test value 3'] },
                match: [
                  '  test1 test value 1;',
                  '  test1 test value 2;'
                ]
              },
              {
                title: 'should contain ordered appended directives from hash',
                attr: 'nginx_cfg_prepend',
                value: { 'test1' => 'test value 1', 'test2' => 'test value 2', 'allow' => 'test value 3' },
                match: [
                  'allow test value 3;',
                  'test1 test value 1;',
                  'test2 test value 2;'
                ]
              },
              {
                title: 'should contain duplicate appended directives from list of hashes',
                attr: 'nginx_cfg_prepend',
                value: [['allow', 'test value 1'], ['allow', 'test value 2']],
                match: [
                  'allow test value 1;',
                  'allow test value 2;'
                ]
              },
              {
                title: 'should contain duplicate appended directives from array values',
                attr: 'nginx_cfg_prepend',
                value: { 'test1' => ['test value 1', 'test value 2', 'test value 3'] },
                match: [
                  'test1 test value 1;',
                  'test1 test value 2;',
                  'test1 test value 3;'
                ]
              },
              {
                title: 'should set pid',
                attr: 'pid',
                value: '/path/to/pid',
                match: 'pid        /path/to/pid;'
              },
              {
                title: 'should set mail',
                attr: 'mail',
                value: true,
                match: 'mail {'
              },
              {
                title: 'should not set mail',
                attr: 'mail',
                value: false,
                notmatch: %r{mail}
              },
              {
                title: 'should set proxy_buffers',
                attr: 'proxy_buffers',
                value: '50 5k',
                match: '  proxy_buffers           50 5k;'
              },
              {
                title: 'should set proxy_buffer_size',
                attr: 'proxy_buffer_size',
                value: '2k',
                match: '  proxy_buffer_size       2k;'
              },
              {
                title: 'should set proxy_http_version',
                attr: 'proxy_http_version',
                value: '1.1',
                match: '  proxy_http_version      1.1;'
              },
              {
                title: 'should not set proxy_http_version',
                attr: 'proxy_http_version',
                value: nil,
                notmatch: 'proxy_http_version'
              },
              {
                title: 'should contain ordered appended proxy_set_header directives',
                attr: 'proxy_set_header',
                value: %w[header1 header2],
                match: [
                  '  proxy_set_header        header1;',
                  '  proxy_set_header        header2;'
                ]
              },
              {
                title: 'should contain ordered appended proxy_hide_header directives',
                attr: 'proxy_hide_header',
                value: %w[header1 header2],
                match: [
                  '  proxy_hide_header        header1;',
                  '  proxy_hide_header        header2;'
                ]
              },
              {
                title: 'should contain ordered appended proxy_pass_header directives',
                attr: 'proxy_pass_header',
                value: %w[header1 header2],
                match: [
                  '  proxy_pass_header        header1;',
                  '  proxy_pass_header        header2;'
                ]
              },
              {
                title: 'should set client_body_temp_path',
                attr: 'client_body_temp_path',
                value: '/path/to/body_temp',
                match: '  client_body_temp_path   /path/to/body_temp;'
              },
              {
                title: 'should set client_body_temp_path with subdirectory hierarchy',
                attr: 'client_body_temp_path',
                value: [
                  '/path/to/body_temp',
                  1,
                  2,
                  3
                ],
                match: '  client_body_temp_path   /path/to/body_temp 1 2 3;'
              },
              {
                title: 'should set proxy_temp_path',
                attr: 'proxy_temp_path',
                value: '/path/to/proxy_temp',
                match: '  proxy_temp_path         /path/to/proxy_temp;'
              },
              {
                title: 'should set proxy_temp_path with subdirectory hierarchy',
                attr: 'proxy_temp_path',
                value: [
                  '/path/to/proxy_temp',
                  1,
                  2,
                  3
                ],
                match: '  proxy_temp_path         /path/to/proxy_temp 1 2 3;'
              },
              {
                title: 'should set proxy_max_temp_file_size',
                attr: 'proxy_max_temp_file_size',
                value: '1024m',
                match: '  proxy_max_temp_file_size 1024m;'
              },
              {
                title: 'should set proxy_busy_buffers_size',
                attr: 'proxy_busy_buffers_size',
                value: '16k',
                match: '  proxy_busy_buffers_size 16k;'
              },
              {
                title: 'should set ssl_stapling_verify',
                attr: 'ssl_stapling_verify',
                value: 'on',
                match: '  ssl_stapling_verify       on;'
              },
              {
                title: 'should set ssl_protocols',
                attr: 'ssl_protocols',
                value: 'TLSv1.2',
                match: '  ssl_protocols             TLSv1.2;'
              },
              {
                title: 'should set ssl_ciphers',
                attr: 'ssl_ciphers',
                value: 'ECDHE-ECDSA-CHACHA20-POLY1305',
                match: '  ssl_ciphers               ECDHE-ECDSA-CHACHA20-POLY1305;'
              },
              {
                title: 'should set ssl_dhparam',
                attr: 'ssl_dhparam',
                value: '/path/to/dhparam',
                match: '  ssl_dhparam               /path/to/dhparam;'
              },
              {
                title: 'should not set ssl_ecdh_curve',
                attr: 'ssl_ecdh_curve',
                value: :undef,
                notmatch: 'ssl_ecdh_curve'
              },
              {
                title: 'should set ssl_ecdh_curve',
                attr: 'ssl_ecdh_curve',
                value: 'prime256v1:secp384r1',
                match: '  ssl_ecdh_curve            prime256v1:secp384r1;'
              },
              {
                title: 'should set ssl_session_cache',
                attr: 'ssl_session_cache',
                value: 'shared:SSL:10m',
                match: '  ssl_session_cache         shared:SSL:10m;'
              },
              {
                title: 'should set ssl_session_timeout',
                attr: 'ssl_session_timeout',
                value: '5m',
                match: '  ssl_session_timeout       5m;'
              },
              {
                title: 'should not set ssl_session_tickets',
                attr: 'ssl_session_tickets',
                value: :undef,
                notmatch: 'ssl_session_tickets'
              },
              {
                title: 'should set ssl_session_tickets',
                attr: 'ssl_session_tickets',
                value: 'on',
                match: '  ssl_session_tickets       on;'
              },
              {
                title: 'should not set ssl_session_ticket_key',
                attr: 'ssl_session_ticket_key',
                value: :undef,
                notmatch: 'ssl_session_ticket_key'
              },
              {
                title: 'should set ssl_session_ticket_key',
                attr: 'ssl_session_ticket_key',
                value: '/path/to/ticket_key',
                match: '  ssl_session_ticket_key    /path/to/ticket_key;'
              },
              {
                title: 'should not set ssl_buffer_size',
                attr: 'ssl_buffer_size',
                value: :undef,
                notmatch: 'ssl_buffer_size'
              },
              {
                title: 'should set ssl_buffer_size',
                attr: 'ssl_buffer_size',
                value: '16k',
                match: '  ssl_buffer_size           16k;'
              },
              {
                title: 'should not set ssl_crl',
                attr: 'ssl_crl',
                value: :undef,
                notmatch: 'ssl_crl'
              },
              {
                title: 'should set ssl_crl',
                attr: 'ssl_crl',
                value: '/path/to/crl',
                match: '  ssl_crl                   /path/to/crl;'
              },
              {
                title: 'should not set ssl_stapling_file',
                attr: 'ssl_stapling_file',
                value: :undef,
                notmatch: 'ssl_stapling_file'
              },
              {
                title: 'should set ssl_stapling_file',
                attr: 'ssl_stapling_file',
                value: '/path/to/stapling_file',
                match: '  ssl_stapling_file         /path/to/stapling_file;'
              },
              {
                title: 'should not set ssl_stapling_responder',
                attr: 'ssl_stapling_responder',
                value: :undef,
                notmatch: 'ssl_stapling_responder'
              },
              {
                title: 'should set ssl_stapling_responder',
                attr: 'ssl_stapling_responder',
                value: 'http://stapling.responder/',
                match: '  ssl_stapling_responder    http://stapling.responder/;'
              },
              {
                title: 'should not set ssl_trusted_certificate',
                attr: 'ssl_trusted_certificate',
                value: :undef,
                notmatch: 'ssl_trusted_certificate'
              },
              {
                title: 'should set ssl_trusted_certificate',
                attr: 'ssl_trusted_certificate',
                value: '/path/to/trusted_cert',
                match: '  ssl_trusted_certificate   /path/to/trusted_cert;'
              },
              {
                title: 'should not set ssl_verify_depth',
                attr: 'ssl_verify_depth',
                value: :undef,
                notmatch: 'ssl_verify_depth'
              },
              {
                title: 'should set ssl_verify_depth',
                attr: 'ssl_verify_depth',
                value: 5,
                match: '  ssl_verify_depth          5;'
              },
              {
                title: 'should not set ssl_password_file',
                attr: 'ssl_password_file',
                value: :undef,
                notmatch: 'ssl_password_file'
              },
              {
                title: 'should set ssl_password_file',
                attr: 'ssl_password_file',
                value: '/path/to/password_file',
                match: '  ssl_password_file         /path/to/password_file;'
              },
              {
                title: 'should contain debug_connection directives',
                attr: 'debug_connections',
                value: %w[127.0.0.1 unix:],
                match: [
                  '  debug_connection 127.0.0.1;',
                  '  debug_connection unix:;'
                ]
              },
              {
                title: 'should set reset_timedout_connection',
                attr: 'reset_timedout_connection',
                value: 'on',
                match: %r{^\s+reset_timedout_connection\s+on;}
              }
            ].each do |param|
              context "when #{param[:attr]} is #{param[:value]}" do
                let(:params) { { param[:attr].to_sym => param[:value] } }

                it { is_expected.to contain_file('/etc/nginx/nginx.conf').with_mode('0644') }

                it param[:title] do
                  matches = Array(param[:match])

                  if matches.all? { |m| m.is_a? Regexp }
                    matches.each { |item| is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(item) }
                  else
                    lines = catalogue.resource('file', '/etc/nginx/nginx.conf').send(:parameters)[:content].split("\n")
                    expect(lines & Array(param[:match])).to eq(Array(param[:match]))
                  end

                  # if we have a _path attribute make sure we create the path
                  if param[:attr].end_with?('_path')
                    if %w[client_body_temp_path proxy_temp_path].include?(param[:attr]) && param[:value].is_a?(Array)
                      is_expected.to contain_file(param[:value][0]).with_ensure('directory')
                    elsif param[:value].is_a?(Hash)
                      param[:value].each_key do |path|
                        is_expected.to contain_file(path).with_ensure('directory')
                      end
                    else
                      is_expected.to contain_file(param[:value]).with_ensure('directory')
                    end
                  end

                  Array(param[:notmatch]).each do |item|
                    is_expected.to contain_file('/etc/nginx/nginx.conf').without_content(item)
                  end
                end
              end
            end
          end

          context 'when mime.types is "[\'text/css css\']"' do
            let(:params) do
              {
                mime_types: { 'text/css' => 'css' }
              }
            end

            it { is_expected.to contain_file('/etc/nginx/mime.types').with_content(%r{text/css css;}) }
          end

          context 'when mime.types is default' do
            it { is_expected.to contain_file('/etc/nginx/mime.types').with_content(%r{text/css css;}) }
            it { is_expected.to contain_file('/etc/nginx/mime.types').with_content(%r{audio/mpeg mp3;}) }
          end

          context 'when mime.types is "[custom/file customfile]" and mime.types.preserve.defaults is true' do
            let(:params) do
              {
                mime_types: { 'custom/file' => 'customfile' },
                mime_types_preserve_defaults: true
              }
            end

            it { is_expected.to contain_file('/etc/nginx/mime.types').with_content(%r{audio/mpeg mp3;}) }
            it { is_expected.to contain_file('/etc/nginx/mime.types').with_content(%r{custom/file customfile;}) }
          end

          context 'when dynamic_modules is "[ngx_http_geoip_module]"' do
            let(:params) do
              {
                dynamic_modules: ['ngx_http_geoip_module']
              }
            end

            it { is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(%r{load_module "modules/ngx_http_geoip_module.so";}) }
          end

          context 'when dynamic_modules is "[/path/to/module/ngx_http_geoip_module.so]"' do
            let(:params) do
              {
                dynamic_modules: ['/path/to/module/ngx_http_geoip_module.so']
              }
            end

            it { is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(%r{load_module "/path/to/module/ngx_http_geoip_module.so";}) }
          end

          context 'when proxy_cache_path is /path/to/proxy.cache and loader_files is 1000' do
            let(:params) do
              {
                conf_dir: '/path/to/nginx',
                proxy_cache_path: '/path/to/proxy.cache',
                proxy_cache_loader_files: 1000
              }
            end

            it { is_expected.to contain_file('/path/to/nginx/nginx.conf').with_content(%r{\s+proxy_cache_path\s+/path/to/proxy.cache levels=1 keys_zone=d2:100m max_size=500m inactive=20m loader_files=1000;}) }
          end

          context 'when proxy_cache_path is /path/to/nginx and loader_sleep is 50ms' do
            let(:params) { { conf_dir: '/path/to/nginx', proxy_cache_path: '/path/to/proxy.cache', proxy_cache_loader_sleep: '50ms' } }

            it { is_expected.to contain_file('/path/to/nginx/nginx.conf').with_content(%r{\s+proxy_cache_path\s+/path/to/proxy.cache levels=1 keys_zone=d2:100m max_size=500m inactive=20m loader_sleep=50ms;}) }
          end

          context 'when proxy_cache_path is /path/to/nginx and loader_threshold is 300ms' do
            let(:params) { { conf_dir: '/path/to/nginx', proxy_cache_path: '/path/to/proxy.cache', proxy_cache_loader_threshold: '300ms' } }

            it { is_expected.to contain_file('/path/to/nginx/nginx.conf').with_content(%r{\s+proxy_cache_path\s+/path/to/proxy.cache levels=1 keys_zone=d2:100m max_size=500m inactive=20m loader_threshold=300ms;}) }
          end

          context 'when conf_dir is /path/to/nginx' do
            let(:params) { { conf_dir: '/path/to/nginx' } }

            it { is_expected.to contain_file('/path/to/nginx/nginx.conf').with_content(%r{include       mime\.types;}) }
            it { is_expected.to contain_file('/path/to/nginx/nginx.conf').with_content(%r{include /path/to/nginx/conf\.d/\*\.conf;}) }
            it { is_expected.to contain_file('/path/to/nginx/nginx.conf').with_content(%r{include /path/to/nginx/sites-enabled/\*;}) }
          end

          context 'when mime_types_path is /path/to/mime.types' do
            let(:params) { { mime_types_path: '/path/to/mime.types' } }

            it { is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(%r{include       /path/to/mime\.types;}) }
          end

          context 'when confd_purge true' do
            let(:params) { { confd_purge: true } }

            it do
              is_expected.to contain_file('/etc/nginx/conf.d').with(
                purge: true,
                recurse: true
              )
            end
          end

          context 'when confd_purge false' do
            let(:params) { { confd_purge: false } }

            it do
              is_expected.to contain_file('/etc/nginx/conf.d').without(
                %w[
                  ignore
                  purge
                  recurse
                ]
              )
            end
          end

          context 'when confd_only true' do
            let(:params) { { confd_only: true } }

            it do
              is_expected.to contain_file('/etc/nginx/conf.d').without(
                %w[
                  ignore
                  purge
                  recurse
                ]
              )
              is_expected.not_to contain_file('/etc/nginx/sites-available')
              is_expected.not_to contain_file('/etc/nginx/sites-enabled')
              is_expected.to contain_file('/etc/nginx/nginx.conf').without_content(%r{include /path/to/nginx/sites-enabled/\*;})
              is_expected.not_to contain_file('/etc/nginx/streams-available')
              is_expected.not_to contain_file('/etc/nginx/streams-enabled')
            end
          end

          context 'when server_purge true' do
            let(:params) { { server_purge: true } }

            it do
              is_expected.to contain_file('/etc/nginx/sites-available').with(
                purge: true,
                recurse: true
              )
            end

            it do
              is_expected.to contain_file('/etc/nginx/sites-enabled').with(
                purge: true,
                recurse: true
              )
            end
          end

          context 'when confd_purge true, server_purge true, and confd_only true' do
            let(:params) do
              {
                confd_purge: true,
                confd_only: true,
                server_purge: true
              }
            end

            it do
              is_expected.to contain_file('/etc/nginx/conf.d').with(
                purge: true,
                recurse: true
              )
            end

            it do
              is_expected.to contain_file('/etc/nginx/conf.stream.d').with(
                purge: true,
                recurse: true
              )
            end
          end

          context 'when confd_purge true, server_purge default (false), confd_only true' do
            let(:params) do
              {
                confd_purge: true,
                confd_only: true
              }
            end

            it do
              is_expected.to contain_file('/etc/nginx/conf.d').without(
                %w[
                  purge
                ]
              )
            end

            it do
              is_expected.to contain_file('/etc/nginx/conf.stream.d').without(
                %w[
                  purge
                ]
              )
            end
          end

          context 'when server_purge false' do
            let(:params) { { server_purge: false } }

            it do
              is_expected.to contain_file('/etc/nginx/sites-available').without(
                %w[
                  ignore
                  purge
                  recurse
                ]
              )
            end

            it do
              is_expected.to contain_file('/etc/nginx/sites-enabled').without(
                %w[
                  ignore
                  purge
                  recurse
                ]
              )
            end

            it do
              is_expected.to contain_file('/var/log/nginx').without(
                %w[
                  ignore
                  purge
                  recurse
                ]
              )
            end

            it do
              is_expected.to contain_file('/etc/nginx/streams-available').without(
                %w[
                  ignore
                  purge
                  recurse
                ]
              )
            end

            it do
              is_expected.to contain_file('/etc/nginx/streams-enabled').without(
                %w[
                  ignore
                  purge
                  recurse
                ]
              )
            end
          end

          context 'when daemon_user = www-data' do
            let(:params) { { daemon_user: 'www-data' } }

            it { is_expected.to contain_file('/etc/nginx/nginx.conf').with_content %r{^user www-data;} }
          end

          context 'when daemon_group = test-group' do
            let(:params) { { daemon_group: 'test-group' } }

            it { is_expected.to contain_file('/etc/nginx/nginx.conf').with_content %r{^user .* test-group;} }
          end

          context 'when log_dir is non-default' do
            let(:params) { { log_dir: '/foo/bar' } }

            it { is_expected.to contain_file('/foo/bar').with(ensure: 'directory') }

            it do
              is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                %r{access_log /foo/bar/access.log;}
              )
            end

            it do
              is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                %r{error_log /foo/bar/error.log error;}
              )
            end
          end

          context 'when log_mode is non-default' do
            let(:params) { { log_mode: '0771' } }

            it { is_expected.to contain_file('/var/log/nginx').with(mode: '0771') }
          end

          context 'when gzip is non-default (on) test gzip defaults' do
            let(:params) { { gzip: 'on' } }

            it do
              is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                %r{  gzip              on;}
              )
            end

            it do
              is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                %r{  gzip_comp_level   1;}
              )
            end

            it do
              is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                %r{  gzip_disable      msie6;}
              )
            end

            it do
              is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                %r{  gzip_min_length   20;}
              )
            end

            it do
              is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                %r{  gzip_http_version 1.1;}
              )
            end

            it do
              is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                %r{  gzip_vary         off;}
              )
            end

            it do
              is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                %r{  gzip_proxied      off;}
              )
            end
          end

          context 'when gzip is non-default (on) set gzip_types (array)' do
            let(:params) do
              {
                gzip: 'on',
                gzip_types: ['text/plain', 'text/html']
              }
            end

            it do
              is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                %r{  gzip_types        text/plain text/html;}
              )
            end
          end

          context 'when gzip is non-default (on) set gzip types (string)' do
            let(:params) do
              {
                gzip: 'on',
                gzip_types: 'text/plain'
              }
            end

            it do
              is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                %r{  gzip_types        text/plain;}
              )
            end
          end

          context 'when gzip is non-default (on) set gzip buffers' do
            let(:params) do
              {
                gzip: 'on',
                gzip_buffers: '32 4k'
              }
            end

            it do
              is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                %r{  gzip_buffers      32 4k;}
              )
            end
          end

          context 'when gzip is non-default (on) set gzip_proxied' do
            let(:params) { { gzip: 'on' } }

            context 'set gzip_proxied to a single value' do
              let(:params) { super().merge({ gzip_proxied: 'any' }) }

              it { is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(%r{  gzip_proxied      any;}) }
            end

            context 'set gzip_proxied to multiple values' do
              let(:params) { super().merge({ gzip_proxied: %w[no-cache expired] }) }

              it { is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(%r{  gzip_proxied      no-cache expired;}) }
            end
          end

          context 'when gzip_static is non-default set gzip_static' do
            let(:params) do
              {
                gzip_static: 'on'
              }
            end

            it do
              is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                %r{  gzip_static       on;}
              )
            end
          end

          context 'when stream is true' do
            let(:params) { { stream: true } }

            it do
              is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                %r{stream\s\{}
              )
            end

            context 'when stream_log_format is defined' do
              let(:params) do
                super().merge({ stream_log_format: { 'stream_format' => 'STREAM_FORMAT' } })
              end

              it do
                is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                  %r{log_format stream_format 'STREAM_FORMAT';}
                )
              end
            end

            context 'when stream_custom_format_log is default' do
              it do
                is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                  %r{access_log /var/log/nginx/stream-access.log;}
                )
              end
            end

            context 'when stream_custom_format_log is non-default' do
              let(:params) do
                super().merge({ stream_custom_format_log: 'stream_format' })
              end

              it do
                is_expected.to contain_file('/etc/nginx/nginx.conf').with_content(
                  %r{access_log /var/log/nginx/stream-access.log stream_format;}
                )
              end
            end
          end
        end
      end
    end
  end
end
