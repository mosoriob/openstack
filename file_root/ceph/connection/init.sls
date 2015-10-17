{% set nova = salt['openstack_utils.nova']() %}
{% set neutron = salt['openstack_utils.neutron']() %}
{% set service_users = salt['openstack_utils.openstack_users']('service') %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}

{% for name in ['glance', 'cinder', 'cinder-backup'] -%}
keyring_{{name}}:
  cmd.run:
    - name: "ceph auth get-or-create client.{{name}} | tee /etc/ceph/ceph.client.{{name}}.keyring"
{% endfor -%}


/etc/ceph/ceph.client.cinder.keyring:
  file.managed:
    - user: cinder
    - group: cinder

/etc/ceph/ceph.client.glance.keyring:
  file.managed:
    - user: glance
    - group: glance

/etc/ceph/ceph.client.cinder-backup.keyring:
  file.managed:
    - user: cinder
    - group: cinder

virsh_config:
  file.managed:
    - name: '/root/linets_ceph/secret.xml'
    - source: salt://connect/files/secret.xml.tpl
    - template: jinja

virsh_secret_define:
  cmd.run:
    - name: "virsh secret-define --file /root/linets_ceph/secret.xml"

virsh_secret_set_value:
  cmd.run:
    - name: "virsh secret-set-value --secret {{ openstack_parameters['secret_uuid'] }} --base64 $(cat /etc/ceph/ceph.client.cinder.keyring) && rm secret.xml" 
