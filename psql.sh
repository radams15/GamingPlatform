#!/bin/sh

user="postgres"

if [ "$1" != "" ]
then
    user=$1
fi

docker-compose exec -u postgres db psql -U $user postgres
