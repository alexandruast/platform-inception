def services = [
  'fabio',
  'fluentd'
]

def environments = [
  'devel',
  'staging',
  'integration'
]

def jobSuffix='deploy'
services.each { service ->
  environments.each { environment ->
    pipelineJob("${environment}-${service}-${jobSuffix}") {
      description("Dynamically generated with job-dsl by $JOB_NAME\nAny changes to this item will be overwritten without notice.")
      def repo = 'https://github.com/alexandruast/platform-inception'
      keepDependencies(false)
      parameters {
        choiceParam('SERVICE_ENVIRONMENT', ["${environment}"], "Running in $environment environment")
        choiceParam('SERVICE_NAME', ["${service}"], "Service name")
        choiceParam('SERVICE_VERSION', ["latest"], "Service version")
        stringParam('ANSIBLE_EXTRAVARS', "{'ansible_user':'ec2-user'}", "Optional: JSON format single line, single quoutes")
      }
      definition {
        cpsScm {
          scm {
            git {
              remote { url(repo) }
              branches('devel')
              scriptPath("origin/jobs/scm/pipeline-infra-service-deploy.groovy")
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
