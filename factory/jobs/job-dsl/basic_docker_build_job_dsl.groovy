def environments = [
  "sandbox",
  "integration",
  "qa"
]

def pods = [
  "yaml-to-consul"
]

def jobSuffix='build'
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
      // parameters {
      //   choiceParam('PLATFORM_ENVIRONMENT', ["${environment}"], "Running in environment")
      //   choiceParam('POD_NAME', ["${pod}"], "Pod name")
      // }
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

