#!/bin/bash

SCRIPTS_PATH=$(cd "${0%/*}"; pwd)

TMP_DIR="/tmp/poly/certs"
mkdir -p $TMP_DIR


METHOD="generateRSAPrivateKey"
DOMAIN=""
SUB_COUNTRY=""
SUB_STATE=""
SUB_LOCATION=""
SUB_ORGANIZATION=""
SUB_ORGANIZATION_UNIT=""
SUB_COMMON_NAME=""
GENERATE_KEY_TYPE="server"
INSTALL_DIR="/opt/poly/vces-configs/certs"

usage() {  
    local prog="`basename $1`"  
    echo "Usage: [-m method]"  
    echo "       $prog -h for help."  
    echo "  -m   which method do you want to invoke. values are generateRSAPrivateKey,createCSR,signServerCertificate,compineCertificates,convert2JKS,installCertificates(default generateRSAPrivateKey)"
    echo "  -d   domain name for this server."
    echo "  -g   generate key type(server/ca), default is server."
    echo "  -i   install certificates dir, default is /opt/poly/vces-configs/certs."
    echo "  -C   subject country."
    echo "  -S   subject state."
    echo "  -L   subject location."
    echo "  -O   subject organization."
    echo "  -U   subject organizationUnit."
    echo "  -N   subject commonName."
    exit 1   
}  
##################################
# prase param
##################################
while getopts "m:d:g:i:C:S:L:O:U:N:h" arg  
do  
        case $arg in  
        m)                  METHOD=$OPTARG ;;  
        d)                  DOMAIN=$OPTARG ;;  
        g)                  GENERATE_KEY_TYPE=$OPTARG ;; 
        i)                  INSTALL_DIR=$OPTARG ;;
        C)                  SUB_COUNTRY=$OPTARG ;;   
        S)                  SUB_STATE=$OPTARG ;;   
        L)                  SUB_LOCATION=$OPTARG ;;   
        O)                  SUB_ORGANIZATION=$OPTARG ;;  
        U)                  SUB_ORGANIZATION_UNIT=$OPTARG ;;  
        N)                  SUB_COMMON_NAME=$OPTARG ;;   
        h)                  usage $0 ;;  
        *)                  usage $0 ;;  
        esac  
done

echo "************************"
echo "METHOD=$METHOD"
echo "DOMAIN=$DOMAIN"
echo "GENERATE_KEY_TYPE=$GENERATE_KEY_TYPE"
echo "INSTALL_DIR=$INSTALL_DIR"
echo "SUB_COUNTRY=$SUB_COUNTRY"
echo "SUB_STATE=$SUB_STATE"
echo "SUB_LOCATION=$SUB_LOCATION"
echo "SUB_ORGANIZATION=$SUB_ORGANIZATION"
echo "SUB_ORGANIZATION_UNIT=$SUB_ORGANIZATION_UNIT"
echo "SUB_COMMON_NAME=$SUB_COMMON_NAME"
echo "************************"

KeyStroe="$TMP_DIR/server/$DOMAIN.truststore.ks"
ServerAllCertificate="$TMP_DIR/server/$DOMAIN.all.pem"
ServerCertificate="$TMP_DIR/server/$DOMAIN.certificate.pem"
ServerKey="$TMP_DIR/server/$DOMAIN.key.pem"
ServerCSR="$TMP_DIR/server/$DOMAIN.csr"
ServerPKCS12="$TMP_DIR/server/server.p12"
CAKey="$TMP_DIR/ca/$DOMAIN.key.pem"
CACertificate="$TMP_DIR/ca/$DOMAIN.certificate.pem"


generateRSAPrivateKey(){
    KeyType=$1    
    echo "Generating RSA private key for $KeyType."
    mkdir -p $TMP_DIR/$KeyType
    if [ "$KeyType" == "server" ]; then    
        openssl genrsa -out $TMP_DIR/$KeyType/$DOMAIN.key.pem 2048    
    else
        Check="ok"
        if [ -z "$SUB_COUNTRY" ]; then Check=""; fi
        if [ -z "$SUB_STATE" ]; then Check=""; fi
        if [ -z "$SUB_LOCATION" ]; then Check=""; fi
        if [ -z "$SUB_ORGANIZATION" ]; then Check=""; fi
        if [ -z "$SUB_ORGANIZATION_UNIT" ]; then Check=""; fi
        if [ -z "$SUB_COMMON_NAME" ]; then Check=""; fi
        if [ "$Check" == "ok" ]; then
            Subject="/C=$SUB_COUNTRY/ST=$SUB_STATE/L=$SUB_LOCATION/O=$SUB_ORGANIZATION/OU=$SUB_ORGANIZATION_UNIT/CN=$SUB_COMMON_NAME"        
            openssl req -newkey rsa:2048 -nodes -keyout $TMP_DIR/$KeyType/$DOMAIN.key.pem -x509 -days 365 -out $TMP_DIR/$KeyType/$DOMAIN.certificate.pem -subj $Subject
        else
            echo "Subject error."
            exit -2
        fi
    fi
}

