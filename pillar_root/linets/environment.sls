environment_name: "controller1"

openstack_series: "kilo"

db_engine: "mysql"

message_queue_engine: "rabbitmq"

reset: "hard"
debug_mode: True

system_upgrade: True

hosts:
  "controller1": "172.16.1.1"
  "node1": "172.16.1.2"

controller: "controller1"
network: "controller1"
storage:
  - "node2"
compute:
  - "node1"

cinder:
  volumes_group_name: "cinder-volumes"
  volumes_path: "/var/lib/cinder/cinder-volumes"
  volumes_group_size: "10"
  loopback_device: "/dev/loop0"

nova:
  cpu_allocation_ratio: "16"
  ram_allocation_ratio: "1.5"

glance:
  images:
    cirros:
      user: "admin"
      tenant: "admin"
      parameters:
        min_disk: 1
        min_ram: 0
        copy_from: "http://download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img"
        disk_format: qcow2
        container_format: bare
        is_public: True
        protected: False


ceph_osd:
  - "node1"
  - "controller1"
  - "node2"

ceph_mon:
  - "controller1"
  - "node1"
  - "node2"
controller1:
  devs:
    sdb:
      journal: nvme0n1
    sdc:
      journal: nvme0n1
    sdd:
      journal: nvme0n1
    sde:
      journal: nvme0n1
    sdf:
      journal: nvme0n1
    sdg:
      journal: nvme0n1
    sdh:
      journal: nvme0n1
    sdi:
      journal: nvme0n1


node1:
  devs:
    sdb:
      journal: nvme0n1
    sdc:
      journal: nvme0n1
    sdd:
      journal: nvme0n1
    sde:
      journal: nvme0n1
    sdf:
      journal: nvme0n1
    sdg:
      journal: nvme0n1
    sdh:
      journal: nvme0n1

node2:
  devs:
    sdb:
      journal: nvme0n1
    sdc:
      journal: nvme0n1
    sdd:
      journal: nvme0n1
    sde:
      journal: nvme0n1
    sdf:
      journal: nvme0n1
    sdg:
      journal: nvme0n1
    sdh:
      journal: nvme0n1

secret_uuid: "a04a5658-64b7-4ce1-884e-b36ed52f7653"

