{% set system = salt['openstack_utils.system']() %}
{% set yum_repository = salt['openstack_utils.yum_repository']() %}


{% for pkg in system['packages'] %}
system_{{ pkg }}_install:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}


system_network_manager_dead:
  service.dead:
    - name: {{ system['services']['network_manager'] }}
    - enable: False
    - require:
{% for pkg in system['packages'] %}
      - pkg: system_{{ pkg }}_install
{% endfor %}


system_network_running:
  service.running:
    - name: {{ system['services']['network'] }}
    - enable: True
    - require:
      - service: system_network_manager_dead


system_firewalld_dead:
  service.dead:
    - name: {{ system['services']['firewalld'] }}
    - enable: False
    - require:
{% for pkg in system['packages'] %}
      - pkg: system_{{ pkg }}_install
{% endfor %}


system_iptables_running:
  service.running:
    - name: {{ system['services']['iptables'] }}
    - enable: True
    - require:
      - service: system_firewalld_dead

include:
  - system.RedHat.iptables
  
{% for pkg in yum_repository['packages'] %}
system_repository_{{ pkg }}_install:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}

