Deployment and configuration scripts for the image processing pipeline application at https://github.com/HASTE-project/cellprofiler-pipeline.

This is a simple, distributed, image stream processing pipeline built around CellProfiler, as a case study demonstrating use of the HASTE Toolkit.
These deployment scripts configure/deploy the client and worker applications, as well as RabbitMQ and MongoDB to form the complete pipeline.

See:
```
Rapid development of cloud-native intelligent data pipelines for scientific data streams using the HASTE Toolkit. 
Blamey, Toor, Dahlö, Wieslander, Harrison, Sintorn, Sabirsh, Wählby, Spjuth, Hellander.
https://doi.org/10.1093/gigascience/giab018 Gigascience 10(3). 2021.
```


The pipeline is intended to be deployed into lab environments and process images as they are written to disk by a microscope. To reproduce the results in the paper, one simply copies the example dataset into the 'source' folder. The application will process all images in turn, queuing them as necessary, automatically scaling according to the workload.

# Contents

- [Deployment](#deployment)
  * [Prerequisites](#prerequisites)
  * [Storage](#storage)
  * [RabbitMQ](#rabbitmq)
    + [Set up PV/PVC for persistence for RabbitMQ](#set-up-pv-pvc-for-persistence-for-rabbitmq)
    + [RabbitMQ credentials](#rabbitmq-credentials)
    + [Set up RabbitMQ with helm](#set-up-rabbitmq-with-helm)
  * [Mongodb](#mongodb)
    + [Set up PV/PVC for persistence for mongodb](#set-up-pv-pvc-for-persistence-for-mongodb)
    + [Set up mongodb with helm](#set-up-mongodb-with-helm)
    + [Port forwarding for Mongo](#port-forwarding-for-mongo)
  * [Redeploying helm applications (RMQ, Mongo)](#redeploying-helm-applications--rmq--mongo-)
  * [Image Processing Client & Workers](#image-processing-client---workers)
    + [Scaling](#scaling)
- [Test-Running the Pipeline](#test-running-the-pipeline)
  * [Download the pipeline](#download-the-pipeline)
  * [Using the imageset used in the paper](#using-the-imageset-used-in-the-paper)
  * [Using the Broad Institute Dataset](#using-the-broad-institute-dataset)
- [Questions?](#questions?)
  


# Deployment

To reproduce the experimental results presented in the paper, it is first necessary to deploy the software pipeline to your cluster. The deployment scripts in this repository will need to be edited for your cluster, e.g. storage, user authentication and TCP ingress (for security), and scaling (depending on your available hardware). 

## Prerequisites

* These instructions assume that Kubernetes is installed on a remote machine/cluster (and that kubectl is configured correctly to access your cluster). It is possible to run Kubernetes locally using [MiniKube](https://minikube.sigs.k8s.io/docs/).
* The instructions assume an empty namespace `haste` is dedicated to running the pipeline.  


## Storage

We begin by configuring storage for the images. If you want to run the software with a microscope, this needs to be a directory where the microscope can write image files. If you simply wish to reproduce our results, it can simply be an empty directory. 

The persistent volume needs to be configured to match your storage: `mikro_testdata_pv.yaml`.
The persistent volume claim needs to be configured with the storage quota: `mikro_testdata_pvc.yaml`. 

Deploy Persistent Volume:
```
kubectl apply -f mikro_testdata_pv.yaml
```

Deploy Persistent Volume Claim: 
```
kubectl apply -f mikro_testdata_pvc.yaml
```

Later on, we'll download and extract the example image dataset here.

We deploy a single Ubuntu pod, we'll use this later to move files around and trigger the pipeline.
```
kubectl apply -f ubuntu-container.yaml
```

Test that the Ubuntu pod can access the storage (check the Kubernetes UI for the pod ID), with a remote shell:
```
kubectl exec --namespace haste -it 	test-mikro-datamount-77cbb9858-hcfkt bash

# install curl (needed to download datasets)
apt update
apt -y install curl
```

In our example, the storage is mounted under `/mnt/mikro-testdata`.

```
ls /mnt/mikro-testdata
```

## RabbitMQ

RabbitMQ is used to manage the image processing queue. (It is effectively a queue of filenames waiting to be processed, with some additional information).  

### Set up PV/PVC for persistence for RabbitMQ

RMQ requires persistent storage for its queue data. Run the following to set up the PV/PVC for RabbitMQ persistence. 
Again, this needs to be configured for your local storage.

`kubectl apply -f rabbitmq/haste-rabbitmq.yaml`

### RabbitMQ credentials

The RMQ web gui is useful for monitoring progress of the image processing queue, especially when processing large numbers of images. 

The credentials are created using two secrets; one for the admin user creation, and another for all other users. 
Because of the way the rabbitmq container is initialized, we have to create the admin user twice, once in each secret. 
A way to get around this would be to modify the docker image, but we will probably want to keep using the official image.

We create two users: a `guest` user, which our client and worker applications use to access the queue securely within the kubernetes cluster. The guest user doesn't have admin rights to login via the web mgmt GUI. The guest credentials match those defined in the client/worker deployment script -- guest/guest.   

We also create an administrative user 'hasterabbit' for use with the web GUI. This user needs an actual password, so then we can expose the RMQ web interface publicly. Edit the script `rmq_config.sh` changing both occurances `pass0` to your own secure password. 
 
Then run the deployment script to deploy the secrets:
```
cd rabbitmq
./rmq_config.sh
```

### Set up RabbitMQ with helm

Now to deploy RMQ itself. First, modify the ingress hostname in rabbitmq/values.yaml to match your own DNS records. Then deploy the chart. 

`helm del --purge haste-rabbitmq`
`helm install --name haste-rabbitmq --namespace haste -f rabbitmq/values.yaml stable/rabbitmq`

Any additional parameters can be configured with additional `--set <param>=<value>` entries, full list of parameters available at https://github.com/helm/charts/tree/master/stable/rabbitmq

A single RMQ pod will be sufficient, even for many thousands of images.

Now, it should be possible to log onto the RMQ web interface (the client application will create a queue for incoming images).

Or, start port-forwarding and log in with the adminstrative credentials you created earlier:
```
kubectl port-forward haste-rabbitmq-0 --namespace haste 15672:15672
```



## Mongodb

MongoDB is used by the HASTE Toolkit for recording metadata about processed data objects (in the case of this pipeline, images). 

### Set up PV/PVC for persistence for mongodb
Run the following to set up the PV/PVC for mongodb persistence (again, contextualizing for your deployment).

`kubectl apply -f mongodb/haste-state-mongodb.yaml`

### Set up mongodb with helm
To set up mongodb with helm chart, run following command from a point with access to Ola's kubernetes cluster and with the `values.yaml` file available:

```
helm install --name haste-mongodb --namespace haste -f mongodb/values.yaml stable/mongodb
```
-or upgrade existing-
```
helm upgrade --name haste-mongodb --namespace haste -f mongodb/values.yaml stable/mongodb
```
-or to delete-
```
helm delete --purge haste-mongodb
```

### Port forwarding for Mongo
It is useful to configure port forwarding from your local machine for accessing MongoDB, which will be populated with records of processed images. (We used [Robo 3T](https://robomongo.org/) during the initial development). 

Setup port forwarding for remote MongoDB access:
```
kubectl port-forward --namespace haste svc/haste-mongodb 27018:27017
```

A single RMQ pod will be sufficient, even for large numbers of concurrent workers.

## Redeploying helm applications (RMQ, Mongo) 
To redeploy, the current deployment must be deleted (see name above) before running `helm install` again:
 
`helm delete --purge <deployment name>` 

**NOTE**: `<deployment name>` must match the name of the deployed application. To list all helm deployments in haste:
```
$ helm list --namespace haste
NAME          	REVISION	UPDATED                 	STATUS  	CHART         	APP VERSION	NAMESPACE
haste-rabbitmq	1       	Fri May 17 18:07:15 2019	DEPLOYED	rabbitmq-5.5.1	3.7.14     	haste    
haste-mongodb 	1       	Mon May  6 09:42:40 2019	DEPLOYED	mongodb-5.6.1 	4.0.6      	haste  
```


## Image Processing Client & Workers

We are finally ready the deploy the HASTE client and workers!


`pipeline_client.yaml` needs to be configured with the path of the 'source' directory -- where the files arrive from the microscope, and the (internal) host name of the RMQ service.

`pipeline_worker.yaml` needs to be configured with the path of the CellProfiler pipeline file, and the output tier directory paths and thresholds. In the paper, the output tiers were simply directories on the NAS. In practice, these could be different local and remote storage platforms.  

Next, start the client and workers:
```
kubectl apply -f pipeline_client.yaml
kubectl apply -f pipeline_worker.yaml
```

**Note that to reproduce the experiment in the paper exactly, use v3 for the worker, and v1 for the cient, as configured.** 

(For development purposes, if we need to delete the deployment to fetch a fresh image:)
```
kubectl delete -n haste deployment pipeline-worker ; kubectl apply -f pipeline_worker.yaml
kubectl delete -n haste deployment pipeline-client ; kubectl apply -f pipeline_client.yaml
```

### Scaling
We only use a single instance of the client application. The worker can be scaled, by default a single pod will be deployed.

A busy worker pod will consume ~50% cpu -- so this auto-scaler will simply scale to the specified maximum whenever there are messages on the queue:
```
kubectl --namespace haste autoscale deployment pipeline-worker --cpu-percent=10 --min=1 --max=16
kubectl --namespace haste get hpa
```

To remove autoscaling:
```
kubectl --namespace haste delete horizontalpodautoscaler pipeline-worker 
```

If the Docker image has been updated, delete the deployment, and then start again:
```
kubectl --namespace haste delete deployment.apps/pipeline-worker ; kubectl apply -f pipeline_worker.yaml ; kubectl --namespace haste delete deployment.apps/pipeline-client ; kubectl apply -f pipeline_client.yaml 
```
(there is no nice way to force it to re-fetch this, see: 
https://github.com/kubernetes/kubernetes/issues/33664 )


# Test-Running the Pipeline

If everything is working correctly, the client application will be monitoring the source folder.
To test-run the pipeline, we simply copy in a set of images (such as those published with the paper).
We use the test container to copy files in/out of the volume.


## Download the pipeline

The CellProfiler pipeline to use needs to be available on storage accessible to the worker pod. 
To reproduce the results from the paper, download our .cppipe file from github:

```
cd /mnt/mikro-testdata
curl -o MeasureImageQuality-TestImages.cppipe https://raw.githubusercontent.com/HASTE-project/cellprofiler-pipeline/master/worker/dry-run/MeasureImageQuality-TestImages.cppipe
```

## Using the imageset used in the paper 

The imageset used for the paper was:
http://doi.org/10.17044/scilifelab.12811997.v1

Run these commands from inside the Ubuntu pod we created earlier.
```
cd /mnt/mikro-testdata
curl -L https://scilifelab.figshare.com/ndownloader/files/24271214 | tar -xz # w1
curl -L https://scilifelab.figshare.com/ndownloader/files/24271223 | tar -xz # w2
curl -L https://scilifelab.figshare.com/ndownloader/files/24271229 | tar -xz # w3
curl -L https://scilifelab.figshare.com/ndownloader/files/24271232 | tar -xz # w4
curl -L https://scilifelab.figshare.com/ndownloader/files/24271238 | tar -xz # w5
```

Copy files into source dir to test application (from inside the container)...
 ```
cd /mnt/mikro-testdata
mkdir ./source
find ./source/* -delete
find ./PolinaG-KO/181214-KOday7-40X-H2O2-Glu/2018-12-14/9 -name '*.tif' -exec cp -v '{}' ./source \;
```

Run with a single image for debugging...
```
cd /mnt/mikro-testdata
mkdir ./source
# use find, incase there are lots of files...
find ./source/* -delete
cp ./PolinaG-KO/181214-KOday7-40X-H2O2-Glu/2018-12-14/9/181214-KOday7-40X-H2O2-Glu_D09_s5_w4BC3DBE5C-C6C1-4AA5-A7BD-40D08C48EF76.tif ./source/
```

When processing is running, the progress is visible in the RMQ mgmt GUI:
![RMQ Mgmt GUI](./docs_rmq_mgmt.png) 

Records for processed images are written to MongoDB:
![RMQ Mgmt GUI](./docs_image_mongodb_record.png) 

In this configuration (used for the paper), images are moved to the 'target' directory, with files visible under the various tiers.

Output files are collated by HASTE Stream ID. A new stream ID is generated automatically when the 'client' application is (re)started.
 
To verify consistency with the classifications in the paper, count the number of output files in each tier:
(In this case, the auto-generate HASTE Stream ID was `2021_01_25__12_14_15_mikro-testdata-source`).

```
$ find /mnt/mikro-testdata/target/A/2021_01_25__12_14_15_mikro-testdata-source -name *.tif | wc -l
726
$ find /mnt/mikro-testdata/target/B/2021_01_25__12_14_15_mikro-testdata-source -name *.tif | wc -l
731
$ find /mnt/mikro-testdata/target/C/2021_01_25__12_14_15_mikro-testdata-source -name *.tif | wc -l
606
$ find /mnt/mikro-testdata/target/D/2021_01_25__12_14_15_mikro-testdata-source -name *.tif | wc -l
636
```

These should match the totals listed in the paper/shown above.


## Using the Broad Institute Dataset

Download the files:
```
for i in {00..33} ; do curl https://data.broadinstitute.org/bbbc/BBBC006/BBBC006_v1_images_z_${i}.zip -o BBBC006/BBBC006_v1_images_z_${i}.zip ; done
```

```
# run BBBC006
cd /mnt/mikro-testdata
mkdir ./source
# use find, incase there are lots of files...
find ./source/* -delete
find ./BBBC006 -name '*.tif' -exec cp '{}' ./source \;
```

# Questions?

We'd love to hear from you! ben.blamey@it.uu.se
