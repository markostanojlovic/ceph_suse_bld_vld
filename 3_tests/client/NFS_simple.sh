set -ex 

umount -f /mnt || echo 'not mounted'
mount.nfs4 ${1}:/cephfs /mnt
FILE_NAME=/mnt/nfs-ganesha.file.txt_$(date +%H_%M_%S)
base64 /dev/urandom | head --bytes=1MB > $FILE_NAME
ls -la $FILE_NAME
tail $FILE_NAME
umount -f /mnt

echo "Result: OK"

set +ex 
