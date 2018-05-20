pipelineJob("system-jenkins-vault-token-renew") {
  description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
  triggers { cron('H 00 * * *') }
  def repo = 'https://github.com/alexandruast/platform-inception'
  keepDependencies(false)
  parameters {
    stringParam('VAULT_ADDR', "http://vault.service.consul:8200", "Vault address")
  }
  definition {
    cpsScm {
      scm {
        git {
          remote { url(repo) }
          branches('devel')
          scriptPath("common/jobs/scm/system-jenkins-vault-token-renew-pipeline.groovy")
          extensions {
            cleanBeforeCheckout()
          }
          lightweight(true)
        }
      }
    }
  }
}
