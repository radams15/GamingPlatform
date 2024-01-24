# How to use the config files

Install all of the conf files into `/var/lib/postgresql/data` and ensure they
are owned by the user running PostgreSQL.

The file pg\_hba.conf is altered to only allow SSL connections to the server.

The file postgresql.conf is altered to set the SSL certificates to the ones
provides.

The rest of the files are SSL certificate files, generated using openssl, which
allow the encryption to function.
