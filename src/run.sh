#!/bin/bash  

(nohup ruby parallelDownloadLog.rb repo0.csv > output0 2>&1 & )&
(nohup ruby parallelDownloadLog.rb repo1.csv > output1 2>&1 & )&
(nohup ruby parallelDownloadLog.rb repo2.csv > output2 2>&1 & )&
(nohup ruby parallelDownloadLog.rb repo3.csv > output3 2>&1 & )&
(nohup ruby parallelDownloadLog.rb repo4.csv > output4 2>&1 & )&

