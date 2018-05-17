pipelineJob("infra-generic-os-update") {
  description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
  def repo = 'https://github.com/alexandruast/platform-inception'
  keepDependencies(false)
  parameters {
    stringParam('ANSIBLE_TARGET', "192.0.2.255", "Targets to use")
    stringParam('ANSIBLE_EXTRAVARS', "{'ansible_user':'ec2-user'}", "Optional: JSON format single line, single quoutes")
  }
  definition {
    cpsScm {
      scm {
        git {
          remote { url(repo) }
          branches('devel')
          scriptPath("common/jobs/scm/pipeline-infra-generic-os-update.groovy")
          extensions {
            cleanBeforeCheckout()
          }
          lightweight(true)
        }
      }
    }
  }
}
