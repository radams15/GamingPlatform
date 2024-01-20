#!/bin/sh

podman-compose exec -u postgres db psql $@
