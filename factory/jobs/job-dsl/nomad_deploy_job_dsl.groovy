def scopes = ['server', 'compute']
def jobPrefix='infra-generic-nomad'
def jobSuffix='deploy'
scopes.each { scope ->
  pipelineJob("${jobPrefix}-${scope}-${jobSuffix}") {
    description("Dynamically generated with job-dsl by $JOB_NAME\nAny changes to this item will be overwritten without notice.")
    def repo = 'https://github.com/alexandruast/platform-inception'
    keepDependencies(false)
    parameters {
      stringParam('ANSIBLE_TARGET', "user@192.0.2.255", "Which targets to use")
      choiceParam('NOMAD_SCOPE', ["$scope"], "Running in $scope scope only!")
      stringParam('ANSIBLE_EXTRAVARS', "{'foo':'bar'}", "Optional: use extravars(single line JSON string only!)")
    }
    definition {
      cpsScm {
        scm {
          git {
            remote { url(repo) }
            branches('devel')
            scriptPath("factory/jobs/scm/pipeline-nomad-deploy.groovy")
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
