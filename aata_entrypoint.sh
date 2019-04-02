#!/bin/bash

HELP_TEXT="

Arguments:
	run_aata: Default. Run the Arches server
	run_tests: Run unit tests
	setup_aata: Delete any existing Arches database and set up a fresh one
	-h or help: Display help text
"

display_help() {
	echo "${HELP_TEXT}"
}

APP_FOLDER=${ARCHES_ROOT}
PACKAGE_JSON_FOLDER=${ARCHES_ROOT}

# Read modules folder from yarn config file
# Get string after '--install.modules-folder' -> get first word of the result 
# -> remove line endlings -> trim quotes -> trim leading ./
YARN_MODULES_FOLDER=${PACKAGE_JSON_FOLDER}/$(awk \
	-F '--install.modules-folder' '{print $2}' ${PACKAGE_JSON_FOLDER}/.yarnrc \
	| awk '{print $1}' \
	| tr -d $'\r' \
	| tr -d '"' \
	| sed -e "s/^\.\///g")

export DJANGO_PORT=${DJANGO_PORT:-8000}
COUCHDB_URL="http://$COUCHDB_USER:$COUCHDB_PASS@$COUCHDB_HOST:$COUCHDB_PORT"
STATIC_ROOT=${STATIC_ROOT:-/static_root}


cd_web_root() {
	cd ${WEB_ROOT}
	echo "Current work directory: ${WEB_ROOT}"
}

cd_arches_root() {
	cd ${ARCHES_ROOT}
	echo "Current work directory: ${ARCHES_ROOT}"
}

cd_app_folder() {
	cd ${APP_FOLDER}
	echo "Current work directory: ${APP_FOLDER}"
}

cd_yarn_folder() {
	cd ${PACKAGE_JSON_FOLDER}
	echo "Current work directory: ${PACKAGE_JSON_FOLDER}"
}

activate_virtualenv() {
	. ${WEB_ROOT}/ENV/bin/activate
}


#### Install

init_aata() {
	if db_exists; then
		echo "Database ${PGDBNAME} already exists, skipping initialization."
		echo ""
	else
		echo "Database ${PGDBNAME} does not exists yet, starting setup..."
		setup_aata
	fi
}


# Setup Postgresql and Elasticsearch
setup_aata() {
	cd_arches_root
	activate_virtualenv

	echo "Clearing and setting up Elasticsearch indices"
	echo "============================================="
	echo
	python manage.py es delete_indexes
	python manage.py es setup_indexes
	echo

	echo "Running: Creating couchdb system databases"
	echo "=========================================="
	echo
	curl -X PUT ${COUCHDB_URL}/_users
	curl -X PUT ${COUCHDB_URL}/_global_changes
	curl -X PUT ${COUCHDB_URL}/_replicator
	echo

	echo "Running migrations"
	echo "=================="
	echo
	run_migrations
	echo

	echo "Importing Arches system graphs"
	echo "=============================="
	echo
	python manage.py packages -o import_graphs \
	                          -s ${ARCHES_ROOT}/arches/db/system_settings/Arches_System_Settings_Model.json \
	                          -ow=overwrite

	python manage.py packages -o import_business_data \
	                          -s ${ARCHES_ROOT}/arches/db/system_settings/Arches_System_Settings.json \
	                          -ow=overwrite
	echo

	echo "Importing AATA-specfic Concepts"
	echo "==============================="
	echo
	import_reference_data ${ARCHES_ROOT}/aata_config/rdm/thesaurus.skos.xml
	import_reference_data ${ARCHES_ROOT}/aata_config/rdm/collections.skos.xml
	echo

	echo "Importing AATA Branches"
	echo "======================="
	echo
	python manage.py packages -o import_graphs \
	                          -s ${ARCHES_ROOT}/aata_config/graphs/branches \
	                          -ow=overwrite
	echo

	echo "Importing AATA Models"
	echo "====================="
	echo
	python manage.py packages -o import_graphs \
	                          -s ${ARCHES_ROOT}/aata_config/graphs/resource_models \
	                          -ow=overwrite
	echo

	echo "Having to do a 'makemigrations' step as the master migrations are a little broken it seems"
	python manage.py makemigrations
	run_migrations

	install_yarn_components
}

wait_for_db() {
	echo "Testing if database server is up..."
	while [[ ! ${return_code} == 0 ]]
	do
				psql --host=${PGHOST} --port=${PGPORT} --user=${PGUSERNAME} --dbname=postgres -c "select 1" >&/dev/null
		return_code=$?
		sleep 1
	done
	echo "Database server is up"

		echo "Testing if Elasticsearch is up..."
		while [[ ! ${return_code} == 0 ]]
		do
				curl -s "http://${ESHOST}:${ESPORT}" >&/dev/null
				return_code=$?
				sleep 1
		done
		echo "Elasticsearch is up"
}

set_dev_mode() {
	echo ""
	echo ""
	echo "----- SETTING DEV MODE -----"
	echo ""
	cd_arches_root
	python ${ARCHES_ROOT}/setup.py develop
}


# Yarn
init_yarn_components() {
	if [[ ! -d ${YARN_MODULES_FOLDER} ]] || [[ ! "$(ls ${YARN_MODULES_FOLDER})" ]]; then
		echo "Yarn modules do not exist, installing..."
		install_yarn_components
	fi
}

# This is also done in Dockerfile, but that does not include user's custom Arches app package.json
# Also, the packages folder may have been overlaid by a Docker volume.
install_yarn_components() {
	echo ""
	echo ""
	echo "----- INSTALLING YARN COMPONENTS -----"
	echo ""
	cd_yarn_folder
	yarn install
}

