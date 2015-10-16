openstack: 
  "controller1":
    - match: list
    - {{ grains['os'] }}
    - linets.credentials
    - linets.environment
    - linets.networking
