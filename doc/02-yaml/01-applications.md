# Applications

Example:
```
applications:
  user_profile_service:
    git:
      repo: git@github.com:as-ideas/user-profile-svc.git
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
    config:
      MY_CUSTOM_ENV_VAR_PASSED_TO_APPLICATION: foo

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
