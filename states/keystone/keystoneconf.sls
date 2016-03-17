/etc/keystone/keystone.conf:
  ini.options_present:
    - sections:
        DEFAULT:
           debug: 'True'
           admin_token: {{ pillar['admin_token'] }}
           log_dir: /var/log/keystone
           secure_proxy_ssl_header: "HTTP_X_FORWARDED_PROTO"
           rpc_backend: rabbit
           notification_driver: messagingv2
        database:
           connection: mysql://keystone:{{ pillar['keystone_dbpass'] }}@{{ pillar['mysqlhost'] }}/keystone
        revoke:
           driver: keystone.contrib.revoke.backends.sql.Revoke
        token:
           provider: keystone.token.providers.uuid.Provider
           driver: keystone.token.persistence.backends.memcache.Token
        memcache:
           servers: 172.16.129.48:11211,172.16.129.112:11211,172.16.129.176:11211   
        identity:
           domain_specific_drivers_enabled: true
        cache:
           backend: keystone.cache.memcache_pool
           memcache_servers: 172.16.129.48:11211,172.16.129.112:11211,172.16.129.176:11211
        oslo_messaging_rabbit:
          rabbit_ha_queues: True
          rabbit_hosts: {{ pillar['rabbit_hosts'] }}
          rabbit_userid: openstack
          rabbit_password: {{ pillar['openstack_rabbit_pass'] }}
