#!/bin/bash

# Creating an array that defines the environment variables
# that must be set. This can be consumed later via arrray
# variable expansion ${REQUIRED_ENV_VARS[@]}.
readonly REQUIRED_ENV_VARS=(
  "PGUSERNAME"
  "PGPASSWORD"
  "PGDBNAME"
  "POSTGRES_USER")

main() {
  check_env_vars_set
  init_user_and_db
}

check_env_vars_set() {
  for required_env_var in ${REQUIRED_ENV_VARS[@]}; do
    if [[ -z "${!required_env_var}" ]]; then
      echo "Error:
    Environment variable '$required_env_var' not set.
    Make sure you have the following environment variables set:
      ${REQUIRED_ENV_VARS[@]}
Aborting."
      exit 1
    fi
  done
}


# Performs the initialization in the already-started PostgreSQL
# using the preconfigured POSTGRE_USER user.
init_user_and_db() {
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
     CREATE USER $PGUSERNAME WITH PASSWORD '$PGPASSWORD';
     CREATE DATABASE $PGDBNAME TEMPLATE template_postgis_20;
     GRANT ALL PRIVILEGES ON DATABASE $PGDBNAME TO $PGUSERNAME;
EOSQL
}

# Executes the main routine with environment variables
# passed through the command line. We don't use them in
# this script but now you know 🤓
main "$@"