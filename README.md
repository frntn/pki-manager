# frntn/pki-manager

## Description

Manage small PKI for multiple projects with 2 bash scripts :

- `01_generate_CA.sh`: used once to create a dedicated CA for a specific project (usually a client)
- `02_generate_CRT.sh`: used as many time as needed to create either :
  - **server certificates (x509)** for your SSL-enabled server configuration
  - **client certificates (p12)** for your advanced and more secure client authentication (no more HTTP Basic Auth...)

## Basic Usage

#### Create *the* CA

```
$ ./01_generate_CA.sh -h
Usage: ./01_generate_CA.sh -p projectname
```

*For example:*

```
$ ./01_generate_CA.sh -p demo
Generating a 4096 bit RSA private key
....++
....................++
writing new private key to 'ca.key'
-----

The Certificate Authority files have been generated :
 - key :         '/lab/frntn/pki-manager/demo/ca.key'
 - certificate : '/lab/frntn/pki-manager/demo/ca.crt' (self-signed) 
```

#### Create a server certificate

The help shows you everything you need to know to start with :

```
Usage: ./02_generate_CRT.sh -p projectname -t certype [-n name]

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
```

*For example:*

```
$ ./02_generate_CRT.sh -p demo -t server -n "*.example.com"
Generating a 4096 bit RSA private key
.++
......................................++
writing new private key to 'serverCertificate_20150909_083432_examplecom.key'
-----
Signature ok
subject=/C=FR/L=Paris/O=Ekino/OU=DevOps/CN=*.example.com
Getting CA Private Key


The X509 file has been generated for server identified as '*.example.com'

  pubcert.crt : /lab/frntn/pki-manager/demo/serverCertificate_20150909_083432_examplecom.crt

You can now install it on your server so the clients can identify your server.

NB1:
This server certificate is verified on the client side when the browser finds the CA used to generate this certificate in its list of *trusted* CA,
which means the CA certificate have to be deployed on the client in order to perform such verification (otherwise the identity will be reported as *untrusted*)
If you want your clients to be able to actually *trust* the provided identity (that famous 'green address bar' in a browser for example), you'll need to deploy the CA certificate on the client side

  pubcert_CA.crt : /lab/frntn/pki-manager/demo/ca.crt

```

#### Create a client certificate

*For example:*

```
$ ./02_generate_CRT.sh -p demo -t client -n "Matthieu Fronton"
Generating a 4096 bit RSA private key
...................++
...++
writing new private key to 'clientCertificate_20150909_090153_MatthieuFronton.key'
-----
Signature ok
subject=/C=FR/L=Paris/O=Ekino/OU=DevOps/CN=Matthieu Fronton
Getting CA Private Key


The PKCS12 file has been generated for user identified as 'Matthieu Fronton'
(it is password protected, and contains the public certificate with the associated --also password protected-- private key)

  container.p12       : /lab/frntn/pki-manager/demo/clientCertificate_20150909_090153_MatthieuFronton.p12 # <-- password stored in /lab/frntn/pki-manager/demo/clientCertificate_20150909_090153_MatthieuFronton.p12.pass
    |
    |-- pubcert.crt   : /lab/frntn/pki-manager/demo/clientCertificate_20150909_090153_MatthieuFronton.crt
    `-- privkey.key   : /lab/frntn/pki-manager/demo/clientCertificate_20150909_090153_MatthieuFronton.key # <-- password stored in /lab/frntn/pki-manager/demo/clientCertificate_20150909_090153_MatthieuFronton.key.pass

You can now install it on your browser so the servers can identify yourself.

NB1:
This client certificate is verified on the server side when the application finds the CA used to generate this certificate in its list of *trusted* CA,
which means the CA certificate have to be deployed on the server in order to perform such verification (otherwise the identity will be reported as *untrusted*)
If you want your server to be able to actually *trust* the provided identity (successful authentication), you'll need to deploy the CA certificate on the client side

NB2:
If the end user is using Windows, you might want to rename the file .p12 -> .pfx

```

## Advanced Usage

#### Override everything

All the `subject` fields of the certificate can be overridden with environment variables to fit with your own needs :
- Country : `CRT_C`
- Location : `CRT_L`
- Organization : `CRT_O`
- Organizational Unit : `CRT_OU`
- Common Name : `CRT_CN` (if used in combination with `-n name`, the latter takes precedence)

```
$ export CRT_C="US" CRT_L="Mountain View" CRT_O="iPhone Killer" CRT_OU="Snipers" CRT_CN="Larry Page"
$ ./02_generate_CRT.sh -p demo -t client
...
subject=/C=US/L=Mountain View/O=iPhone Killer/OU=Snipers/CN=Larry Page
...
```

Oh, and you can also override the subject of the CA : `CA_C`, `CA_L`, `CA_O`, `CA_OU`, `CA_CN`.

## Full PKI Example 

```
export CA_O="Cyberdyne Systems" CA_OU="Research" 
./01_generate_CA.sh -p "Terminator"

export CRT_O="Cyberdyne Systems" CRT_OU="Research-Cyborgs"
./02_generate_CRT.sh -p "Terminator" -t server -n "t-800.intra.cyberdyne"
./02_generate_CRT.sh -p "Terminator" -t server -n "t-1000.intra.cyberdyne"

export CRT_O="Connors Family" CRT_OU="Insurgent"
./02_generate_CRT.sh -p "Terminator" -t client -n "Kyle Reese"
./02_generate_CRT.sh -p "Terminator" -t client -n "Sarah Connor"
./02_generate_CRT.sh -p "Terminator" -t client -n "John Connor"

export CRT_O="US Air Force" CRT_OU="Sergeant"
./02_generate_CRT.sh -p "Terminator" -t client -n "William Candy"
```

This generate the following certificates :
```
$ for i in Terminator/server*.crt; do openssl x509 -in $i -noout -subject | awk '{print "x509> "$0}'; done
x509> subject= /C=FR/L=Paris/O=Cyberdyne Systems/OU=Research-Cyborgs/CN=t-800.intra.cyberdyne
x509> subject= /C=FR/L=Paris/O=Cyberdyne Systems/OU=Research-Cyborgs/CN=t-1000.intra.cyberdyne

$ for i in Terminator/client*.p12; do openssl pkcs12 -nokeys -info -in $i -passin file:${i}.pass 2>/dev/null| grep -E "subject=" | awk '{print "pkcs12> "$0}'; done
pkcs12> subject=/C=FR/L=Paris/O=Connors Family/OU=Insurgent/CN=Kyle Reese
pkcs12> subject=/C=FR/L=Paris/O=Connors Family/OU=Insurgent/CN=Sarah Connor
pkcs12> subject=/C=FR/L=Paris/O=Connors Family/OU=Insurgent/CN=John Connor
pkcs12> subject=/C=FR/L=Paris/O=US Air Force/OU=Sergeant/CN=William Candy
```

# Finally

You may want to save your generated files in a **secured** git repository...

```
cd Terminator/
git init
git add *
git commit -m "First Commit"
git remote add origin git@gitlab.example.com:PKIs/terminator-pki.git
git push
```
