import boto.s3.connection
from boto.s3.connection import S3Connection
from boto.s3.key import Key
import sys 
import subprocess
import json 
import string 
import random 


def print_usage():
    MSG = """
    EXAMPLE usage: python3 rgw_s3.py 192.168.122.152:7080 zone.user
    """
    print(MSG)


def print_buckets():
    print("Existing buckets:\n")
    for bucket in conn.get_all_buckets():
        print('{}\t{}'.format(bucket.name, bucket.creation_date))


if __name__ == '__main__':
    """
    Script name: rgw_s3.py
    REQUIREMENTS: 
    - sudo zypper in -y python3-boto # should be installed with SES
    - Server needs to be ceph admin node 
    - There is at least one RGW user: radosgw-admin user list
    Purpose: 
    - Listing existing buckets 
    - Creating new bucket 
    - Puting a txt based object into newly created bucket 
    - Reading the same object 
    """
    try: 
        RGW_HOST, RGW_USER = sys.argv[1], sys.argv[2]
    except IndexError:
        print_usage()
        sys.exit("Please read usage and try again.")

    try:
        RGW_HOST_IP, TCP_PORT = RGW_HOST.split(':')[0], int(RGW_HOST.split(':')[1])
    except IndexError: 
        RGW_HOST_IP, TCP_PORT = RGW_HOST, 80

    bash_cmd = 'radosgw-admin user info --uid={} --format=json'.format(RGW_USER)
    usr_info = json.loads(subprocess.check_output(bash_cmd, shell=True))
    access_key = usr_info['keys'][0]['access_key']
    secret_key = usr_info['keys'][0]['secret_key']

    conn = S3Connection(aws_access_key_id=access_key, 
                        aws_secret_access_key=secret_key, 
                        host=RGW_HOST_IP, 
                        port=TCP_PORT, 
                        is_secure=False, 
                        calling_format=boto.s3.connection.OrdinaryCallingFormat())

    print_buckets()

    # create new bucket 
    rnd_sufix = ''.join(random.choice(string.ascii_lowercase + string.digits) for _ in range(8))
    bucket_name = 'bucket_' + rnd_sufix
    try:
        bucket = conn.create_bucket(bucket_name)
    except S3ResponseError:
        sys.exit("Error: Bucket creation failed") 
    else:
        print("\nBucket " + bucket_name + " creation DONE")

    print_buckets()

    # write object to a bucket 
    k = Key(bucket)
    k.key = 'test_content'
    rnd_data_string = ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(64))
    try:
        k.set_contents_from_string('Random chars: ' + rnd_data_string)
    except:
        sys.exit("Error: Object putting failed.")

    print('\nRead obj verification OK.') if 'Random chars:' in str(k.get_contents_as_string()) else sys.exit("Error: obj read FAILED.")
    
    conn.close()
