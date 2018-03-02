#!/usr/bin/env bash
exit 1

source origin/.scope
docker run --rm --name origin-jenkins -p 8080:8080 --env JAVA_OPTS=$JENKINS_JAVA_OPTS jenkins/jenkins:lts-alpine
JENKINS_ADDR=http://127.0.0.1:8080 JENKINS_ADMIN_PASS=welcome1 ./jenkins-setup.sh