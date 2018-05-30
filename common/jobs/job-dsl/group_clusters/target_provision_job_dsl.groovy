def services = [
  consul : ['server'],
  nomad  : ['server', 'compute'],
  vault  : ['server']
]

services.each { service, scopes ->
  def jobPrefix="ansible-target-${service}"
  def jobSuffix='provision'
  scopes.each { scope ->
    pipelineJob("${jobPrefix}-${scope}-${jobSuffix}") {
      description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
      def repo = 'https://github.com/alexandruast/platform-inception'
      keepDependencies(false)
      parameters {
        stringParam('ANSIBLE_TARGET', "192.0.2.255", "Targets to use")
        choiceParam('ANSIBLE_SERVICE', ["${service}"], "Service to deploy")
        choiceParam('ANSIBLE_SCOPE', ["${scope}"], "Running in scope")
        stringParam('ANSIBLE_EXTRAVARS', "{'ansible_user':'ec2-user'}", "Optional: JSON format single line, single quoutes")
      }
      definition {
        cpsScm {
          scm {
            git {
              remote { url(repo) }
              branches('devel')
              scriptPath("common/jobs/scm/target-provision-pipeline.groovy")
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
}
