#!/bin/bash

find $1 -type f -name "*.java-tmp" | sed 's/\.java-tmp/.java/' | xargs -I{} mv "{}-tmp" "{}"