#!/bin/bash

# See the link below for detailed steps
# https://elmiko.github.io/2018/05/18/python3-coming-to-radanalytics.html

# Pull resource yaml from rad
oc create -f https://radanalytics.io/resources.yaml

# Deploy custom notebook

# I pulled from elmiko's container and made this one
# quay.io/danclark/jupyter-notebook-py36:devel and :latest
# Original: elmiko/jupyter-notebook-py36
oc new-app quay.io/danclark/jupyter-notebook-py36:devel   -e JUPYTER_NOTEBOOK_PASSWORD=foo   -e PYSPARK_PYTHON=/opt/rh/rh-python36/root/usr/bin/python

oc new-app --template oshinko-python36-spark-build-dc   -p APPLICATION_NAME=sparkpi   -p GIT_URI=https://github.com/elmiko/tutorial-sparkpi-python-flask.git   -p GIT_REF=python3   -p OSHINKO_CLUSTER_NAME=spy3

./oshinko create spy3 --image=elmiko/openshift-spark:python36-latest --masters=1 --workers=3

oc expose svc/sparkpi
oc expose svc/jupyter-notebook-py36
