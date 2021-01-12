Deployment and configuration scripts for the image processing pipeline application at https://github.com/HASTE-project/cellprofiler-pipeline.

This is a simple, distributed, image stream processing pipeline built around CellProfiler, as a case study demonstrating use of the HASTE Toolkit.
These deployment scripts configure/deploy the client and worker applications, as well as RabbitMQ and MongoDB to form the complete pipeline.

See:
```
"Rapid development of cloud-native intelligent data pipelines for scientific data streams using the HASTE Toolkit"
https://www.biorxiv.org/content/10.1101/2020.09.13.274779v1
```

# Deployment

Persistent Volume:
```
kubectl apply -f mikro_testdata_pv.yaml
```

Persistent Volume Claim: 
```
kubectl apply -f mikro_testdata_pvc.yaml
```

I also created this dummy-ubuntu-container:
(a simple dummy ubuntu container executing a loop) 
```
kubectl apply -f dummy-ubuntu-container.yaml
```
 
You can execute into it with:
```
kubectl exec --namespace haste -it test-mikro-datamount-77cbb9858-h756d bash
kubectl exec --namespace haste -it pipeline-client-869546b6bb-qsj6m bash
	
kubectl exec --namespace haste -it pipeline-worker-98799dbbc-d2qv4 bash
kubectl exec --namespace haste -it test-mikro-datamount bash
```

## Image Processing Client & Workers

Start the client and workers:
```
kubectl apply -f pipeline_client.yaml

# need to delete the deployment to fetch the fresh docker image
kubectl delete -n haste deployment pipeline-worker ; kubectl apply -f pipeline_worker.yaml
```

```
# scaling - a busy worker pod will consume ~50% cpu -- so this auto-scaler will simply scale to the max whenever there are messages on the Q.
kubectl --namespace haste autoscale deployment pipeline-worker --cpu-percent=10 --min=1 --max=18

kubectl --namespace haste get hpa
kubectl --namespace haste delete horizontalpodautoscaler pipeline-worker 
```

