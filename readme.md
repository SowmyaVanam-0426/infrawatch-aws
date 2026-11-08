# InfraWatch for a webapplication– AWS Infrastructure Provisioning & Performance Engineering

## Overview

InfraWatch is an AWS infrastructure project built using Terraform to provision, deploy and test a web application in a load-balanced environment.

The infrastructure is provisioned as code rather than created manually through the AWS Console. Two EC2 instances host a Flask application behind an internet-facing Application Load Balancer.

The objective is to understand infrastructure provisioning, traffic distribution, application performance to simulate a production like environment.

## Why InfraWatch?

Provisioning infrastructure is only the starting point. In a production environment, infrastructure must handle changing traffic, unhealthy instances, resource constraints and application failures  and we are going to see that in real time.

This project focuses on:

- Automating AWS infrastructure provisioning using Terraform.
- Building a network architecture with VPCs, subnets and security groups.
- Distributing application traffic across multiple EC2 instances.
- Generating load and observing application behaviour.
- Identifying infrastructure and application bottlenecks.
- Implementing monitoring to monitor the instances and it's performance- how traffic effects the instances in real time

## Technology Stack

| Infrastructure as Code | Terraform |
| Cloud Provider | AWS |
| Networking | VPC, Subnets, Route Tables, Internet Gateway |
| Compute | EC2 |
| Load Balancing | Application Load Balancer |
| Security | AWS Security Groups |
| Operating System | Ubuntu Linux |
| Application | Python, Flask, Gunicorn |
| Load Testing | k6 |
| Monitoring | Amazon CloudWatch |

## Infrastructure Provisioning – Terraform

Terraform is used to provision and manage the AWS infrastructure. Once the main.tf is configure you can validate and apply the terraform

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

## Application Deployment

A Flask application is deployed on both EC2 instances.

Gunicorn runs the application as a systemd service.

The application includes endpoints for:

| Endpoint | Purpose |
|---|---|
| `/` | Application status and instance identity |
| `/health` | ALB health check |
| `/api/products` | Sample application response |
| `/api/slow` | Simulates application latency |
| `/api/heavy` | CPU-intensive workload |

Each EC2 instance returns its own server identity, making it possible to verify that the ALB distributes incoming requests across both instances.

## Load Testing – Planned

Use k6 to generate concurrent HTTP traffic against the ALB.


```bash
k6 run loadtest.js
```

Planned scenarios:

/home/lenovo/DevOps _Project/Infra_Project1/images/traffic.png

| Scenario | Virtual Users | Duration |
|---|---:|---:|
| Baseline | 10 | 1 min |
| Moderate | 50 | 2 min |
| High | 100 | 2 min |
| Spike | 200 | 1 min |

Evaluate throughput, response time, error rates and resource utilization.

## Monitoring & Troubleshooting – Planned

CloudWatch will be used to observe infrastructure behaviour during load tests.

**EC2 metrics**
- CPU Utilization
- Network In/Out
- Instance Status Checks
- Memory and Disk Utilization through CloudWatch Agent

**ALB metrics**
- Request Count
- Target Response Time
- HTTP 5XX Errors
- Healthy and Unhealthy Host Count


## Cleanup

Destroy the provisioned infrastructure when testing is complete.

```bash
terraform destroy
```

Review the Terraform plan before confirming deletion.
