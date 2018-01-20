#!/bin/bash  

(nohup ruby parallelDownloadLog.rb repo0.csv > output0 2>&1 & )&
(nohup ruby parallelDownloadLog.rb repo1.csv > output1 2>&1 & )&
(nohup ruby parallelDownloadLog.rb repo2.csv > output2 2>&1 & )&
(nohup ruby parallelDownloadLog.rb repo3.csv > output3 2>&1 & )&
(nohup ruby parallelDownloadLog.rb repo4.csv > output4 2>&1 & )&
(nohup ruby parallelDownloadLog.rb repo5.csv > output5 2>&1 & )&
(nohup ruby parallelDownloadLog.rb repo6.csv > output6 2>&1 & )&
(nohup ruby parallelDownloadLog.rb repo6.csv > output7 2>&1 & )&
(nohup ruby parallelDownloadLog.rb repo8.csv > output8 2>&1 & )&
(nohup ruby parallelDownloadLog.rb repo9.csv > output9 2>&1 & )&
