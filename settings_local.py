import os
from django.core.exceptions import ImproperlyConfigured
import ast
import requests
import sys
from settings import *


def get_env_variable(var_name):
    msg = "Set the %s environment variable"
    try:
        return os.environ[var_name]
    except KeyError:
        error_msg = msg % var_name
        raise ImproperlyConfigured(error_msg)


def get_optional_env_variable(var_name):
    try:
        return os.environ[var_name]
    except KeyError:
        return None

ARCHES_NAMESPACE_FOR_DATA_EXPORT = 'http://localhost:8000/'

USER_ARCHES_NAMESPACE_FOR_DATA_EXPORT = get_optional_env_variable('ARCHES_NAMESPACE_FOR_DATA_EXPORT')
if USER_ARCHES_NAMESPACE_FOR_DATA_EXPORT:
    # Make this unique, and don't share it with anybody.
    ARCHES_NAMESPACE_FOR_DATA_EXPORT = USER_ARCHES_NAMESPACE_FOR_DATA_EXPORT

ONTOLOGY_PATH = 'ontology/linked_art'
ONTOLOGY_BASE = 'cidoc_crm_v6.2.4.xml'
ONTOLOGY_BASE_NAME = 'Linked Art'
ONTOLOGY_EXT = ['linkedart.xml', 'linkedart_crm_enhancements.xml']
ONTOLOGY_NAMESPACES = {
        "http://purl.org/dc/terms/": "dcterms",
        "http://purl.org/dc/elements/1.1/": "dc",
        "http://schema.org/": "schema",
        "http://www.w3.org/2004/02/skos/core#": "skos",
        "http://www.w3.org/2000/01/rdf-schema#": "rdfs",
        "http://xmlns.com/foaf/0.1/": "foaf",
        "http://www.w3.org/2001/XMLSchema#": "xsd",
        "https://linked.art/ns/terms/": 'la',
    'http://www.w3.org/1999/02/22-rdf-syntax-ns#': 'rdf',
    'http://www.cidoc-crm.org/cidoc-crm/': '',
    'http://www.ics.forth.gr/isl/CRMgeo/': 'geo',
    'http://www.ics.forth.gr/isl/CRMsci/': 'sci'
}

# options are either "PROD" or "DEV" (installing with Dev mode set gets you extra dependencies)
MODE = get_env_variable('DJANGO_MODE')

DEBUG = ast.literal_eval(get_env_variable('DJANGO_DEBUG'))

COUCHDB_URL = 'http://{}:{}@{}:{}'.format(get_env_variable('COUCHDB_USER'), get_env_variable('COUCHDB_PASS'),
                                          get_env_variable('COUCHDB_HOST'),
                                          get_env_variable('COUCHDB_PORT'))  # defaults to localhost:5984

DATABASES = {
    'default': {
        'ENGINE': 'django.contrib.gis.db.backends.postgis',
        'NAME': get_env_variable('PGDBNAME'),
        'USER': get_env_variable('PGUSERNAME'),
        'PASSWORD': get_env_variable('PGPASSWORD'),
        'HOST': get_env_variable('PGHOST'),
        'PORT': get_env_variable('PGPORT'),
        'POSTGIS_TEMPLATE': 'template_postgis_20',
    }
}

ELASTICSEARCH_HTTP_PORT = get_env_variable('ESPORT')
ELASTICSEARCH_HOSTS = [
    {'host': get_env_variable('ESHOST'), 'port': ELASTICSEARCH_HTTP_PORT}
]

USER_ELASTICSEARCH_PREFIX = get_optional_env_variable('ELASTICSEARCH_PREFIX')
if USER_ELASTICSEARCH_PREFIX:
    ELASTICSEARCH_PREFIX = USER_ELASTICSEARCH_PREFIX

ALLOWED_HOSTS = get_env_variable('DOMAIN_NAMES').split()

USER_SECRET_KEY = get_optional_env_variable('DJANGO_SECRET_KEY')
if USER_SECRET_KEY:
    # Make this unique, and don't share it with anybody.
    SECRET_KEY = USER_SECRET_KEY

STATIC_ROOT = '/static_root'

APP_NAME = 'AATA'

APP_TITLE = 'AATA | Arches'
COPYRIGHT_TEXT = ''
COPYRIGHT_YEAR = '2019'
