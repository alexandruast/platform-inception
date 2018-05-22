pipelineJob("vault-secret-update") {
  description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
  def repo = 'https://github.com/alexandruast/platform-inception'
  keepDependencies(false)
  parameters {
    nonStoredPasswordParam('VAULT_TOKEN', "Vault token")
    stringParam('SECRET_KEY', "operations/foo", "Key to store secret")
    nonStoredPasswordParam('SECRET_VALUE', "Secret value")
  }
  definition {
    cpsScm {
      scm {
        git {
          remote { url(repo) }
          branches('devel')
          scriptPath("common/jobs/scm/vault-secret-update-pipeline.groovy")
          extensions {
            cleanBeforeCheckout()
          }
          lightweight(true)
        }
      }
    }
  }
}
