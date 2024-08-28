# talos-proxmox-testlab

## Introduction

The goal of this guide is setting up a Talos testlab with 4 vm's (one control node and 3 workers) scripted using
terraform and proxmox, with bash scripts and repeatable commands.

## Client preparations

Assuming we're using a linux machine as a client:

install terraform:

    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update
    sudo apt-get install terraform

install kubectl:

    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly
    sudo apt-get update
    sudo apt-get install -y kubectl


## Getting the Talos image

Because we want Talos with extensions, we're going to build a specific image. Go to the talos-image folder, create
a file called `longhorn.yaml`:

    customization:
      systemExtensions:
        officialExtensions:
          - siderolabs/iscsi-tools
          - siderolabs/util-linux-tools
          - siderolabs/gvisor
          - siderolabs/qemu-guest-agent

run the command:

    curl -X POST --data-binary @longhorn.yaml https://factory.talos.dev/schematics

it will show this output:

    {"id":"c527b6b20fb22847304656677e9bd4c4055dfcce95f3385da5db80e35f5fa1dc"}

The result is that you can download this iso:

    curl -o talos-metal-amd64.iso https://factory.talos.dev/image/c527b6b20fb22847304656677e9bd4c4055dfcce95f3385da5db80e35f5fa1dc/v1.7.6/metal-amd64.iso

Put it in the proxmox ISO store with the name local/iso:talos-metal-amd64.iso (that name is later used in terraform)

## Terraform

Go to the terraform folder, change the credentials, and do a `terraform init` and `terraform apply`.

It should show output like this:

    $ terraform output
    proxmox_ip_address_talos_01 = [
      "${TALOS01IP}",
    ]
    proxmox_ip_address_talos_02 = [
      "192.168.128.224",
    ]
    proxmox_ip_address_talos_03 = [
      "192.168.128.220",
    ]
    proxmox_ip_address_talos_04 = [
      "192.168.128.223",
    ]

Fill some environment variables to make the rest of the commands easier:

    export TALOS01IP=$(terraform output -json | jq -r .proxmox_ip_address_talos_01.value[0])
    export TALOS02IP=$(terraform output -json | jq -r .proxmox_ip_address_talos_02.value[0])
    export TALOS03IP=$(terraform output -json | jq -r .proxmox_ip_address_talos_03.value[0])
    export TALOS04IP=$(terraform output -json | jq -r .proxmox_ip_address_talos_04.value[0])
    export | grep TALOS

## Creating a Talos config

Got to the 'talos' directory in this repo. Let's create a new cluster called testcluster, with an endpoint point to the controller node.

    $ talosctl gen config testcluster https://${TALOS01IP}:6443
    generating PKI and tokens
    Created /home/angelo/kube-terraform/talos/controlplane.yaml
    Created /home/angelo/kube-terraform/talos/worker.yaml
    Created /home/angelo/kube-terraform/talos/talosconfig

Let's patch this files with the correct custom image we did before:

    talosctl machineconfig patch controlplane.yaml --patch '[{"op": "replace", "path": "/machine/install/image", "value": "factory.talos.dev/installer/c527b6b20fb22847304656677e9bd4c4055dfcce95f3385da5db80e35f5fa1dc:v1.7.6"}]' -o controlplane.yaml
    talosctl machineconfig patch worker.yaml --patch '[{"op": "replace", "path": "/machine/install/image", "value": "factory.talos.dev/installer/c527b6b20fb22847304656677e9bd4c4055dfcce95f3385da5db80e35f5fa1dc:v1.7.6"}]' -o worker.yaml

Let's create machine-specific configs:

    talosctl machineconfig patch controlplane.yaml --patch '[{"op": "add", "path": "/machine/network/hostname", "value": "talos-01"}]' -o talos-01.yaml
    talosctl machineconfig patch worker.yaml --patch '[{"op": "add", "path": "/machine/network/hostname", "value": "talos-02"}]' -o talos-02.yaml
    talosctl machineconfig patch worker.yaml --patch '[{"op": "add", "path": "/machine/network/hostname", "value": "talos-03"}]' -o talos-03.yaml
    talosctl machineconfig patch worker.yaml --patch '[{"op": "add", "path": "/machine/network/hostname", "value": "talos-04"}]' -o talos-04.yaml


Add the control node:

    talosctl apply-config --insecure --nodes ${TALOS01IP} --file talos-01.yaml

Wait for it to reboot and the 'KUBELET' status to go to healthy, and bootstrap kubernetes:

    talosctl bootstrap --nodes ${TALOS01IP} --endpoints ${TALOS01IP} --talosconfig=./talosconfig

