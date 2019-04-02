# AATA Arches

## About

AATA is a Getty GCI project to catalogue abstracts about conservation articles. This repository creates an application stack that uses the Arches content management system (http://archesproject.org/), with the models, ontologies and branches that is required to describe the metadata.

## Usage

Requires `docker` and `docker-compose`

### Build and Setup:
Run these commands from the root of the repository directory, as a user with sufficient privileges to run `docker` and `docker-compose` commands:

    [docker-user]$ docker-compose build --no-cache aata_arches
    [docker-user]$ docker-compose run aata_arches setup_aata

### Run:
Once the application container has been built and the setup command run once, it can be spun up and down as needed:

- Spin up:

    `[docker-user]$ docker-compose up -d`

- Spin down:

    `[docker-user]$ docker-compose down`

The application will be available at http://localhost by default.

### PROD/DEV deployment modes

To switch on (or off) debugging modes, please do the following:

    [docker-user]$ docker-compose down   # to spin down the application stack
    
    Edit the docker-compose.yml file, and change the following variables in the aata_arches environment variables:
    
    For production mode (served through nginx at http://localhost):
        - DJANGO_MODE=PROD
        - DJANGO_DEBUG=False
        
    For development mode with debugging (served by django runserver at http://localhost:8000):
        - DJANGO_MODE=DEV
        - DJANGO_DEBUG=True

### Get a commandline on the AATA Arches container:

It can be useful to get a commandline interface to the aata application container. When the stack is running, run the following. NB Once in, it is recommended to enter the application's python virtualenv as show below:

    [docker-user]$ docker exec -it aata_arches /bin/bash
    root@a84d01715b92:/web_root/arches# ls
    CONTRIBUTING.md     arches             docker                      node_modules              setup.py
    LICENSE.txt         arches.egg-info    docker-compose-default.yml  normal.sublime-workspace  tests
    MANIFEST.in         arches.log         docker-compose-test.yml     ontology                  untitled.sublime-workspace
    README.md           bandit.report.txt  export_pkg                  package-lock.json         yarn.lock
    _pkg_181018_054737  bash_env           gunicorn_config.py          package.json
    aata_config         cypress            manage.py                   pycallgraph.patch
    appspec.yml         cypress.json       new_fixtures                releases
    
    root@a84d01715b92:/web_root/arches# . ../ENV/bin/activate
    (ENV) root@a84d01715b92:/web_root/arches#

### Reset from scratch

If the source data, models, branches or ontology files are edited, you will likely wish to rebuild from scratch to reflect these changes. Run `docker-compose down -v` to not just spin down the application stack, but to *remove* its volumes. This will DELETE anything that had been created in the application. After this, run the build and setup steps again before spinning the application back up.

## Postgres + PostGIS

The default Postgres image has been altered to include a .sql file that creates a suitable PostGIS template database, and an initialisation script that creates a database and user. The PostGIS extension setup in the SQL likely will not be necessary given the use of a PostGIS-specific db container, but it would be helpful to move away from that to a more generic db image so the configuration is left for information. (It currently doesn't impact the functioning of the application).
