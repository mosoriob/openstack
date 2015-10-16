{% set neutron = salt['openstack_utils.neutron']() %}
{% set service_users = salt['openstack_utils.openstack_users']('service') %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


neutron_network_ipv4_forwarding_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['sysctl'] }}"
    - sections: 
        DEFAULT_IMPLICIT: 
          net.ipv4.conf.all.rp_filter: 0
          net.ipv4.ip_forward: 1
          net.ipv4.conf.default.rp_filter: 0


neutron_network_ipv4_forwarding_enable:
  cmd.run:
    - name: "sysctl -p"
    - require:
      - ini: neutron_network_ipv4_forwarding_conf


neutron_network_conf_keystone_authtoken:
  ini.sections_absent:
    - name: "{{ neutron['conf']['neutron'] }}"
    - sections:
      - keystone_authtoken
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['neutron'] }}"
    - sections: 
        DEFAULT: 
          auth_strategy: keystone
          router_distributed:True
          dvr_base_mac: fa:16:3f:00:00:00
          core_plugin: ml2
          service_plugins: router
          allow_overlapping_ips: True
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
        keystone_authtoken: 
          auth_uri: "http://{{ openstack_parameters['controller_ip'] }}:5000"
          auth_url: "http://{{ openstack_parameters['controller_ip'] }}:35357"
          auth_plugin: "password"
          project_domain_id: "default"
          user_domain_id: "default"
          project_name: "service"
          username: "neutron"
          password: "{{ service_users['neutron']['password'] }}"
    - require: 
      - ini: neutron_network_conf_keystone_authtoken


neutron_network_ml2_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['ml2'] }}"
    - sections:
        ml2:
          type_drivers: "flat,vlan,gre,vxlan"
          tenant_network_types: "vxlan"
          mechanism_drivers: "openvswitch,l2population"
        ml2_type_flat:
          flat_networks: "*"
        ml2_type_vlan:
        ml2_type_gre:
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
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_ml2_symlink:
  file.symlink:
    - name: {{ neutron['conf']['ml2_symlink'] }}
    - target: {{ neutron['conf']['ml2'] }}
    - require:
      - ini: neutron_network_ml2_conf


neutron_network_l3_agent_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['l3_agent'] }}"
    - sections: 
        DEFAULT: 
          debug: "False"
          interface_driver: "neutron.agent.linux.interface.OVSInterfaceDriver"
          use_namespaces: "True"
          handle_internal_only_routers: "True"
          external_network_bridge:
          metadata_port: "9697"
          send_arp_for_ha: "3"
          periodic_interval: "40"
          periodic_fuzzy_delay: "5"
          enable_metadata_proxy: "True"
          router_delete_namespaces: "True"
          agent_mode: "dvr_snat"
          allow_automatic_l3agent_failover: "False"
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_dhcp_agent_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['dhcp_agent'] }}"
    - sections: 
        DEFAULT: 
          interface_driver: neutron.agent.linux.interface.OVSInterfaceDriver
          dhcp_driver: neutron.agent.linux.dhcp.Dnsmasq
          dhcp_delete_namespaces: True
          dnsmasq_config_file: {{ neutron['conf']['dnsmasq_config_file'] }}
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_dnsmasq_conf:
  ini.options_present:
    - name: {{ neutron['conf']['dnsmasq_config_file'] }}
    - sections:
        DEFAULT_IMPLICIT:
          dhcp-option-force: 26,1454
    - require:
      - ini: neutron_network_dhcp_agent_conf


neutron_network_metadata_agent_conf:
  ini.options_present:
    - name: "{{ neutron['conf']['metadata_agent'] }}"
    - sections: 
        DEFAULT: 
          auth_uri: "http://{{ openstack_parameters['controller_ip'] }}:5000"
          auth_url: "http://{{ openstack_parameters['controller_ip'] }}:35357"
          auth_region: RegionOne
          auth_insecure: False
          auth_plugin: password
          admin_tenant_name: services
          admin_user: neutron
          admin_password:  "{{ service_users['neutron']['password'] }}"
          nova_metadata_ip: {{ openstack_parameters['controller_ip'] }}
          metadata_proxy_shared_secret: {{ neutron['metadata_secret'] }}
          nova_metadata_protocol: http
          metadata_workers: 32
          metadata_backlog:  4096
          cache_url: memory://?default_ttl=5
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_ovs_fix_cp:
  file.copy:
    - name: {{ neutron['conf']['ovs_systemd'] }}.orig
    - source: {{ neutron['conf']['ovs_systemd'] }}
    - unless: ls {{ neutron['conf']['ovs_systemd'] }}.orig
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_ovs_fix_sed:
  cmd.run:
    - name: sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' {{ neutron['conf']['ovs_systemd'] }}
    - require:
      - file: neutron_network_ovs_fix_cp


neutron_network_openvswitch_running:
  service.running:
    - enable: True
    - name: "{{ neutron['services']['network']['ovs'] }}"
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_openvswitch_agent_running:
  service.running:
    - enable: True
    - name: "{{ neutron['services']['network']['ovs_agent'] }}"
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_ovs_cleanup_running:
  service.enabled:
    - name: "{{ neutron['services']['network']['ovs_agent'] }}"
    - require:
{% for pkg in neutron['packages']['network'] %}
      - pkg: neutron_network_{{ pkg }}_install
{% endfor %}


neutron_network_l3_agent_running:
  service.running:
    - enable: True
    - name: "{{ neutron['services']['network']['l3_agent'] }}"
    - watch: 
      - ini: neutron_network_l3_agent_conf


neutron_network_dhcp_agent_running:
  service.running:
    - enable: True
    - name: "{{ neutron['services']['network']['dhcp_agent'] }}"
    - watch: 
      - ini: neutron_network_dhcp_agent_conf


neutron_network_metadata_agent_running:
  service.running:
    - enable: True
    - name: "{{ neutron['services']['network']['metadata_agent'] }}"
    - watch: 
      - ini: neutron_network_metadata_agent_conf


neutron_network_wait:
  cmd.run:
    - name: "sleep 5"
    - require:
      - service: neutron_network_openvswitch_running
      - service: neutron_network_openvswitch_agent_running
      - service: neutron_network_l3_agent_running
      - service: neutron_network_dhcp_agent_running
      - service: neutron_network_metadata_agent_running
