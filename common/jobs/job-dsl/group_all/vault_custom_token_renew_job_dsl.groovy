pipelineJob("vault-custom-token-renew") {
  description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
  def repo = 'https://github.com/alexandruast/platform-inception'
  keepDependencies(false)
  parameters {
    nonStoredPasswordParam('VAULT_TOKEN', "Vault token")
    stringParam('RENEW_INCREMENT', "48h", "Time to increment")
  }
  definition {
    cpsScm {
      scm {
        git {
          remote { url(repo) }
          branches('devel')
          scriptPath("common/jobs/scm/vault-custom-token-renew-pipeline.groovy")
          extensions {
            cleanBeforeCheckout()
          }
          lightweight(true)
        }
      }
    }
  }
}
