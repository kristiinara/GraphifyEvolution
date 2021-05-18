#!/bin/bash

grep --include=\*.java -rnw $1 -e "lombok" -l | xargs -I{} sh -c "java -jar JavaAnalyser/delomboc/lombock.jar delombok {} -p > '{}-tmp'"