# General structure

The YAML file is a central point of the infrastructure declaration. It defines
all environments, applications, resources and dependencies between them.
The declaration is the source to produce CloudFormation templates used to
build the infrastructure stack and also to provision selected Jenkins server
with automatically generated jobs managing deployments and other common tasks.

## base_amis

This section is used by `baustelle ami` subcommand. It declares named images used in
the stack and describes what AWS AMIs should be used as a base, how to connect to these
base AMIs. More info [TODO LINK]

## stacks

This section is used to define the environment of an application deployed in
ElasticBeanstalk. Every stack consists of a reference to an AWS Solution Stack Name
and an optional custom AMI (these AMIs should be built on top of ElasticBeanstalk
base AMIs for given Solution Stack). More info on customizing ElasticBeanstalk AMIs
[TODO LINK]. More info on Solution Stacks [TODO LINK AWS Docs].

## vpc

Here the basic configuration of the infrastructure stack VPC is defined:

* VPC network address
* subnets and availablity zones
* peering connections to other VPCs

## jenkins

This section contains configuration used when provisioning a Jenkins server
with generated jobs. It provides login credentials and specific plugin parameters.

## backends

## applications

## environments
