# ceph_suse_bld_vld

Deploy Ceph on local VMs and run number of test scripts. 

## Preparation

Adjust cfg/hostname_arch.cfg configuration file.

Forkflow: 

1. Preparing VMs (deleting old, creating new fresh installations)
   - local host by using libvirt and cloning local VM image
   - TBD
2. Deploying Ceph/SES
   - By using salt-stack based deepsea
3. Performin test scripts 
4. Collecting logs (rsyslog)



