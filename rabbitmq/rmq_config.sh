#!/usr/bin/env bash


kubectl --namespace haste delete secret rabbitmq-admin-creds
kubectl --namespace haste delete secret rabbitmq-user-creds

## create admin secret
kubectl --namespace haste create secret generic rabbitmq-admin-creds --from-literal=username=hasterabbit --from-literal=rabbitmq-password='pass0'

## create the other user secret, and additional config of vhost and permissions, that is otherwise lost when creating users this way.
kubectl --namespace haste create secret generic rabbitmq-user-creds --from-literal=load_definition.json="{\
   \"users\":[\
      {\
         \"name\":\"hasterabbit\",\
         \"password_hash\":\"$(python rabbitmq_password_hasher.py pass0)\",\
         \"hashing_algorithm\":\"rabbit_password_hashing_sha256\",\
         \"tags\":\"administrator\"\
      },\
      {\
         \"name\":\"guest\",\
         \"password_hash\":\"$(python rabbitmq_password_hasher.py guest)\",\
         \"hashing_algorithm\":\"rabbit_password_hashing_sha256\",\
         \"tags\":\"\"\
      }\
   ],\
   \"vhosts\":[\
      {\
         \"name\":\"/\"\
      }\
   ],\
   \"permissions\":[\
      {\
         \"user\":\"hasterabbit\",\
         \"vhost\":\"/\",\
         \"configure\":\".*\",\
         \"write\":\".*\",\
         \"read\":\".*\"\
      },\
      {\
         \"user\":\"guest\",\
         \"vhost\":\"/\",\
         \"configure\":\"\",\
         \"write\":\".*\",\
         \"read\":\".*\"\
      }\
   ]\
}"