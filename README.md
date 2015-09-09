# frntn/pki-manager

## Description

Manage small PKI for multiple projects with 2 bash scripts :

- `01_generate_CA.sh`: used once to create a dedicated CA for a specific project (usually a client)
- `02_generate_CRT.sh`: used as many time as needed to create either :
  - **server certificates (x509)** for your SSL-enabled server configuration
  - **client certificates (p12)** for your advanced and more secure client authentication (no more HTTP Basic Auth...)

## TL;DR

First create the CA:
```bash
./01_generate_CA.sh -p demo
```

Then create a server certificate (x509) and/or a client certificate (p12):
```
$ ./02_generate_CRT.sh -p demo -t server -n "*.example.com"
$ ./02_generate_CRT.sh -p demo -t client -n "Matthieu Fronton"
```

## Basic Usage

*RTFM*: Use `-h` to get basic help usage from each script. Also scripts output
is fairly detailed to explained what has been generated, where is it located 
and what to do with it.

## Advanced Usage

#### Override everything

All the `subject` fields of the certificates can be overridden with environment
variables to fit with your own needs :
- Country : `CRT_C`
- Location : `CRT_L`
- Organization : `CRT_O`
- Organizational Unit : `CRT_OU`
- Common Name : `CRT_CN` (if used in combination with `-n name`, the latter takes precedence)

Example below :

```
$ export CRT_C="US" CRT_L="Mountain View" CRT_O="iPhone Killer" CRT_OU="Snipers" CRT_CN="Larry Page"
$ ./02_generate_CRT.sh -p demo -t client
...
subject=/C=US/L=Mountain View/O=iPhone Killer/OU=Snipers/CN=Larry Page
...
```

You can also override the `subject` fields of the CA using `CA_C`, `CA_L`, `CA_O`, `CA_OU` or `CA_CN`.

## Full PKI Example 

The CA:
```bash
export CA_O="Cyberdyne Systems" CA_OU="Research" 
./01_generate_CA.sh -p "Terminator"
```

The SERVERS:
```bash
export CRT_O="Cyberdyne Systems" CRT_OU="Research-Cyborgs"
./02_generate_CRT.sh -p "Terminator" -t server -n "t-800.intra.cyberdyne"
./02_generate_CRT.sh -p "Terminator" -t server -n "t-1000.intra.cyberdyne"
```

The USERS:
```bash
export CRT_O="Connors Family" CRT_OU="Insurgent"
./02_generate_CRT.sh -p "Terminator" -t client -n "Kyle Reese"
./02_generate_CRT.sh -p "Terminator" -t client -n "Sarah Connor"
./02_generate_CRT.sh -p "Terminator" -t client -n "John Connor"

export CRT_O="US Air Force" CRT_OU="Sergeant"
./02_generate_CRT.sh -p "Terminator" -t client -n "William Candy"
```

The above generate the following certificates subjects :
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

## Finally

You may want to save your generated files in a **secured** git repository...

```
cd Terminator/
git init
git add *
git commit -m "First Commit"
git remote add origin git@gitlab.example.com:PKIs/terminator-pki.git
git push
```
