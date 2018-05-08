def scopes = ['factory', 'prod']
def jobNames=[]
def jobSuffix='jenkins-deploy'
scopes.each { scope ->
  jobNames.add("${scope}-${jobSuffix}")
  pipelineJob("${scope}-${jobSuffix}") {
    description("Dynamically generated with job-dsl by $JOB_NAME\nAny changes to this item will be overwritten without notice.")
    def repo = 'https://github.com/alexandruast/platform-inception'
    keepDependencies(false)
    parameters {
      nonStoredPasswordParam('JENKINS_ADMIN_PASS', "Password for ${scope} Jenkins admin user")
      stringParam('ANSIBLE_TARGET', "user@192.0.2.255", "Which target to use")
      choiceParam('JENKINS_SCOPE', ["$scope"], "Running in $scope scope only!")
      stringParam('ANSIBLE_EXTRAVARS', "{'foo':'bar'}", "Optional: use extravars(single line JSON string only!)")
    }
    definition {
      cpsScm {
        scm {
          git {
            remote { url(repo) }
            branches('master')
            scriptPath("origin/jobs/scm/pipeline-jenkins-deploy.groovy")
            extensions {
              cleanBeforeCheckout()
            }
            lightweight(true)
          }
        }
      }
    }
  }
}

listView('Jenkins-Deploy') {
  description("Dynamically generated with job-dsl by $JOB_NAME\nAny changes to this item will be overwritten without notice.")
  filterBuildQueue()
  filterExecutors()
  jobs {
    jobNames.each { jobName ->
      name(jobName)
    }
  }
  columns {
    status()
    weather()
    name()
    lastSuccess()
    lastFailure()
    lastDuration()
    buildButton()
  }
}