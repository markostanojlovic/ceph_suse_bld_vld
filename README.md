# ceph_suse_bld_vld

Deploy Ceph on local VMs and run number of test scripts. 

## Preparation

- Adjust cfg/hostname_arch.cfg configuration file
- Add iso http link to cfg/repo/ directory 
- Choose tests in cfg/suites/all_tests_aarch64 

Forkflow: 

1. Preparing VMs (deleting old, creating new fresh installations)
   - local host by using libvirt and cloning local VM image
   - TBD
2. Deploying Ceph/SES
   - By using salt-stack based deepsea
3. Performin test scripts 
4. Collecting logs (rsyslog)

## How to run

`./run.sh cfg/maiax86_64.cfg`

### Rerun the single test 

`./3_tests/01_basic_TCs/TC010_NFS_ganesha_basic.sh cfg/maiax86_64.cfg`
