def pods = [
  'fabio',
  'fluentd'
]

def environments = [
  'sandbox',
  'integration',
  'qa'
]

def jobSuffix='deploy'
pods.each { pod ->
  environments.each { environment ->
    pipelineJob("${environment}-${pod}-${jobSuffix}") {
      description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
      def repo = 'https://github.com/alexandruast/platform-inception'
      keepDependencies(false)
      parameters {
        choiceParam('POD_ENVIRONMENT', ["${environment}"], "Running in environment")
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
