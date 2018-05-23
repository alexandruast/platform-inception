def views = [
  system: 'system',
  infra:  'infra',
  meta:   'vault|consul'
]

views.each { view, filter ->
  listView(view) {
    description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
    filterBuildQueue()
    filterExecutors()
    jobs {
      regex("${filter}-.+")
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
}
