#!/bin/bash

gradle -q --no-daemon dependencies --gradle-user-home $1 --project-dir $2

echo "done"