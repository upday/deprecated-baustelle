branch = "master"
deploy_timeout = 30
region = "eu-west-1"
eb_application_name = "PabloContentMachine"
application_environment_name = "staging-40dd648e7c"
environment_name = application_environment_name.split('-')[0]
application_identifier = application_environment_name.split('-')[1]
eb_application_version_source = "git"


def create_file = { path, content -> "echo \"${content}\" > ${path}"}

ebcli = "docker run --rm=true -v \$WORKSPACE/_output:/app sevos/awsebcli"
def eb_status = {
    "\$($ebcli status staging-40dd648e7c --region eu-west-1 | grep '$it' | awk '{{print \$2}}')"
}



def ebconfig_cmd = {
	application_environment_name, output_file -> "docker run --rm sevos/awsebenvconfig $region $eb_application_name $application_environment_name | grep -v M2 | grep -v JAVA_HOME | tee $output_file"
}

wait_for_environment = """
set -e -o pipefail

echo \"Waiting for the environment to be ready...\"
while [[ \"${eb_status("Status")}\" != \"Ready\" ]]; do
  sleep 5
done
"""

assert_healthy_environment = """
if [[ \"${eb_status('Health')}\" == \"Green\" ]]; then
  exit 0
else
  exit 1
fi
"""


java_config_yml = '''---
packages:
  yum:
    git: []
'''

config_yml = '''---
global:
  application_name: PabloContentMachine
  default_region: eu-west-1
  profile: null
  sc: null
'''

path_to_artifact = "yana-contentmachine-api/target/contentmachine.jar"
artifact_name = "contentmachine.jar"
maven_goals_options = 'clean org.jacoco:jacoco-maven-plugin:prepare-agent deploy -Pit'
maven_settings_id = "org.jenkinsci.plugins.configfiles.maven.GlobalMavenSettingsConfig1422533819776"


job('00-deploy') {
    logRotator { numToKeep(5) }
    scm {
        git {
            remote {
                url ("git@github.com:as-ideas/yana-contentmachine.git")
                branch "master"
                credentials("aa51055b-a9ad-48b2-974c-e1f4ab328fa4")
            }
            clean true
        }
    }

    steps {
        shell("mkdir -p _output/.ebextensions")
        shell("mkdir -p _output/.elasticbeanstalk")
        shell(create_file("_output/.ebextensions/java.config", java_config_yml))
        shell(create_file("_output/.elasticbeanstalk/config.yml", config_yml))
        shell(wait_for_environment)
        if (eb_application_version_source.equals('git')) {
            maven {
                goals maven_goals_options
            }
            shell("cp $path_to_artifact _output/$artifact_name")
            shell(create_file("_output/Procfile", "web: java -Dserver.port=5000 -jar $artifact_name"))
            shell("$ebcli deploy staging-40dd648e7c --region eu-west-1 -l \$(git rev-parse HEAD) -m \"\$(git log -1 --pretty=%B)\" --timeout $deploy_timeout")

        } else {
            shell("""
DEPLOYED_VERSION=\$($ebcli status $eb_application_version_source-$application_identifier | grep \"Deployed Version:\" | sed \"s/.*Deployed Version://\")
$ebcli deploy staging-40dd648e7c --region eu-west-1 --version \$DEPLOYED_VERSION --timeout $deploy_timeout
""")
        }
        shell(wait_for_environment)
        shell(assert_healthy_environment)
    }

    configure {
        project ->
            project.remove(project / scm / branches)
            project / scm / branches / 'hudson.plugins.git.BranchSpec' {
                name "master"
            }
            project / publishers / 'hudson.plugins.sonar.SonarPublisher'(plugin:"sonar@2.2") {
                jdk "jdk8"
                branch ''
                mavenOpts ''
                rootPom ''
                jobAdditionalProperties
                settings(class:"jenkins.mvn.DefaultSettingsProvider")
                globalSettings(class:"org.jenkinsci.plugins.configfiles.maven.job.MvnGlobalSettingsProvider", plugin:"config-file-provider@2.7.5") {
                    settingsConfigId maven_settings_id
                }
                usePrivateRepository false
                jobAdditionalProperties ''
            }
    }
}


job("10-systemtests") {
    environment_file = 'environment'
    logRotator { numToKeep(5) }

    triggers {
        
    }

    scm {
        git {
            remote {
                url("git@github.com:as-ideas/yana-contentmachine-systemtests.git")
                credentials("aa51055b-a9ad-48b2-974c-e1f4ab328fa4")
                branch "**/DO-119"
            }
        }
    }

    steps {
        shell (ebconfig_cmd(application_environment_name,environment_file))
        environmentVariables {
            propertiesFile (environment_file)
        }
        maven {
            goals "clean verify -Psystem-tests"
        }
    }
}


// job("monitor-health") {
//     logRotator { numToKeep(5) }
//
//     parameters {
//         stringParam("ENDPOINT", "pablo-eu-west-1-staging-content-machine.elasticbeanstalk.com")
//         stringParam("ENDPOINT_PATH", "/health")
//         stringParam("TIME", "10", "Time for the test in seconds")
//         stringParam("FREQUENCY", "4", "How many tests per second")
//         stringParam("THREADS", "1", "How many concurrent threads (multiplies frequency)")
//     }
//     scm {
//         git {
//             remote {
//                 url("git@github.com:as-ideas/yana-deployment.git")
//                 credentials("aa51055b-a9ad-48b2-974c-e1f4ab328fa4")
//                 branch "**/master"
//             }
//             clean(true)
//         }
//     }
//
//     steps {
//         shell("docker run -v \$WORKSPACE:/scripts -v \$WORKSPACE:/logs -v \$WORKSPACE:/input_data nate9/jmeter -n -t /scripts/jobs/monitor_health.jmx -Jhost=\$ENDPOINT -Jtime=\$TIME -Jfrequency=\$FREQUENCY -Jpath=\$ENDPOINT_PATH -Jthreads=\$THREADS")
//
//         shell("""
// SUCCESS=\$(cat \$WORKSPACE/result.csv | (grep \"200,OK\" || true) | wc -l)
// TOTAL=\$(cat \$WORKSPACE/result.csv | wc -l)
// echo "Successful requests: \$SUCCESS"
// echo "Total requests: \$TOTAL"
// [ \$SUCCESS -eq \$TOTAL ] && exit 0 || exit 1
// """)
//     }
// }