graphs_exist() {
	row_count=$(psql -h ${PGHOST} -p ${PGPORT} -U postgres -d ${PGDBNAME} -Atc "SELECT COUNT(*) FROM public.graphs")
	if [[ ${row_count} -le 3 ]]; then
		return 1
	else
		return 0
	fi
}

concepts_exist() {
	row_count=$(psql -h ${PGHOST} -p ${PGPORT} -U postgres -d ${PGDBNAME} -Atc "SELECT COUNT(*) FROM public.concepts WHERE nodetype = 'Concept'")
	if [[ ${row_count} -le 2 ]]; then
		return 1
	else
		return 0
	fi
}

collections_exist() {
	row_count=$(psql -h ${PGHOST} -p ${PGPORT} -U postgres -d ${PGDBNAME} -Atc "SELECT COUNT(*) FROM public.concepts WHERE nodetype = 'Collection'")
	if [[ ${row_count} -le 1 ]]; then
		return 1
	else
		return 0
	fi
}

import_reference_data() {
	# Import example concept schemes
	local rdf_file="$1"
	echo "Running: python manage.py packages -o import_reference_data -s \"${rdf_file}\""
	python manage.py packages -o import_reference_data -s "${rdf_file}"
}

copy_settings_local() {
	# The settings_local.py in ${ARCHES_ROOT}/arches/ gets ignored if running manage.py from a custom Arches project instead of Arches core app
	echo "Copying ${ARCHES_ROOT}/arches/settings_local.py to ${APP_FOLDER}/${ARCHES_PROJECT}/settings_local.py..."
	cp ${ARCHES_ROOT}/arches/settings_local.py ${APP_FOLDER}/${ARCHES_PROJECT}/settings_local.py
}

# Allows users to add scripts that are run on startup (after this entrypoint)
run_custom_scripts() {
	for file in ${CUSTOM_SCRIPT_FOLDER}/*; do
		if [[ -f ${file} ]]; then
			echo ""
			echo ""
			echo "----- RUNNING CUSTUM SCRIPT: ${file} -----"
			echo ""
			source ${file}
		fi
	done
}




#### Run

run_migrations() {
	echo ""
	echo ""
	echo "----- RUNNING DATABASE MIGRATIONS -----"
	echo ""
	cd_app_folder
	python manage.py migrate
}

collect_static(){
	echo ""
	echo ""
	echo "----- COLLECTING DJANGO STATIC FILES -----"
	echo ""
	cd_app_folder
	python manage.py collectstatic --noinput
}


run_django_server() {
	echo ""
	echo ""
	echo "----- *** RUNNING DJANGO DEVELOPMENT SERVER *** -----"
	echo ""
	cd_app_folder
	if [[ ${DJANGO_REMOTE_DEBUG} != "True" ]]; then
			echo "Running Django with livereload."
		exec python manage.py runserver 0.0.0.0:${DJANGO_PORT}
	else
				echo "Running Django with options --noreload --nothreading for remote debugging."
		exec python manage.py runserver --noreload --nothreading 0.0.0.0:${DJANGO_PORT}
	fi
}


run_gunicorn_server() {
	echo ""
	echo ""
	echo "----- *** RUNNING GUNICORN PRODUCTION SERVER *** -----"
	echo ""
	cd_app_folder
	
	if [[ ! -z ${ARCHES_PROJECT} ]]; then
				gunicorn arches.wsgi:application \
						--config ${ARCHES_ROOT}/gunicorn_config.py \
						--pythonpath ${ARCHES_PROJECT}
	else
				gunicorn arches.wsgi:application \
						--config ${ARCHES_ROOT}/gunicorn_config.py
		fi
}



#### Main commands
run_aata() {

	#init_aata

	#init_yarn_components

	if [[ "${DJANGO_MODE}" == "DEV" ]]; then
		set_dev_mode
	fi

	run_custom_scripts

	if [[ "${DJANGO_MODE}" == "DEV" ]]; then
		run_django_server
	elif [[ "${DJANGO_MODE}" == "PROD" ]]; then
		collect_static
		run_gunicorn_server
	fi
}


run_tests() {
	set_dev_mode
	echo ""
	echo ""
	echo "----- RUNNING ARCHES TESTS -----"
	echo ""
	cd_arches_root
	python manage.py test tests --pattern="*.py" --settings="tests.test_settings" --exe
	if [ $? -ne 0 ]; then
				echo "Error: Not all tests ran succesfully."
		echo "Exiting..."
				exit 1
	fi
}




### Starting point ###

activate_virtualenv

# Use -gt 1 to consume two arguments per pass in the loop (e.g. each
# argument has a corresponding value to go with it).
# Use -gt 0 to consume one or more arguments per pass in the loop (e.g.
# some arguments don't have a corresponding value to go with it, such as --help ).

# If no arguments are supplied, assume the server needs to be run
if [[ $#	-eq 0 ]]; then
	run_aata
fi

# Else, process arguments
echo "Full command: $@"
while [[ $# -gt 0 ]]
do
	key="$1"
	echo "Command: ${key}"

	case ${key} in
		run_aata)
			wait_for_db
			run_aata
		;;
		setup_aata)
			wait_for_db
			setup_aata
		;;
		run_tests)
			wait_for_db
			run_tests
		;;
		run_migrations)
			wait_for_db
			run_migrations
		;;
		install_yarn_components)
			install_yarn_components
		;;
		help|-h)
			display_help
		;;
		*)
						cd_app_folder
			"$@"
			exit 0
		;;
	esac
	shift # next argument or value
done
