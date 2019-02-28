# Set up mongodb with helm

To set up mongodb with helm chart, run following command from a point with access to Ola's kubernetes cluster and with the `values.yaml` file available:

`helm install --name mongodb --namespace haste -f values.yaml --set persistence.size=30Gi --set usePassword=false stable/mongodb`

Any additional parameters can be configured with additional `--set <param>=<value>` entries, full list of parameters available at https://github.com/helm/charts/tree/master/stable/mongodb

To redeploy, the current helm deployment must be deleted before running `helm install` again:

`helm delete --purge <name of installment, mongodb above>` 
