def scopes = ['factory', 'prod']
def jobSuffix='provision'
def jobPrefix='jenkins'
scopes.each { scope ->
  pipelineJob("${jobPrefix}-${scope}-${jobSuffix}") {
    description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
    def repo = 'https://github.com/alexandruast/platform-inception'
    keepDependencies(false)
    parameters {
      nonStoredPasswordParam('JENKINS_ADMIN_PASS', "Password for ${scope} Jenkins admin user")
      stringParam('ANSIBLE_TARGET', "192.0.2.255", "Target to use")
      choiceParam('JENKINS_SCOPE', ["$scope"], "Running in scope")
      stringParam('ANSIBLE_EXTRAVARS', "{'ansible_user':'ec2-user'}", "Optional: JSON format single line, single quoutes")
    }
    definition {
      cpsScm {
        scm {
          git {
            remote { url(repo) }
            branches('master')
            scriptPath("origin/jobs/scm/jenkins-provision-pipeline.groovy")
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
