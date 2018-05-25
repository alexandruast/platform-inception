def environments = [
  "sandbox",
  "integration",
  "qa"
]

def pods = [
  "fluentd",
  "fabio",
  "echo"
]

def jobSuffix='deploy'
environments.each { environment ->
  pods.each { pod ->
    pipelineJob("${environment}-${pod}-${jobSuffix}") {
      description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
      def repo = 'https://github.com/alexandruast/platform-inception'
      keepDependencies(false)
      parameters {
        choiceParam('PLATFORM_ENVIRONMENT', ["${environment}"], "Running in environment")
        choiceParam('POD_NAME', ["${pod}"], "Pod name")
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

