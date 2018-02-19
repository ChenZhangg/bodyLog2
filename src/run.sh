#!/bin/bash  
for((i=0;i<26;i=i+1))
do
  (nohup ruby downloadLogs.rb repo$i.csv > output$i 2>&1 & )&
done

