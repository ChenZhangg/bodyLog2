#!/bin/bash
count=0;
for old in `find . -name 'repo*'`
do
    new=repo$count
    echo "Renaming $old to $new"
    mv "$old" "$new"
    let count++
done