If the Docker image has been updated, delete the deployment, and then start again:
```
kubectl --namespace haste delete deployment.apps/pipeline-worker ; kubectl apply -f pipeline_worker.yaml ; kubectl --namespace haste delete deployment.apps/pipeline-client ; kubectl apply -f pipeline_client.yaml 
```
(there is no nice way to force it to re-fetch this, see: 
https://github.com/kubernetes/kubernetes/issues/33664 )


# Set up mongodb
## Set up PV/PVC for persistence for mongodb
Run the following to set up the PV/PVC for mongodb persistence

`kubectl apply -f mongodb/haste-state-mongodb.yaml`

## Set up mongodb with helm
To set up mongodb with helm chart, run following command from a point with access to Ola's kubernetes cluster and with the `values.yaml` file available:

`helm install --name haste-mongodb --namespace haste -f mongodb/values.yaml stable/mongodb`
-or-
`helm upgrade --name haste-mongodb --namespace haste -f mongodb/values.yaml stable/mongodb`

Can see an issue in the logs on startup..
"mongodb INFO ==> No injected configuration files found. Creating default config files..."
Cause is unknown. With this error, clients are not able to connect.

`helm delete --purge haste-mongodb`

Any additional parameters can be configured with additional `--set <param>=<value>` entries, full list of parameters available at https://github.com/helm/charts/tree/master/stable/mongodb

## Set up RabbitMQ
### Set up PV/PVC for persistence for RabbitMQ
Run the following to set up the PV/PVC for RabbitMQ persistence

`kubectl apply -f rabbitmq/haste-rabbitmq.yaml`

### Set up RabbitMQ with helm
First, you have to create the user credentials for the rabbitmq server. These will be used by scripts to access the mq. 
The credentials are created using two secrets; one for the admin user creation, and another for all other users. 
Because of the way the rabbitmq container is initialized, we have to create the admin user twice, once in each secret. 
A way to get around this would be to modifiy the docker image, but we will probably want to keep using the official image.

Note: the administrative password needs to be changed to something random.
The guest credentials match those defined in the client/worker -- guest/guest.
The guest user doesn't have admin rights to login via the web mgmt GUI.

To set up RabbitMQ with helm chart, run following command from a point with access to Ola's kubernetes cluster and with the `values.yaml` file available:

`helm del --purge haste-rabbitmq`
`helm install --name haste-rabbitmq --namespace haste -f rabbitmq/values.yaml stable/rabbitmq`

Any additional parameters can be configured with additional `--set <param>=<value>` entries, full list of parameters available at https://github.com/helm/charts/tree/master/stable/rabbitmq

Redeploying helm applications
To redeploy, the current deployment must be deleted (see name above) before running `helm install` again:
 
`helm delete --purge <deployment name>` 

**NOTE**: `<deployment name>` must match the name of the deployed application. To list all helm deployments in haste:
```
$ helm list --namespace haste
NAME          	REVISION	UPDATED                 	STATUS  	CHART         	APP VERSION	NAMESPACE
haste-rabbitmq	1       	Fri May 17 18:07:15 2019	DEPLOYED	rabbitmq-5.5.1	3.7.14     	haste    
haste-mongodb 	1       	Mon May  6 09:42:40 2019	DEPLOYED	mongodb-5.6.1 	4.0.6      	haste  
```

Setup port forwarding for remote MongoDB access:
```
kubectl port-forward --namespace haste svc/haste-mongodb 27018:27017
```

# Test-Running the Pipeline

If everything is working correctly, the client application will be monitoring the source folder.
To test-run the pipeline, we simply copy in a set of images (such as those published with the paper)

TODO: this needs a cleanup.... 

## Copy files for testing 

Use the test container to copy files in/out of the volume:

Copy files out (ie. to the laptop)
```
kubectl cp haste/test-mikro-datamount-77cbb9858-
kubectl exec --namespace haste -it test-mikro-datamount-77cbb9858-sgx4h -- /bin/bash:/mnt/mikro-testdata/PolinaG-KO/ .
kubectl cp haste/test-mikro-datamount-77cbb9858-sgx4h:/mnt/mikro-testdata/PolinaG-KO/181214-KOday7-40X-H2O2-Glu/2018-12-14/list.txt list.txt

kubectl cp haste/test-mikro-datamount-77cbb9858-h756d:/mnt/mikro-testdata/PolinaG-KO/181214-KOday7-40X-H2O2-Glu/2018-12-14/9/181214-KOday7-40X-H2O2-Glu_G09_s4_w1B81A283D-D081-4EFE-9118-4E911ED18AA8.tif 181214-KOday7-40X-H2O2-Glu_G09_s4_w1B81A283D-D081-4EFE-9118-4E911ED18AA8.tif



cat ../../../list.txt | xargs -t -R 2 -I@ bash -c "echo kubectl cp haste/test-mikro-datamount-77cbb9858-sgx4h:/mnt/mikro-testdata/PolinaG-KO/181214-KOday7-40X-H2O2-Glu/2018-12-14/@ @"
cat ../../../list.txt | xargs -t -s 4000 -I@ bash -c "echo kubectl cp haste/test-mikro-datamount-77cbb9858-sgx4h:/mnt/mikro-testdata/PolinaG-KO/181214-KOday7-40X-H2O2-Glu/2018-12-14/@ @"
cat ../../../list.txt | xargs -t -J@ bash -c "echo kubectl cp haste/test-mikro-datamount-77cbb9858-sgx4h:/mnt/mikro-testdata/PolinaG-KO/181214-KOday7-40X-H2O2-Glu/2018-12-14/@ @"
cat ../../../list.txt | xargs -I@ bash -c "echo kubectl cp @ @"


```
Copy files in (from the laptop), e.g.:
```
kubectl cp foo haste/test-mikro-datamount-6c59856b87-6k2bj:/mnt/mikro-testdata
kubectl cp /Users/benblamey/projects/haste/cell-profiler-work/OutOfFocus-TestImages.cppipe haste/test-mikro-datamount-6c59856b87-6k2bj:/mnt/mikro-testdata
kubectl cp /Users/benblamey/projects/haste/haste-image-analysis-spjuth-lab/worker/dry-run/MeasureImageQuality-TestImages.cppipe haste/test-mikro-datamount-6c59856b87-6k2bj:/mnt/mikro-testdata

kubectl --namespace haste cp /Users/benblamey/projects/haste/images/BBBC021_v1/BBBC021_v1_images_Week1_22123.zip test-mikro-datamount-5bdcd6d4f-p5vrh:/mnt/mikro-testdata/BBC021_v1


kubectl cp haste/test-mikro-datamount-77cbb9858-h756d:/mnt/mikro-testdata/PolinaG-KO/181214-KOday7-40X-H2O2-Glu/2018-12-14/9/*.tif /Users/benblamey/projects/haste/images/PolinaG-KO/181214-KOday7-40X-H2O2-Glu/2018-12-14/9 
```

Copy files into source dir to test application (from inside the container)
```
cd /mnt/mikro-testdata 
rm ./source/*
mkdir ./source
cp -v PolinaG-KO/181214-KOday7-40X-H2O2-Glu/2018-12-14/9/*.tif ./source/
```

```
cd /mnt/mikro-testdata
rm ./source/* 
cp -v ./BBBC021_v1/Week1_22123/*.tif ./source/
```


```
cd /mnt/mikro-testdata
rm ./source/* 
cp -v ./BBBC021_v1/Week1_22123/*.tif ./source/
```



```
cd /mnt/mikro-testdata
rm ./source/* 
cp -v ./azn/azn/*.tif ./source/
```


Some other snippets to fetch datasets / kickoff the pipeline... 
```
for i in {00..33} ; do wget https://data.broadinstitute.org/bbbc/BBBC006/BBBC006_v1_images_z_${i}.zip ; done
```

```
# run BBBC006
cd /mnt/mikro-testdata
mkdir ./source
# use find, incase there are lots of files...
find ./source/* -delete
find ./BBBC006 -name '*.tif' -exec cp '{}' ./source \;
```

```
# run Polina
cd /mnt/mikro-testdata
mkdir ./source
# use find, incase there are lots of files...
find ./source/* -delete
find ./PolinaG-KO/181214-KOday7-40X-H2O2-Glu/2018-12-14/9 -name '*.tif' -exec cp -v '{}' ./source \;
```

```
# run Polina Single Image
cd /mnt/mikro-testdata
mkdir ./source
# use find, incase there are lots of files...
find ./source/* -delete
cp ./PolinaG-KO/181214-KOday7-40X-H2O2-Glu/2018-12-14/9/181214-KOday7-40X-H2O2-Glu_D09_s5_w4BC3DBE5C-C6C1-4AA5-A7BD-40D08C48EF76.tif ./source/
```


kubectl cp haste/test-mikro-datamount-77cbb9858-h756d:/mnt/mikro-testdata/BBBC006/filelist.txt
 
cat list.txt | while read line; do echo $line; kubectl cp haste/test-mikro-datamount-77cbb9858-h756d:/mnt/mikro-testdata/PolinaG-KO/181214-KOday7-40X-H2O2-Glu/2018-12-14/9/$line $line; done
cat list.txt | while read line; do echo $line; done

## Other useful kubectl snippets 

Get all running pods:
```
kubectl --namespace haste get pods
```

Checking resource usage/namespace quotas/default resource specs:
```
kubectl describe resourcequotas -n haste

kubectl describe limitranges -n haste
```