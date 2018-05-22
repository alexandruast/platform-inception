def environments = [
  "sandbox",
  "integration",
  "qa"
]

def services = [
  "yaml-to-consul"
]

def jobSuffix='build'
environments.each { environment ->
  services.each { service ->
    pipelineJob("${environment}-${service}-${jobSuffix}") {
      description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
      def repo = 'https://github.com/alexandruast/platform-inception'
      keepDependencies(false)
      parameters {
        choiceParam('PLATFORM_ENVIRONMENT', ["${environment}"], "Running in environment")
        choiceParam('SERVICE_NAME', ["${service}"], "Service name")
      }
      definition {
        cpsScm {
          scm {
            git {
              remote { url(repo) }
              branches('devel')
              scriptPath("common/jobs/scm/basic-docker-build-pipeline.groovy")
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

