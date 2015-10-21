{% set nova = salt['openstack_utils.nova']() %}
{% set neutron = salt['openstack_utils.neutron']() %}
{% set service_users = salt['openstack_utils.openstack_users']('service') %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


cephx_cinder:
  cmd.run: 
    - name: "ceph auth get-or-create client.cinder mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=vms, allow rx pool=images'"

/root/linets_ceph:
  file.directory:
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644


{% for name in ['cinder'] -%}
keyring_{{name}}:
  cmd.run:
    - name: "ceph auth get-or-create client.{{name}} | tee /etc/ceph/ceph.client.cinder.keyring"
{% endfor -%}


{% for name in ['cinder'] -%}
keyring_temp_{{name}}:
  cmd.run:
    - name: "ceph auth get-key client.{{name}} | tee /root/linets_ceph/client.cinder.key"
{% endfor -%}


virsh_config:
  file.managed:
    - name: '/root/linets_ceph/secret.xml'
    - source: salt://ceph/connection/compute/files/secret.xml.tpl
    - template: jinja

virsh_secret_define:
  cmd.run:
    - name: "virsh secret-define --file /root/linets_ceph/secret.xml"

virsh_secret_set_value:
  cmd.run:
    - name: "virsh secret-set-value --secret {{ openstack_parameters['secret_uuid'] }} --base64 $(cat /root/linets_ceph/client.cinder.key)" 
