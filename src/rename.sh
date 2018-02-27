#!/bin/bash
count=0;
for old in `find . -name 'temp*'`
do
    new=repo$count
    echo "Renaming $old to $new"
    mv "$old" "$new"
    let count++
done