This can take a few minutes. 
Get the kubernetes config to be used by kubectl:

    talosctl kubeconfig --nodes ${TALOS01IP} --endpoints ${TALOS01IP} --talosconfig=./talosconfig

After a while kubernetes should be ready:

    $ kubectl get nodes
    NAME       STATUS   ROLES           AGE     VERSION
    talos-01   Ready    control-plane   5m13s   v1.30.3

Now add the worker nodes:

    talosctl apply-config --insecure --nodes ${TALOS02IP} --file talos-02.yaml
    talosctl apply-config --insecure --nodes ${TALOS03IP} --file talos-03.yaml
    talosctl apply-config --insecure --nodes ${TALOS04IP} --file talos-04.yaml

And watch for the nodes to change state:

    kubectl get nodes --watch

Okay, that was phase one, now we have a working cluster!

Feel free to start over with

    terraform destroy


## Longhorn


patch the controlplane.yaml file to include the longhorn-system namespace. Create the following file longhorn-namespace.yaml:

    cluster:
        inlineManifests:
          - name: namespace-longhorn-system
            contents: |-
              apiVersion: v1
              kind: Namespace
              metadata:
                 name: longhorn-system

And apply it:

    talosctl machineconfig patch talos-01.yaml --patch @longhorn-namespace.yaml -o talos-01.yaml
    talosctl apply-config --nodes ${TALOS01IP} --endpoints ${TALOS01IP} --talosconfig=./talosconfig -f talos-01.yaml

Let's enable the longhorn storage mounts. Create a file longhorn-mount.yaml

    - op: add
      path: /machine/kubelet/extraMounts
      value:
        - destination: /var/lib/longhorn
          type: bind
          source: /var/lib/longhorn
          options:
            - bind
            - rshared
            - rw

And create a new machineconfig for the workers:

    talosctl machineconfig patch talos-02.yaml --patch @longhorn-mount.yaml -o talos-02.yaml
    talosctl apply-config --nodes ${TALOS02IP} --endpoints ${TALOS01IP} --talosconfig=./talosconfig -f talos-02.yaml
    talosctl machineconfig patch talos-03.yaml --patch @longhorn-mount.yaml -o talos-03.yaml
    talosctl apply-config --nodes ${TALOS03IP} --endpoints ${TALOS01IP} --talosconfig=./talosconfig -f talos-03.yaml
    talosctl machineconfig patch talos-04.yaml --patch @longhorn-mount.yaml -o talos-04.yaml
    talosctl apply-config --nodes ${TALOS04IP} --endpoints ${TALOS01IP} --talosconfig=./talosconfig -f talos-04.yaml

Apply the pod security policy

    talosctl machineconfig patch talos-01.yaml --patch '[{"op": "add", "path": "/cluster/apiServer/admissionControl/0/configuration/exemptions/namespaces/-", "value": "longhorn-system"}]' -o talos-01.yaml
    talosctl apply-config --nodes ${TALOS01IP} --endpoints ${TALOS01IP} --talosconfig=./talosconfig -f talos-01.yaml

And deploy longhorn:


    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.7.0/deploy/longhorn.yaml


Watch stuff happen:

    watch kubectl --namespace longhorn-system get pods

Now let's create the ingress. Create an auth file [source](https://longhorn.io/docs/1.7.0/deploy/accessing-the-ui/longhorn-ingress/)

    USER=user; PASSWORD=password; echo "${USER}:$(openssl passwd -stdin -apr1 <<< ${PASSWORD})" >> auth
    kubectl -n longhorn-system create secret generic basic-auth --from-file=auth

Create a file called `longhorn-ingress.yml`:

    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: longhorn-ingress
      namespace: longhorn-system
      annotations:
        # type of authentication
        nginx.ingress.kubernetes.io/auth-type: basic
        # prevent the controller from redirecting (308) to HTTPS
        nginx.ingress.kubernetes.io/ssl-redirect: 'false'
        # name of the secret that contains the user/password definitions
        nginx.ingress.kubernetes.io/auth-secret: basic-auth
        # message to display with an appropriate context why the authentication is required
        nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required '
        # custom max body size for file uploading like backing image uploading
        nginx.ingress.kubernetes.io/proxy-body-size: 10000m
    spec:
      rules:
      - http:
          paths:
          - pathType: Prefix
            path: "/"
            backend:
              service:
                name: longhorn-frontend
                port:
                  number: 80

and apply it:

    kubectl -n longhorn-system apply -f longhorn-ingress.yml