createCSR(){ 
    echo "Creating CSR."
    Check="ok"
    if [ -z "$SUB_COUNTRY" ]; then Check=""; fi
    if [ -z "$SUB_STATE" ]; then Check=""; fi
    if [ -z "$SUB_LOCATION" ]; then Check=""; fi
    if [ -z "$SUB_ORGANIZATION" ]; then Check=""; fi
    if [ -z "$SUB_ORGANIZATION_UNIT" ]; then Check=""; fi
    if [ -z "$SUB_COMMON_NAME" ]; then Check=""; fi
    if [ "$Check" == "ok" ]; then
        Subject="/C=$SUB_COUNTRY/ST=$SUB_STATE/L=$SUB_LOCATION/O=$SUB_ORGANIZATION/OU=$SUB_ORGANIZATION_UNIT/CN=$SUB_COMMON_NAME"
        if [ -f $ServerKey ]; then        
            openssl req -new -key $ServerKey -out $ServerCSR -subj $Subject
        else
            echo "Key file does not exist, please generate key first."
            exit -1
        fi
    else
        echo "Subject error."
        exit -2
    fi
    
    
}

signServerCertificate(){
    echo "Sign server certificate!"
    Check="ok"
    if [ ! -f $ServerCSR ]; then echo "$ServerCSR does not exist!" && Check=""; fi
    if [ ! -f $CAKey ]; then echo "$CAKey does not exist!" && Check=""; fi 
    if [ ! -f $CACertificate ]; then echo "$CACertificate does not exist!" && Check=""; fi 
    if [ "$Check" == "ok" ]; then  
        tee $TMP_DIR/server/v3.ext <<EOF
    authorityKeyIdentifier=keyid,issuer
    basicConstraints=CA:FALSE
    keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
    subjectAltName = @alt_names
    
    [alt_names]
    DNS.1 = $DOMAIN
EOF
        openssl x509 -req -in $ServerCSR -CA $CACertificate -CAkey $CAKey -CAcreateserial -out $ServerCertificate -extfile $TMP_DIR/server/v3.ext      
    else
        echo "Key files do not exist, please generate them first."
        exit -1
    fi    
}

compineCertificates(){
    echo "Compine ca certificate and server certificate!"
    Check="ok"
    if [ ! -f $ServerCertificate ]; then echo "$ServerCertificate does not exist!" && Check=""; fi    
    if [ ! -f $CACertificate ]; then echo "$CACertificate does not exist!" && Check=""; fi 
    if [ "$Check" == "ok" ]; then  
        touch "$ServerAllCertificate"
        cat $ServerCertificate >> "$ServerAllCertificate"
        cat $CACertificate >> "$ServerAllCertificate"
    else
        echo "Key files do not exist, please generate them first."
        exit -1
    fi    
}

installCertificates(){
    echo "Install certificates into $INSTALL_DIR."
    Check="ok"
    if [ ! -f $ServerAllCertificate ]; then echo "$ServerAllCertificate does not exist!" && Check=""; fi    
    if [ ! -f $ServerKey ]; then echo "$ServerKey does not exist!" && Check=""; fi 
    if [ ! -f $KeyStroe ]; then echo "$KeyStroe does not exist!" && Check=""; fi 
    if [ "$Check" == "ok" ]; then     
        cp $ServerKey $INSTALL_DIR/self-signed-key.pem
        cp $ServerAllCertificate $INSTALL_DIR/self-signed-cert.pem
        cp $KeyStroe $INSTALL_DIR/self-signed.jks
    else
        echo "Key files do not exist, please generate them first."
        exit -1
    fi 
}

convert2JKS(){
    echo "Convert PEM to JKS."
    Check="ok"
    if [ ! -f $ServerAllCertificate ]; then echo "$ServerAllCertificate does not exist!" && Check=""; fi    
    if [ ! -f $ServerKey ]; then echo "$ServerKey does not exist!" && Check=""; fi 
    if [ "$Check" == "ok" ]; then             
        rm -fr $ServerPKCS12
        rm -fr $KeyStroe
        openssl pkcs12 -export -in $ServerAllCertificate -inkey $ServerKey -out $ServerPKCS12 -name poly-vces -passin pass:Polycom123 -passout pass:Polycom123
        keytool -genkey -keyalg RSA -alias default -keystore $KeyStroe -storepass Polycom123 -dname "CN=poly.com, OU=PCTC, O=Poly, L=Beijing, S=Beijing, C=CN" 
        keytool -delete -alias default -keystore $KeyStroe -storepass Polycom123
        keytool -importkeystore -srckeystore $ServerPKCS12 -srcstoretype PKCS12 -srcstorepass Polycom123 -alias poly-vces -deststorepass Polycom123 -destkeypass Polycom123 -destkeystore $KeyStroe
    else
        echo "Key files do not exist, please generate them first."
        exit -1
    fi 
}

if [ -z "$DOMAIN" ]; then
    echo "Domain should not empty."
    usage $0
fi

if [ "$METHOD" == "generateRSAPrivateKey" ]; then    
    if [ "$GENERATE_KEY_TYPE" == "ca" ]; then
        generateRSAPrivateKey "ca"
    elif [ "$GENERATE_KEY_TYPE" == "server" ]; then
        generateRSAPrivateKey "server"
    else
        echo "genarate key type error!"
        exit -3
    fi
elif [ "$METHOD" == "createCSR" ]; then    
    createCSR
elif [ "$METHOD" == "signServerCertificate" ]; then
    signServerCertificate
elif [ "$METHOD" == "compineCertificates" ]; then
    compineCertificates
elif [ "$METHOD" == "installCertificates" ]; then
    installCertificates
elif [ "$METHOD" == "convert2JKS" ]; then
    convert2JKS
fi

exit 0
