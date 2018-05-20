pipelineJob("system-vault-jenkins-token-renew") {
  description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
  def repo = 'https://github.com/alexandruast/platform-inception'
  keepDependencies(false)
  parameters {
    stringParam('VAULT_ADDR', "http://vault.service.consul:8200", "Vault address")
    nonStoredPasswordParam('VAULT_TOKEN', "Vault token")
    stringParam('SECRET_KEY', "secret/foo", "Key to store secret")
    nonStoredPasswordParam('SECRET_VALUE', "Secret value")
  }
  definition {
    cpsScm {
      scm {
        git {
          remote { url(repo) }
          branches('devel')
          scriptPath("common/jobs/scm/system-vault-secret-update-pipeline.groovy")
          extensions {
            cleanBeforeCheckout()
          }
          lightweight(true)
        }
      }
    }
  }
}
