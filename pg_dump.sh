#!/bin/sh

podman-compose exec -u postgres db pg_dump $@
