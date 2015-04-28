cobbler:
  pkg:
    - installed

cobbler-web:
  pkg:
    - installed

debmirror:
  pkg:
    - installed
    
cobblerrepo:
  pkgrepo.managed:
    - humanname: Cobbler 2.6 repo
    - name: deb http://download.opensuse.org/repositories/home:/libertas-ict:/cobbler26/xUbuntu_14.04/ ./
    - dist: trusty
    - file: /etc/apt/sources.list.d/cobbler.list
    - key_url: http://download.opensuse.org/repositories/home:/libertas-ict:/cobbler26/xUbuntu_14.04/Release.key
