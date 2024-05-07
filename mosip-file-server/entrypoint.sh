#!/bin/bash

cp /mnt/mosip-file-server/.well-known/mosipvc/*  /home/mosip/mosip-file-server/.well-known/mosipvc/;

bash /home/mosip/get-cert.sh;

if [[ $? -gt 0 ]]; then
  echo "MOSIP's VC PUBLIC KEY Generation failed; EXITING";
  exit 1;
fi