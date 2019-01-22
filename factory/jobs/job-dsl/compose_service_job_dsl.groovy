// ToDo: Retrieve this from Consul
def environments = [

  sandbox: [
    services: [
      "sys-fluentd",
      "sys-fabio",
      "be-java-echo",
      "be-go-demo",
      "sys-sonar7",
      "sys-influxdb",
      "sys-grafana"
      
    ],
    images: [
      "sys-py-yaml-to-consul",
      "sys-py-sonar-to-influxdb"
    ]
  ],

  integration: [
    services: [],
    images: []
  ],

  qa: [
    services: [],
    images: []
  ]
]

environments.each { environment, categories ->
  categories.each { category, services ->
    if (category == 'services') {
      jobSuffix='deploy'
    } else {
      jobSuffix='build'
    }
    services.each { service ->
      pipelineJob("${environment}-${service}-${category}-${jobSuffix}") {
        description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
        def repo = 'https://github.com/alexandruast/platform-inception'
        keepDependencies(false)
        environmentVariables {
          env('PLATFORM_ENVIRONMENT', "${environment}")
          env('SERVICE_NAME', "${service}")
          env('SERVICE_CATEGORY', "${category}")
        }
        definition {
          cpsScm {
            scm {
              git {
                remote { url(repo) }
                branches('devel')
                scriptPath("common/jobs/scm/compose-service-pipeline.groovy")
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
}

