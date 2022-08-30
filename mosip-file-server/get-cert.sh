#!/usr/bin/env bash

#get date
date=$(date --utc +%FT%T.%3NZ)

#get secret
clientsecret_env=$(curl $spring_config_url_env/*/$active_profile_env/$spring_config_label_env/registration-processor-$active_profile_env.properties | sed -n '/token.request.secretKey=/,/ /p' | cut -d '#' -f1 |  sed 's/.*secretKey=//; s/$\n.*//' | awk 'NR==1{print $1}')

if [[ $clientsecret_env =~ '{cipher}' ]]; then
   echo "It clientsecret_env is encrypted; Decrypting";
   clientsecret_env=$( echo $clientsecret_env | sed 's/{cipher}//g' )
   clientsecret_env=$( curl $spring_config_url_env/decrypt -d $clientsecret_env )
fi

#echo "* Request for authorization"
curl -s -D - -o /dev/null -X "POST" \
  "$auth_url_env/v1/authmanager/authenticate/clientidsecretkey" \
  -H "accept: */*" \
  -H "Content-Type: application/json" \
  -d '{
  "id": "string",
  "version": "string",
  "requesttime": "'$date'",
  "metadata": {},
  "request": {
    "clientId": "mosip-regproc-client",
    "secretKey": "'$clientsecret_env'",
    "appId": "regproc"
  }
}' > temp.txt 2>&1 &

sleep 10
#TOKEN=$(cat -n temp.txt | sed -n '/Authorization:/,/\;.*/pI' |  sed 's/.*Authorization://i; s/$\n.*//I' | awk 'NR==1{print $1}')
#TOKEN=$(cat -n temp.txt | grep -i Authorization: |  sed 's/.*Authorization://i; s/$\n.*//' | awk 'NR==1{print $1}')
TOKEN=$( cat temp.txt | awk '/[aA]uthorization:/{print $2}' | sed -z 's/\n//g' | sed -z 's/\r//g')

curl -X "GET" \
  -H "Accept: application/json" \
  --cookie "Authorization=$TOKEN" \
  "$key_url_env/v1/keymanager/getCertificate?applicationId=KERNEL&referenceId=SIGN" > result.txt

RESULT=$(cat result.txt)
CERT=$(echo $RESULT | sed 's/.*certificate\":\"//gi' | sed 's/\".*//gI')
echo $CERT | sed -e 's/\\n/\n/g' > cert.pem
openssl x509 -pubkey -noout -in cert.pem  > pubkey.pem
sed -i "s&replace-public-key&$(cat pubkey.pem | sed -E ':a;N;$!ba;s/\r{0,1}\n/\\\\r\\\\n/g')&g" $base_path_mosipvc/public-key.json

echo "public key creation complete"

curl $spring_config_url_env/*/$active_profile_env/$spring_config_label_env/mosip-context.json > $base_path_mosipvc/mosip-context.json
echo "Downloaded mosip-context.json from config-server to $base_path_mosipvc/mosip-context.json !!!"

curl $spring_config_url_env/*/$active_profile_env/$spring_config_label_env/controller.json > $base_path_mosipvc/controller.json
echo "Downloaded controller.json from config-server to $base_path_mosipvc/controller.json !!!"

sleep 5

exec "$@"
