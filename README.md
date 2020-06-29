# security libs or utils

### certificateUtil.sh
This utils works for generate server certificates, you could use as below steps:

#### create server key and CSR
1. create server key
```bash
./certificateUtil.sh -d web.jeck.com -m generateRSAPrivateKey
```
2. create server CSR
```bash
./certificateUtil.sh -d web.jeck.com -m createCSR -C GB -S London -L London -O jeck -U pctc -N web.jeck.com
```
#### create test CA certificate and sign server CSR
1. create CA key and certificate
```bash
./certificateUtil.sh -d web.jeck.com -m generateRSAPrivateKey -g ca -C GB -S London -L London -O jeck -U pctc -N ca.jeck.com
```
2. sign server CSR
```bash
./certificateUtil.sh -d web.jeck.com -m signServerCertificate
```

#### convert PEM to JKS
```bash
./certificateUtil.sh -d web.jeck.com -m convert2JKS
```
