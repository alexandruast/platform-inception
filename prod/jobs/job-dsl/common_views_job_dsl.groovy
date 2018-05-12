listView('System') {
  description("Dynamically generated with job-dsl by $JOB_NAME\nAny changes to this item will be overwritten without notice.")
  filterBuildQueue()
  filterExecutors()
  jobs {
    regex('system-.+')
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

listView('Infra-Generic') {
  description("Dynamically generated with job-dsl by $JOB_NAME\nAny changes to this item will be overwritten without notice.")
  filterBuildQueue()
  filterExecutors()
  jobs {
    regex('infra-generic-.+')
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