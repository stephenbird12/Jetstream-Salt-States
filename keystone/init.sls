{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{% set os_family = salt['grains.get']('os_family', '') %}


keystone:
    mysql_database.present:
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - connection_host: localhost
    - connection_charset: utf8
    - requirein:
      - mysql_user: keystonelocalhost
      - mysql_grants: keystonelocalhost
      - mysql_user: keystonewildcard
      - mysql_grans: keystonewildcard

keystonelocalhost:
  mysql_user.present:
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - connection_host: localhost
    - connection_charset: utf8
    - host: localhost
    - name: keystone
    - password: {{ pillar['keystone_dbpass'] }}
  mysql_grants.present:
    - connection_user: root
    - connection_pass: {{ mysql_root_password  }}
    - connection_host: localhost
    - connection_charset: utf8
    - grant: all privileges
    - database: keystone.*
    - user: keystone
    - host: "%"

keystonewildcard:
  mysql_user.present:
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - connection_host: localhost
    - connection_charset: utf8
    - host: "%"
    - name: keystone
    - password: {{ pillar['keystone_dbpass'] }}
  mysql_grants.present:
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - connection_host: localhost
    - connection_charset: utf8
    - grant: all privileges
    - database: keystone.*
    - user: keystone
    - host: localhost

keystone-manage pki_setup --keystone-user keystone --keystone-group keystone:
  cmd.run:
    - creates: /etc/keystone/ssl

/etc/keystone/ssl:
  file.directory:
    - user: keystone
    - group: keystone
    - mode: 660
    - recurse:
      - user
      - mode
      - group
/var/log/keystone:
  file.directory:
    - user: keystone
    - group: keystone
    - recurse:
      - user
      - group
include:
  - keystone.keystoneconf
openstack-keystone:
  pkg:
{% if os_family == 'Debian' %}
    - name: keystone
{% endif %}  
    - installed
    - require_in:
      - ini: /etc/keystone/keystone.conf
      - file: /var/log/keystone
      - file: /etc/keystone/ssl
      - cmd: openstack-keystone
  service:
{% if os_family == 'Debian' %}
    - name: keystone
{% endif %}    
    - running
    - enable: True
    - watch:
      - ini: /etc/keystone/keystone.conf
      - cmd: openstack-keystone 
  cmd.run:
    - name: su -s /bin/sh -c "keystone-manage db_sync" keystone
    - stateful: True
keystone-identity-service:
  cmd.run:
    - name: openstack service create --type identity   --description "OpenStack Identity" keystone
    - env:
      - OS_URL: http://{{ pillar['keystonehost'] }}:35357/v2.0
      - OS_TOKEN: {{ pillar['admin_token'] }}
    - unless: openstack service list | grep  -q keystone
    - requires:
      - service: openstack-keystone
      - pkg: python-openstackclient
keystone-endpoint:
  cmd.run:
    - name: openstack endpoint create --publicurl http://{{ pillar['keystonepublichost'] }}:5000/v2.0 --internalurl http://{{ pillar['keystonehost'] }}:5000/v2.0 --adminurl http://{{ pillar['keystonehost'] }}:35357/v2.0 --region RegionOne identity
    - env:
      - OS_URL: http://{{ pillar['keystonehost'] }}:35357/v2.0
      - OS_TOKEN: {{ pillar['admin_token'] }}
    - unless: openstack endpoint list | grep  -q keystone
    - requires:
      - service: openstack-keystone
      - pkg: python-openstackclient
admin-project:
  cmd.run:
    - name: openstack project create --description "Admin Project" admin
    - env:
      - OS_URL: http://{{ pillar['keystonehost'] }}:35357/v2.0
      - OS_TOKEN: {{ pillar['admin_token'] }}
    - unless: openstack project list | grep  -q admin
    - requires:
      - service: openstack-keystone
      - pkg: python-openstackclient
admin-user:
  cmd.run:
    - name: openstack user create --password {{pillar['admin_pass']}} admin
    - env:
      - OS_URL: http://{{ pillar['keystonehost'] }}:35357/v2.0
      - OS_TOKEN: {{ pillar['admin_token'] }}
    - unless: openstack user list | grep  -q admin
    - requires:
      - cmd: openstack-keystone
      - pkg: python-openstackclient
admin-role:
  cmd.run:
    - name: openstack role create admin
    - env:
      - OS_URL: http://{{ pillar['keystonehost'] }}:35357/v2.0
      - OS_TOKEN: {{ pillar['admin_token'] }}
    - unless: openstack role list | grep  -q admin
    - requires:
      - service: openstack-keystone
      - pkg: python-openstackclient
admin-role-project:
  cmd.run:
    - name: openstack role add --project admin --user admin admin
    - env:
      - OS_URL: http://{{ pillar['keystonehost'] }}:35357/v2.0
      - OS_TOKEN: {{ pillar['admin_token'] }}
    - unless: openstack user role list admin --project admin | grep  -q admin
    - requires:
      - cmd: admin-role
      - cmd: admin-user
      - cmd: admin-project
      - pkg: python-openstackclient
service-project:
  cmd.run:
    - name: openstack project create --description "Service Project" service
    - env:
      - OS_URL: http://{{ pillar['keystonehost'] }}:35357/v2.0
      - OS_TOKEN: {{ pillar['admin_token'] }}
    - unless: openstack project list | grep  -q service
    - requires:
      - service: openstack-keystone
      - pkg: python-openstackclient
python-openstackclient: 
  pkg.installed
memcached: 
  pkg:
    - installed
  service:
    - enable: True
    - running
python-memcached:
  pkg:
{% if os_family == 'Debian' %}
    - name: python-memcache
{% endif %}      
    - installed
