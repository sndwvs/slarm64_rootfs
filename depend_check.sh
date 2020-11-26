#!/bin/sh

export LC_MESSAGES=C
LOG="depend"

for exe in $(ls /{s,}bin /usr/{s,}bin);do
    if [[ -d ${exe/:/} ]];then
        echo -e "$exe" >> /$LOG
        DIR=${exe/:/}
    elif [[ $(ldd ${DIR}/$exe | grep "not found")  ]];then
        echo -e "\t$exe" >> /$LOG
        ldd ${DIR}/$exe | grep "not found" | xargs echo -e "\t\t" >> /$LOG
    fi
done
