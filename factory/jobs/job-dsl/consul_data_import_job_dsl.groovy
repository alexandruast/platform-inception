def environments = [
  'sandbox',
  'integration',
  'qa'
]

environments.each { environment ->
  pipelineJob("${environment}-consul-data-import") {
    description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
    def repo = 'https://github.com/alexandruast/platform-inception'
    keepDependencies(false)
    environmentVariables {
      env('PLATFORM_ENVIRONMENT', "${environment}")
    }
    definition {
      cpsScm {
        scm {
          git {
            remote { url(repo) }
            branches('devel')
            scriptPath("common/jobs/scm/consul-data-import-pipeline.groovy")
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
