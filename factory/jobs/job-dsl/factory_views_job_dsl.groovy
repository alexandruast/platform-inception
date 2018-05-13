listView('Factory') {
  description("Dynamically generated with job-dsl by $JOB_NAME\nAny changes to this item will be overwritten without notice.")
  filterBuildQueue()
  filterExecutors()
  jobs {
    regex('factory-.+')
  }
  columns {
    status()
    weather()
    name()
    lastSuccess()
    lastFailure()
    lastDuration()
    buildButton()
  }
}