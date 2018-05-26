def environments = [
  "sandbox",
  "integration",
  "qa"
]

def pods = [
  "fluentd",
  "fabio",
  "echo",
  "sleep"
]

def jobSuffix='deploy'
environments.each { environment ->
  pods.each { pod ->
    pipelineJob("${environment}-${pod}-${jobSuffix}") {
      description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
      def repo = 'https://github.com/alexandruast/platform-inception'
      keepDependencies(false)
      environmentVariables {
        env('PLATFORM_ENVIRONMENT', "${environment}")
        env('POD_NAME', "${pod}")
      }
      definition {
        cpsScm {
          scm {
            git {
              remote { url(repo) }
              branches('devel')
              scriptPath("common/jobs/scm/basic-compose-pod-pipeline.groovy")
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

