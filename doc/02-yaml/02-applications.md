# Applications

<%= breadcrumbs %>

Your application must listen on port 5000 in order to receive requests. You can either
hard-code this in your application configuration or set an environment variable
(see `SERVER_PORT: 5000` in the example below) which will be passed to your applicaiton
process on startup.

Example:
```
applications:
  user_profile_service:
    git:
      repo: git@github.com:upday/user-profile-svc.git
      branch: master
    stack: java-8
    maven:
      path_to_artifact: target/upday-user-profile-svc.jar
      goals_options: clean org.jacoco:jacoco-maven-plugin:prepare-agent deploy
    instance_type: t2.micro
    scale:
      min: 2
      max: 3
    elb:
      visibility: external
      https: true
      ssl_certificate: arn:aws:iam::123456789012:server-certificate/baustelle_com
      ssl_reference_policy: ELBSecurityPolicy-2015-05
    hostname_scheme: old
    dns:
      name: user-profile-service.baustelle.org
      hosted_zone: baustelle.org.
    config:
      SERVER_PORT: 5000
      MY_CUSTOM_ENV_VAR_PASSED_TO_APPLICATION: foo
    systemtests:
      git:
        repo: git@github.com:upday/contentmachine-systemtests.git
        branch: **/DO-127
      maven:
        goals_options: clean verify -Psystem-tests
      config_from_application_whitelist:
      - MY_CUSTOM_ENV_VAR_PASSED_TO_APPLICATION
    iam_instance_profile:
      kinesis:
        action:
          - kinesis:DescribeStream
          - kinesis:ListStreams
          - kinesis:GetShardIterator
          - kinesis:GetRecords
        resource: backend(Kinesis:user_events:arn)


  another_application:
    git:
        repo: (...)
    (...)
```


## Properties:

#### `applications.<app_name>.git.repo`
URL to the git repository to check out in jenkins jobs
* required

#### `applications.<app_name>.git.branch`
The branch of the git repo to check out in jenkins jobs
* default="master"

#### `applications.<app_name>.stack`
The stack to use (e.g. java-8, ruby-2.2, ...), must match with `stacks.<stack_name>`
* required

#### `applications.<app_name>.maven.path_to_artifact`
The path to the java artifact to deploy relative to the jenkins job's workspace
* required for java-\* stack

#### `applications.<app_name>.maven.goals_options`
The maven goals options used in the jenkins job
* default="clean org.jacoco:jacoco-maven-plugin:prepare-agent deploy"

#### `applications.<app_name>.instance_type`
The AWS instance type that will be used for this application
* required

#### `applications.<app_name>.scale.min`
The minimum number of instances of this application that always need to be running (AWS autoscaling)
* required

#### `applications.<app_name>.scale.max`
The maximum number of instances of this application that can be running (AWS autoscaling)
* required

#### `applications.<app_name>.elb.visibility`
Wether the elastic loadbalancer should be public facing (public ip address) or internal only
* required, possible values: `"internal", "external"`

#### `applications.<app_name>.elb.https`
When `true`, the elastic loadbalancer listens on port 443 (HTTPS), when `false`, it listens on port 80 (HTTP).
When `true`, you must specify `applications.<app_name>.elb.ssl_certificate` and `applications.<app_name>.elb.ssl_reference_policy`.
* required, possible values: `true, false`

#### `applications.<app_name>.elb.ssl_certificate`
The AWS ARN of the ssl certificate to use for HTTPS.
* required when `applications.<app_name>.elb.https=true`

#### `applications.<app_name>.elb.ssl_reference_policy`
The AWS SSL reference policy to use. This only configures the SSL ciphers in the loadbalancer that are safe to use.
AWS creates new updated policies regularily, so always try to keep this value to the most recent policy available.
* required when `applications.<app_name>.elb.https=true`

#### `applications.<app_name>.hostname_scheme`
AWS changed the hostname scheme of elasticbeanstalk applications. Old applications that were created before a certain date have the scheme
`<cname>.elasticbeanstalk.com` and new applications have the scheme `<cname>.<region>.elasticbeanstalk.com`. In order to inject the right
application URL when using application references, we must tell baustelle which hostname scheme the application uses. For new applications
you do not need to worry and skip this option. For applications that still use the old scheme, set this to `old`.
* optional, possible values: (`old`, `new`), defaults to `new`

#### `applications.<app_name>.dns.name`
An optional dns name that will point to the loadbalancer of the application. If not given, the application can still be reached
via the `elasticbeanstalk.com` domain.
* optional

#### `applications.<app_name>.dns.hosted_zone`
The AWS hosted zone name where the domain `applications.<app_name>.dns.name` should be created in (must end with a period).
* required when `applications.<app_name>.dns.name` is given

#### `applications.<app_name>.config.<env_var_name>`
Environment variable passed to the application process. In the example above, 2 environment variables will be created:
`SERVER_PORT=5000` and `MY_CUSTOM_ENV_VAR_PASSED_TO_APPLICATION=foo`

#### `applications.<app_name>.systemtests`
The systemtests definition for this application.
Allowed values:
- `false` or no value: disable the systemtests for this application.
- String: Name of the application which's systemtests will be executed
- Hash: configuration of the systemtests

### `applications.<app_name>.systemtests.git.repo`
URL to git repository of the systemtests.
* required

### `applications.<app_name>.systemtests.git.branch`
The branch which will be used by the systemtests.
* required

### `applications.<app_name>.systemtests.maven.goals_options`
The maven goals and options to use for the systemtests job. Basically the string following `mvn`
* required for java applications

### `applications.<app_name>.systemtests.command`
The command to execute the systemtests
* required for ruby applications

### `applications.<app_name>.systemtests.config_from_application_whitelist`
The application has certain environment variables passed to it (those from `applications.<app_name>.config.`).
With this option, you can define which of those environment variables should also be passed to the systemtest process.
Additionally to that list, APPLICATION_URL and HOST (deprecated) are also added to the systemtest process. The value
of those 2 variables is the base URL to the application (e.g. HOST=http://baustelle-eu-west-1-staging-my-app.elasticbeanstalk.com)
* optional. Default is an empty list

### `applications.<app_name>.iam_instance_profile`
Defines a list of policy statements which should be applied on the custom IAM Role assigned
to the application. These statements will be appended to the default set defined by baustelle.

### `applications.<app_name>.iam_instance_profile.<statement_name>`
A label of a given custom statement. `iam_instance_profile` key defines a dictionary
(not a list) just in order to make overriding configurations per-environment possible.

### `applications.<app_name>.iam_instance_profile.<statement_name>.action`
Name (or list of names) of AWS API action, which an application instance will be allowed
to perform
* required

### `applications.<app_name>.iam_instance_profile.<statement_name>.effect`
"Allow" or "Deny". "Allow" by default

### `applications.<app_name>.iam_instance_profile.<statement_name>.resource`
ARN, ARN pattern or a list of ARNs or patterns. Resources concerned by given policy
statement. "*" by default.
It is possible to reference a backend's ARN from here (look at the example on top).
In this case baustelle will take care of replacing the reference with an ARN
for every environment.
Note that if the specific ARN is given here, it is possible to override it on
per-environment basis.
