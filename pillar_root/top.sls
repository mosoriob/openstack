openstack: 
  "controller1,node1,node2":
    - match: list
    - {{ grains['os'] }}
    - linets.credentials
    - linets.environment
    - linets.networking
