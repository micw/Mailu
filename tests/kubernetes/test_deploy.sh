#!/bin/bash

set -e

cd $( dirname $0 )

step() {
    echo
	echo "#############################################"
	echo "###"
	echo "### $*"
	echo "###"
	echo
}
err() {
    echo
	echo "#############################################"
	echo "###"
	echo "### $*"
	echo "###"
	echo "#############################################"
	echo
	exit 1
}

stop_cluster() {
	step "Stopping k3s cluster"
	set +e
	docker-compose down -v
	docker-compose rm -fsv
	set -e
}

start_cluster() {
  step "Starting k3s cluster"
  docker-compose up --build -d
}

await_cluster_ready() {
	step "Waiting for cluster to be ready"

	rc=1
	for i in {60..1}; do
	  set +e
	  docker-compose exec tools kubectl --kubeconfig kubeconfig.yaml get nodes 2>&1 | grep -E '\s+Ready\s+worker\s+' > /dev/null
	  rc=$?
	  set -e
	  if [ "$rc" == "0" ]; then
	    break
	  fi
	  echo -n "$i "
	  sleep 2
	done
	echo

	if [ "$rc" != "0" ]; then
		stop_cluster
		err "Cluster startup failed!"
	fi
	echo "Cluster ready."
}

deploy_ingress_controller() {
	step "Deploying ingress controller"

	docker-compose exec tools kubectl --kubeconfig kubeconfig.yaml apply -f ingress-traefik-1.7.yaml

	echo "Waiting for controller to become ready"

	rc=1
	for i in {60..1}; do
	  set +e
	  curl --fail 172.28.1.2:8080/api >/dev/null 2>&1
	  rc=$?
	  set -e
	  if [ "$rc" == "0" ]; then
	    break
	  fi
	  echo -n "$i "
	  sleep 2
	done
	echo

	if [ "$rc" != "0" ]; then
		stop_cluster
		err "Ingress controller did not start!"
	fi
	echo "Ingress controller ready."
}

deploy_mailu() {
	step "Deploying mailu using kustomize"

	docker-compose exec tools sh -c "kustomize build --load_restrictor none | kubectl --kubeconfig kubeconfig.yaml apply -f -"
}

stop_cluster

start_cluster

await_cluster_ready

deploy_ingress_controller

deploy_mailu

echo "Please wait until everything is pulled and started. This might take several minutes."
echo "Mailu should then be available running at"
echo
echo "Admin: http://172.28.1.2.xip.io/admin/ui"
echo "        Username: admin@example.com"
echo "        Password: admin"
echo
echo "Webmail: http://172.28.1.2.xip.io"
