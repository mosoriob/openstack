{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}
<secret ephemeral='no' private='no'>
  <uuid>{{openstack_parameters['secret_uuid']}}</uuid>
  <usage type='ceph'>
    <name>client.cinder secret</name>
  </usage>
</secret>

