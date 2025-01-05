#!/bin/bash

version=$(cat info.json | grep '"version"' | cut -d ':' -f 2- | sed 's/[ ,"]//g')
dir="circuit-network-research-management_"$version
mkdir $dir
cp LICENSE $dir
cp info.json $dir
cp *.lua $dir
cp -r locale $dir
zip -r $dir.zip $dir
