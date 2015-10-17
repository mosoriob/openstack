{% set oscodename = salt['config.get']('oscodename') -%}
{% set version = salt['pillar.get']('ceph_series') -%}
{% set mons = salt['pillar.get']('ceph_mon')|join(" ") -%}
{% set osds = salt['pillar.get']('ceph_osd')|join(" ") -%}
{% set osds_list = salt['pillar.get']('ceph_osd') -%}

/root/linets_ceph:
  file.directory:
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644

ceph-deploy:
  pkg:
    - installed

new_cluster:
  cmd.run:
    - name: ceph-deploy  new {{ mons }}
    - cwd: /root/linets_ceph
    - require: 
      - file: /root/linets_ceph 

/root/linets_ceph/ceph.conf:
  ini.options_present:
    - sections:
        global:
          'osd pool default min size': 2
          'osd pool default pg num': 256
          'osd pool default pgp num': 256
          'osd pool default size': 3
        client:
          'rbd cache': true
          'rbd cache writethrough until flush': true
          'rbd concurrent management ops': 20
        osd:
          'osd max backfills': 1
          'osd recovery op priority': 1
          'osd client op priority': 63
          'osd recovery max active': 1
          'osd journal size': 5000
          'scrub load threshold': "0.5"

install_mons:
  cmd.run:
    - name: ceph-deploy install --release hammer --no-adjust-repos {{ mons }}
    - cwd: /root/linets_ceph

install_osds:
  cmd.run:
    - name: ceph-deploy install --release hammer --no-adjust-repos {{ osds }}
    - cwd: /root/linets_ceph

create-initial:
  cmd.run:
    - name: ceph-deploy  mon create-initial 
    - cwd: /root/linets_ceph

admin:
  cmd.run:
    - name: ceph-deploy  admin {{ mons }}
    - cwd: /root/linets_ceph

/etc/ceph/ceph.client.admin.keyring:
  file.managed:
    - user: root
    - group: root
    - mode: 644


{% for host in osds_list -%}
{% for dev in salt['pillar.get'](host + ':devs') -%}
{% if dev -%}
{% set journal = salt['pillar.get'](host + ':devs:' + dev + ':journal') -%}

disk_{{host}}_prepare {{ dev }}:
  cmd.run:
    - name: ceph-deploy osd prepare --zap-disk {{ host }}:{{ dev }}:/dev/{{ journal }}
    - unless: parted --script /dev/{{ dev }} print | grep 'ceph data'
    - cwd: /root/linets_ceph

{% endif -%}
{% endfor -%}
{% endfor -%}

