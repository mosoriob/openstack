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

new_cluster:
  cmd.run:
    - name: ceph-deploy --overwrite-conf new {{ mons }}
    - cwd: /root/linets_ceph
    - require: 
      - file: /root/linets_ceph 

/root/linets_ceph/ceph.conf:
  ini.options_present:
    - sections:
        client:
          'rbd cache': true
          'rbd cache writethrough until flush': true
          'rbd concurrent management ops': 20
        osd:
          crush_chooseleaf_type: 1
          crush_update_on_start: "true"
          filestore_merge_threshold: 40
          filestore_split_multiple: 8
          filestore_op_threads: 12
          filestore_max_sync_interval: 5
          filestore_min_sync_interval: "0.01"
          filestore_queue_max_ops: 500
          filestore_queue_max_bytes: 104857600
          filestore_queue_committing_max_ops: 500
          filestore_queue_committing_max_bytes: 104857600
          journal_size: 10240
          scrub_load_threshold: "0.5"
          map_cache_size: 512
          max_backfills: 2
          pool_default_min_size: 1
          pool_default_pg_num: 128
          pool_default_pgp_num: 128
          pool_default_size: 2


install_mons:
  cmd.run:
    - name: ceph-deploy install {{ mons }}
    - cwd: /root/linets_ceph

install_osds:
  cmd.run:
    - name: ceph-deploy install {{ osds }}
    - cwd: /root/linets_ceph

create-initial:
  cmd.run:
    - name: ceph-deploy --overwrite-conf mon create-initial 
    - cwd: /root/linets_ceph

admin:
  cmd.run:
    - name: ceph-deploy --overwrite-conf admin {{ mons }}
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

disk_{{host}}_activate {{ dev }}1:
  cmd.run:
    - name: ceph-deploy osd activate {{ host }}:/dev/{{ dev }}1
    - unless: ceph-disk list | egrep "/dev/{{ dev }}1.*active"
    - timeout: 10
    - cwd: /root/linets_ceph

{% endif -%}
{% endfor -%}
{% endfor -%}

