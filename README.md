### Technical task for pipedrive

#### Creating machines

For automating creation of the machines I'm using Terraform.
To run the automation you will need:
- Terraform
- AWS CLI
- AWS credentials for sufficient access rights.

Script creates a security group with all the needed rules, 3 VMs and hosts file for ansible.

To run:
- `terraform init`
- `terraform apply`

#### Elk stack

To set up the Elastic stack use the playbook `elk.yaml`.
Script expects dedicated VMs, selected in `hosts` file, one for kibana, one for logstash, one as a master node of elastic elasticsearch and two remaining as data nodes.

password and username for accessing kibana, port to open in logstash and connection port of elastic search are set in `./group_vars/all.yaml`

To run: `ansible-playbook elk.yaml`

#### Monitoring

For monitoring I'm using Grafana and prometheus.
Installing and configuring grafana and prometheus is  automated in the playbook `monitoring.yaml`.

prometheus user and password are setup in `./group_vars/all.yaml`

configuring data source in grafana and creating a dashboard is not automated. Manual steps are as follows:

log into newly installed grafana and add new data source url will be:
- When using TLS and DNS: `https://pd-task.xyz:80/prometheus`
- With DNS and no TLS: `http://pd-task.xyz/prometheus`
- If neither DNS and nor TLS are enabled: `http://<public ip of prometheus machine>/prometheus`

use basic auth function with username and password of prometheus

Grafana will run tests and show if the data source works. Once data source is up it's time to configure dashboard, for this you can either use `grafana.json` or prometheus queries

- `avg (irate(process_cpu_seconds_total{job="node", instance="<private ip of instance>:9100"}[1m]))`

To visualize this one, create new grafana dashboard, add new panel and in new panel visualization option  use graph

- `(node_filesystem_free_bytes{job="node", instance="<private ip of instance>:9100"})`

to visualize this one use stat option, in field tab of panel options, go to standard options select unit `bytes(IEC)` or `bytes(SI)`, scroll lower and adjust threshold, base selects color from 0-first threshold, first threshold color0 will be used otherwise. If a second threshold exists, it will be used from first to second, etc.

Save dashboard

#### TLS

Ansible script that sets up TLS uses let's encrypt which needs domain name, variables including the domain name need to be set up in `./group_vars/all.yaml`

script uses nginx and recreates nginx config for this exact infrastructure.

Mapping of https is done to http port (80) as per request, so to access site from browser use https://pd-task.xyz:80 so for example pd-task.xyz/prometheus becomes https://pd-task.xyz:80/prometheus
