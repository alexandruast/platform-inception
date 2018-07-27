// ToDo: Retrieve this from Consul
def environments = [

  sandbox: [
    services: [
      "sys-fluentd",
      "sys-fabio",
      "be-java-echo",
      "be-go-demo",
      
    ],
    images: [
      "sys-py-yaml-to-consul"
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
  categories.each { category, pods ->
    if (category == 'services') {
      jobSuffix='deploy'
    } else {
      jobSuffix='build'
    }
    pods.each { pod ->
      pipelineJob("${environment}-${pod}-${category}-${jobSuffix}") {
        description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
        def repo = 'https://github.com/alexandruast/platform-inception'
        keepDependencies(false)
        environmentVariables {
          env('PLATFORM_ENVIRONMENT', "${environment}")
          env('POD_NAME', "${pod}")
          env('POD_CATEGORY', "${category}")
        }
        definition {
          cpsScm {
            scm {
              git {
                remote { url(repo) }
                branches('devel')
                scriptPath("common/jobs/scm/compose-pod-pipeline.groovy")
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

