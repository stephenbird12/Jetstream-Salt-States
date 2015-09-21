{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{% set os_family = salt['grains.get']('os_family', '') %}

neutron:
    mysql_database.present:
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - connection_host: localhost
    - connection_charset: utf8
    - requirein:
      - mysql_user: neutronlocalhost
      - mysql_grants: neutronlocalhost
      - mysql_user: neutronewildcard
      - mysql_grans: neutronwildcard
      
neutronlocalhost:
  mysql_user.present:
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - connection_host: localhost
    - connection_charset: utf8
    - host: localhost
    - name: neutron
    - password: {{ pillar['neutron_dbpass'] }}
  mysql_grants.present:
    - connection_user: root
    - connection_pass: {{ mysql_root_password  }}
    - connection_host: localhost
    - connection_charset: utf8
    - grant: all privileges
    - database: neutron.*
    - user: neutron
    - host: "%"

neutronwildcard:
  mysql_user.present:
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - connection_host: localhost
    - connection_charset: utf8
    - host: "%"
    - name: neutron
    - password: {{ pillar['neutron_dbpass'] }}
  mysql_grants.present:
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - connection_host: localhost
    - connection_charset: utf8
    - grant: all privileges
    - database: neutron.*
    - user: neutron
    - host: localhost
    
neutron-user:
  cmd.run:
    - name: openstack user create --password {{pillar['neutron_pass']}} neutron
    - env:
      - OS_URL: http://{{ pillar['keystonehost'] }}:35357/v2.0
      - OS_TOKEN: {{ pillar['admin_token'] }}
    - unless: openstack user list | grep  -q neutron

neutron-role-project:
  cmd.run:
    - name: openstack role add --project service --user neutron admin
    - env:
      - OS_URL: http://{{ pillar['keystonehost'] }}:35357/v2.0
      - OS_TOKEN: {{ pillar['admin_token'] }}
    - unless: openstack user role list neutron --project service | grep  -q admin
    - requires:
      - cmd: admin-role
      - cmd: neutron-user
      - cmd: service-project
neutron-service:
  cmd.run:
    - name: openstack service create --type network --description "OpenStack Networking" neutron
    - env:
      - OS_URL: http://{{ pillar['keystonehost'] }}:35357/v2.0
      - OS_TOKEN: {{ pillar['admin_token'] }}
    - unless: openstack service list | grep  -q network
    - requires:
      - service: openstack-keystone
neutron-endpoint:
  cmd.run:
    - name: openstack endpoint create --publicurl http://{{ pillar['neutronpublichost'] }}:9696 --adminurl http://{{ pillar['neutronprivatehost'] }}:9696 --internalurl http://{{ pillar['neutronprivatehost'] }}:9696 --region RegionOne network
    - env:
      - OS_URL: http://{{ pillar['keystonehost'] }}:35357/v2.0
      - OS_TOKEN: {{ pillar['admin_token'] }}
    - unless: openstack endpoint list | grep  -q network
    - requires:
      - service: openstack-keystone
      
openstack-neutron:
  pkg:
    - name: {{ pillar['openstack-neutron'] }}
    - installed
    - require-in:
      - ini: /etc/neutron/neutron.conf
  service:
    - name: neutron-server
    - running
    - enable: True
    - watch:
      - ini: /etc/neutron/neutron.conf
    - require:
      - cmd: openstack-neutron
  cmd.run:
    - name: su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
    - stateful: True
    - require:
      - ini: /etc/neutron/plugins/ml2/ml2_conf.ini
      - ini: /etc/neutron/neutron.conf

openstack-neutron-ml2:
  pkg:
    - name: {{ pillar['openstack-neutron-ml2'] }}
    - installed
python-neutronclient:
  pkg.installed

{% if os_family == 'RedHat' %}
/etc/neutron/plugin.ini:
  file.symlink:
    - target: /etc/neutron/plugins/ml2/ml2_conf.ini
{% endif %}    

/etc/neutron/neutron.conf:
  ini.options_present:
    - sections:
        DEFAULT:
          rpc_backend: rabbit
          auth_strategy: keystone
          core_plugin: ml2
          service_plugins: router
          allow_overlapping_ips: True
          notify_nova_on_port_status_changes: True
          notify_nova_on_port_data_changes: True
          nova_url: http://{{ pillar['novaprivatehost'] }}:8774/v2
          verbose: True
          network_device_mtu: 8950
          advertise_mtu: True
        nova:
          auth_url: http://{{ pillar['keystonehost'] }}:35357
          auth_plugin: password
          project_domain_id: default
          user_domain_id: default
          region_name: RegionOne
          project_name: service
          username: nova
          password: {{ pillar['nova_pass'] }}
        keystone_authtoken:
          auth_uri: http://{{ pillar['keystonehost'] }}:5000
          auth_url: http://{{ pillar['keystonehost'] }}:35357
          auth_plugin: password
          project_domain_id: default
          user_domain_id: default
          project_name: service
          username: neutron
          password: {{ pillar['neutron_pass'] }}
        oslo_messaging_rabbit:
          rabbit_host: {{ pillar['rabbit_controller'] }}
          rabbit_userid: openstack
          rabbit_password: {{pillar['openstack_rabbit_pass'] }}
        database:
          connection: mysql://neutron:{{ pillar['neutron_dbpass'] }}@{{ pillar['mysqlhost'] }}/neutron

/etc/neutron/plugins/ml2/ml2_conf.ini:
  ini.options_present:
    - sections:
        ml2:
          type_drivers: flat,vlan,gre,vxlan
          tenant_network_types: vxlan,vlan
          mechanism_drivers: linuxbridge,l2population
        ml2_type_gre:
          tunnel_id_ranges: '1:1000'
        ml2_type_vxlan:
          vni_ranges: '100:1000'
          vxlan_group: '239.1.1.1'
        securitygroup:
          enable_security_group: 'True'
          enable_ipset: True
          firewall_driver: neutron.agent.linux.iptables_firewall.IptablesFirewallDriver