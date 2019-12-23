#!/bin/bash -x

/home/nutanix/cluster/bin/genesis stop msp_controller

wget http://filer.dev.eng.nutanix.com:8080/Users/pulkit/public/objects-demo-keepalived/msp-controller-installer-patched.tar.xz

sudo rm -rf /home/docker/msp_controller/*

sudo tar xf msp-controller-installer-patched.tar.xz -C /home/docker/msp_controller/

rm msp-controller-installer-patched.tar.xz

cluster start
