require 'json'
f=IO.read '../json_files/ReactiveX@RxJava/build@5277.json'
j= JSON.parse f
p j.class