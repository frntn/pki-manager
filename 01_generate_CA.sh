#!/bin/bash -u

while getopts p:h opt
do
    case "$opt" in
        p) PROJECT_NAME="$OPTARG" ;; # Project Name
        *)
           echo >&2 "Usage: $0 -p projectname"
           exit 1
           ;;
    esac
done

: $PROJECT_NAME

[ -d "$PROJECT_NAME" ] && echo >&2 "FATAL: The project already exist" && exit 1
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

umask 377
< /dev/urandom tr -dc "+=\-%*\!&#':;{}()[]|^~\$_2-9T-Z" | head -c65 > ca.pass

# ca.key / ca.crt
openssl req \
    -new -x509 -days 365 \
    -newkey rsa:4096 -keyout ca.key -passout file:ca.pass \
    -out ca.crt -subj "/C=${CA_C:-"FR"}/L=${CA_L:-"Paris"}/O=${CA_O:-"Ekino"}/OU=${CA_OU:-"DevOps"}/CN=${CA_CN:-"$PROJECT_NAME"}"

umask 022
chmod 400 ca.key
chmod 444 ca.crt

echo
echo "The Certificate Authority files have been generated :"
echo " - key :         '$(readlink -f ca.key)'"
echo " - certificate : '$(readlink -f ca.crt)' (self-signed) "
