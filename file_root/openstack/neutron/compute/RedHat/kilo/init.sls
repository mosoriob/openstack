{% set neutron = salt['openstack_utils.neutron']() %}
{% set service_users = salt['openstack_utils.openstack_users']('service') %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


neutron_compute_sysctl_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['sysctl'] }}"
    - sections: 
        DEFAULT_IMPLICIT: 
          net.ipv4.ip_forward: 1
          net.ipv4.conf.default.rp_filter: 0
          net.ipv4.conf.all.rp_filter: 0
          net.bridge.bridge-nf-call-iptables: 1
          net.bridge.bridge-nf-call-ip6tables: 1


neutron_compute_sysctl_enable:
  cmd.run:
    - name: "sysctl -p"
    - require:
      - ini: neutron_compute_sysctl_conf

neutron_compute_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['neutron'] }}"
    - sections: 
        DEFAULT: 
          auth_strategy: keystone
          core_plugin: ml2
          service_plugins: router
          allow_overlapping_ips: True
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
        keystone_authtoken: 
          auth_uri: 'http://127.0.0.1:35357/v2.0/'
          identity_uri: 'http://127.0.0.1:5000'
          admin_tenant_name: '%SERVICE_TENANT_NAME%'
          admin_user: '%SERVICE_USER%'
          admin_password: '%SERVICE_PASSWORD%'


neutron_compute_l3_agent_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['l3_agent'] }}"
    - sections: 
        DEFAULT: 
          verbose: "True"
          interface_driver: "neutron.agent.linux.interface.OVSInterfaceDriver"
          use_namespaces: "True"
          external_network_bridge:
          agent_mode: "dvr"

neutron_compute_ml2_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['ml2'] }}"
    - sections:
        ml2:
          type_drivers: "flat,vlan,gre,vxlan"
          tenant_network_types: "vxlan"
          mechanism_drivers: "openvswitch,l2population"
        ml2_type_flat:
          flat_networks: "*"
        ml2_type_vxlan:
          vni_ranges: "1001:2000"
          vxlan_group: "239.1.1.2"
        securitygroup:
          enable_security_group: True
          enable_ipset: True
          firewall_driver: "neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver"
        ovs:
          local_ip: {{ salt['openstack_utils.minion_ip'](grains['id']) }}
          bridge_mappings: "physnet1:br-ex"
        agent:
          l2_population: "True"
          tunnel_types: "gre,vxlan"
          enable_distributed_routing: "True"
          arp_responder: "True"


neutron_compute_metadata_agent_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['metadata_agent'] }}"
    - sections: 
        DEFAULT: 
          debug: True
          nova_metadata_ip: {{ openstack_parameters['controller_ip'] }}
          metadata_proxy_shared_secret: {{ neutron['metadata_secret'] }}

neutron_compute_ml2_symlink:
  file.symlink:
    - name: {{ neutron['conf']['ml2_symlink'] }}
    - target: {{ neutron['conf']['ml2'] }}
    - require:
      - ini: neutron_compute_ml2_conf


neutron_compute_ovs_fix_cp:
  file.copy:
    - name: {{ neutron['conf']['ovs_systemd'] }}.orig
    - source: {{ neutron['conf']['ovs_systemd'] }}
    - unless: ls {{ neutron['conf']['ovs_systemd'] }}.orig
    - require:
{% for pkg in neutron['packages']['compute']['kvm'] %}
      - pkg: neutron_compute_{{ pkg }}_install
{% endfor %}


neutron_compute_ovs_fix_sed:
  cmd.run:
    - name: sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' {{ neutron['conf']['ovs_systemd'] }}
    - require:
      - file: neutron_compute_ovs_fix_cp


{% for service in neutron['services']['compute']['kvm'] %}
neutron_compute_{{ service }}_running:
  service.running:
    - enable: True
    - name: "{{ neutron['services']['compute']['kvm'][service] }}"
    - watch:
      - ini: neutron_compute_conf
      - ini: neutron_compute_ml2_conf
{% endfor %}


neutron_compute_wait:
  cmd.run:
    - name: "sleep 5"
    - require:
{% for service in neutron['services']['compute']['kvm'] %}
      - service: neutron_compute_{{ service }}_running
{% endfor %}
