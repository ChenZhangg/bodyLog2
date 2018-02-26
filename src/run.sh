#!/bin/bash  
for((i=0;i<76;i=i+1))
do
  (nohup ruby downloadLogs.rb repo$i > output$i 2>&1 & )&
done

