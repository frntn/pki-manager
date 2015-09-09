#!/bin/bash -u

# default value should be override
CRT_CN=${CRT_CN:-"default"}

while getopts t:n:p:h opt
do
    case "$opt" in
        t) # Certificate Type (client/server)
           case $OPTARG in
               'client')
                   CERTYPE=$OPTARG
		   NO_PASSWD=${NO_PASSWD:-false} # <= PrivateKey with password by default for Client certificate
                   ;;
               'server')
                   CERTYPE=$OPTARG
		   NO_PASSWD=${NO_PASSWD:-true} # <= passwordless PrivateKey by default for Server certificate
                   ;;
               *)
                   echo >&2 "Unknown option '$1' (available values are 'client' or 'server'"
                   exit 1
                   ;;
           esac
           ;;
        p) PROJECT_NAME="$OPTARG" ;; # Project Name
        n) CRT_CN="$OPTARG"       ;; # Name (client: User fullname / server: Website URL)
        *)
           echo >&2 "
Usage: $0 -p projectname -t certype [-n name]

  -p projectname
        
        String to identify the project or client. Only used to create a
        distinct folder to separate the generated files. This _projectname_
        won't be used in the generated certificates.

  -t certype

        Allowed values are 'server' or 'client'
        Choose 'server' to create a x509 file to be installed on your server
        Choose 'client' to create a pkcs12 file to be installed on your browser

  -n name

        String to be used in the Common Name (CN) of the generated certificates
        For 'server' type it should be the URL of the server
        For 'client' type it should be the FULLNAME of the end user
"
           exit 1
           ;;
    esac
done

: $PROJECT_NAME
: $CERTYPE

[ ! -d "$PROJECT_NAME" ] && echo >&2 "FATAL: The project does exist yet" && exit 1
cd "$PROJECT_NAME"

CRT_UID="${CERTYPE}Certificate_$( date +%Y%m%d_%H%M%S )_$( echo ${CRT_CN} | tr -dc A-Za-z0-9 )"
PASSWD_STRING="$( $NO_PASSWD && echo "-nodes" || echo "-passout file:${CRT_UID}.key.pass" )"

umask 377
< /dev/urandom tr -dc A-Za-z0-9 | head -c30 > ${CRT_UID}.key.pass

# .key / .csr
openssl req \
    -new \
    -newkey rsa:4096 -keyout ${CRT_UID}.key $PASSWD_STRING \
    -out ${CRT_UID}.csr -subj "/C=${CRT_C:-"FR"}/L=${CRT_L:-"Paris"}/O=${CRT_O:-"Ekino"}/OU=${CRT_OU:-"DevOps"}/CN=${CRT_CN}"

# What to do here :
#  - TRUSTED CA => stop here, then send the generated .csr to your trusted CA
#  - CUSTOM CA  => continue and generate the .crt/.p12 file(s)
if ${CA_ISCUSTOM:-true}
then
    # .crt
    openssl x509 -req -days 365 -in ${CRT_UID}.csr -passin file:ca.pass -CA ca.crt -CAkey ca.key -CAserial ca.srl -CAcreateserial -out ${CRT_UID}.crt


    if [ "$CERTYPE" = "server" ]
    then
        echo "
$(tput bold)
The X509 file has been generated for server identified as '${CRT_CN}'

  pubcert.crt : $(readlink -f ${CRT_UID}.crt)

You can now install it on your server so the clients can identify your server.

NB1:
This server certificate is verified on the client side when the browser finds the CA used to generate this certificate in its list of *trusted* CA,
which means the CA certificate have to be deployed on the client in order to perform such verification (otherwise the identity will be reported as *untrusted*)
If you want your clients to be able to actually *trust* the provided identity (that famous 'green address bar' in a browser for example), you'll need to deploy the CA certificate on the client side

  pubcert_CA.crt : $(readlink -f ca.crt)
$(tput sgr0)
"
    elif [ "$CERTYPE" = "client" ]
    then
        # client.p12 (or .pfx)
        < /dev/urandom tr -dc A-Za-z0-9 | head -c15 > ${CRT_UID}.p12.pass
        openssl pkcs12 -export -passin file:${CRT_UID}.key.pass -inkey ${CRT_UID}.key -in ${CRT_UID}.crt -name "${CRT_CN}" -passout file:${CRT_UID}.p12.pass -out ${CRT_UID}.p12

        echo "
$(tput bold)
The PKCS12 file has been generated for user identified as '${CRT_CN}'
(it is password protected, and contains the public certificate with the associated --also password protected-- private key)

  container.p12       : $(readlink -f ${CRT_UID}.p12) # <-- password stored in $(readlink -f ${CRT_UID}.p12.pass)
    |
    |-- pubcert.crt   : $(readlink -f ${CRT_UID}.crt)
    \`-- privkey.key   : $(readlink -f ${CRT_UID}.key) # <-- password stored in $(readlink -f ${CRT_UID}.key.pass)

You can now install it on your browser so the servers can identify yourself.

NB1:
This client certificate is verified on the server side when the application finds the CA used to generate this certificate in its list of *trusted* CA,
which means the CA certificate have to be deployed on the server in order to perform such verification (otherwise the identity will be reported as *untrusted*)
If you want your server to be able to actually *trust* the provided identity (successful authentication), you'll need to deploy the CA certificate on the client side

NB2:
If the end user is using Windows, you might want to rename the file .p12 -> .pfx
$(tput sgr0)
"
        #echo
        #echo "Information extracted from that file :"
        #openssl pkcs12 -nokeys -info -in ${CRT_UID}.p12 -passin file:${CRT_UID}.pass | grep -E "subject=|issuer=" | awk '{print "pkcs12> "$0'
    fi
else
    echo "
$(tput bold)
The CSR file has been generated for ${CERTYPE} identified as '${CRT_CN}'

  pubreq.csr : $(readlink -f ${CRT_UID}.csr)'

You can now send it to your *trusted CA* (required for them to generate your signed certificate in return)
$(tput sgr0)
"
fi

umask 022
chmod 600 ca.srl
chmod 444 ${CRT_UID}.csr ${CRT_UID}.crt
