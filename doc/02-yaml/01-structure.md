# General structure

<%= breadcrumbs %>

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

This secrion lists possible resources, other than another application, which
the applications deployed to the infrastructure stack can depend on. There
are multiple backends supported by baustelle, like RabbitMQ or Redis.
If given backend type is not supported by baustelle, there is always possibility
to declare an external backend, so all dependencies are managed in the same way.

Every environment is provisioned with own copy of every backend, so there is no
need to declare separate backends for staging and production. In case of natively
supported backends, there is still possibility to deploy multiple backends of
the same type in every environment, if your business logic requires that, i.e.
to separate a job queue Redis cluster from cache Redis cluster you would declare
the following:

``` yaml
backends:
  Redis:
    cache:
      cache_node_type: cache.m1.medium
      cluster_size: 1
    queue:
      cache_node_type: cache.m1.medium
      cluster_size: 1
```

The code above would deploy two Redis clusters **in every environment**. In configuration
it would be possible to access them using following references:

``` yaml
CACHE_REDIS_URL: backend(Redis:cache:url)
QUEUE_REDIS_URL: backend(Redis:queue:url)
```

Two environment variables with the URLs would be exposed to the application.

For details please refer to <%= link_to '02-yaml', '02-applications' %> and
[TODO: link to backend outputs definitions]

## applications

## environments
