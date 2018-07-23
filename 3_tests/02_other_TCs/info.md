# Miscellaneous SES Test Cases

In this document, list of various test cases used for performing QA of SES product is presented. Some of them are created as input from customer use cases or issues encountered by support. 

| TCID | TC Name |
| --- | --- |
| [001](#TCID001) | Customized deployment of OSDs: salt-run proposal.populate ratio=4 wal-size=1g db-size=2g encryption=dmcrypt name=qatest `bugs: #1080324` |
| [002](#TCID002) | Test erasure coded CephFS data pool |
| [003](#TCID003) | Pool Compression, algorithm zstd mode passive |
| [004](#TCID004) | Global OSD Compression, algorithm snappy mode passive |
| [005](#TCID005) | Test migration from FileStore to BlueStore `bugs: #1083130 #1083128 #1064354 #1073714`  |
| [007](#TCID007) | Customized CRUSH map to simulated 2 DCs with multiple racks |
| [008](#TCID008) | Simulation of RACK failure |
| [009](#TCID009) | Simulation of DC failure |
| [010](#TCID010) | Simulation of 1,2 and max number of MON node failures |
| [011](#TCID011) | Creating 2 zones in RGW config |
| [012](#TCID012) | Testing RGW+Swift reads and writes |
| [013](#TCID013) | Persistent RBD mapping on clients (included in ses-qa-validation scripts)|
| [014](#TCID014) | Crush Map adjusting |
| [015](#TCID015) | Migrate(convert) replicated pool to EC pool by using Cache Tier |
| [016](#TCID016) | Migrate(convert) EC pool to replicated pool by using Cache Tier |

