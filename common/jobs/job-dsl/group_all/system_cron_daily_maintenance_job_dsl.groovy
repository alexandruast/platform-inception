pipelineJob("system-cron-daily-maintenance") {
  description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
  triggers { cron('H 00 * * *') }
  def repo = 'https://github.com/alexandruast/platform-inception'
  keepDependencies(false)
  definition {
    cpsScm {
      scm {
        git {
          remote { url(repo) }
          branches('devel')
          scriptPath("common/jobs/scm/system-cron-daily-maintenance-pipeline.groovy")
          extensions {
            cleanBeforeCheckout()
          }
          lightweight(true)
        }
      }
    }
  }
}
