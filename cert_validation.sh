#!/bin/sh

########################################################
#
#       Check certificates inside a java keystore
#
########################################################
TIMEOUT="timeout -k 10s 5s "
KEYTOOL="keytool"
THRESHOLD_IN_DAYS="30"
KEYSTORE=""
PASSWORD=""
RET=0

ARGS=`getopt -o "p:k:t:" -l "password:,keystore:,threshold:" -n "$0" -- "$@"`

function usage {
        echo "Usage: $0 --keystore <keystore> [--password <password>] [--threshold <number of days until expiry>]"
        exit
}



function start {
        CURRENT=`date +%s`

        THRESHOLD=$(($CURRENT + ($THRESHOLD_IN_DAYS*24*60*60)))
        if [ $THRESHOLD -le $CURRENT ]; then
                echo "[ERROR] Invalid date."
                exit 1
        fi
        echo "Looking for certificates inside the keystore $(basename $KEYSTORE) expiring in $THRESHOLD_IN_DAYS day(s)..."

        $KEYTOOL -list -v -keystore "$KEYSTORE"  -storepass $PASSWORD 2>&1 > /dev/null
        if [ $? -gt 0 ]; then echo "Error opening the keystore."; exit 1; fi

        $KEYTOOL -list -v -keystore "$KEYSTORE"  -storepass $PASSWORD | grep Alias | awk '{print $3}' | while read ALIAS
        do
                #Iterate through all the certificate alias
                EXPIRACY="$(keytool -list -v -keystore $KEYSTORE  -storepass $PASSWORD -alias $ALIAS | grep Valid)"
                UNTIL="$(keytool -list -v -keystore "$KEYSTORE"  -storepass $PASSWORD -alias $ALIAS | grep Valid | head -1 |  perl -ne 'if(/until: (.*?)\n/) { print "$1\n"; }')"
                UNTIL_SECONDS="$(date -d $UNTIL +%s )"
                #REMAINING_DAYS=$(( ($UNTIL_SECONDS -  $(date +%s)) / 60 / 60 / 24 ))
                echo "until - $UNTIL and Useconds - $UNTIL_SECONDS "
                if [ $THRESHOLD -ge $UNTIL_SECONDS ]; then
                        echo "[OK] Certificate $ALIAS looks good as it expires in '$UNTIL' ."
                else
                        echo "[Waring]   Alert! Alert! Alert!   Certificate $ALIAS expires in '$UNTIL' ."
                        RET=1
                fi

        done
        echo "Finished..."
        exit $RET
}

eval set -- "$ARGS"

while true
do
        case "$1" in
                -p|--password)
                        if [ -n "$2" ]; then PASSWORD=" -storepass $2"; else echo "Invalid password"; exit 1; fi
                        shift 2;;
                -k|--keystore)
                        if [ ! -f "$2" ]; then echo "Keystore not found: $1"; exit 1; else KEYSTORE=$2; fi
                        shift 2;;
                -t|--threshold)
                        if [ -n "$2" ] && [[ $2 =~ ^[0-9]+$ ]]; then THRESHOLD_IN_DAYS=$2; else echo "Invalid threshold"; exit 1; fi
                        shift 2;;
                --)
                        shift
                        break;;
        esac
done

#if [ -n "$KEYSTORE" ]
#then
        start
#else
#        usage
#fi
