// def pods = [
//   'fabio',
//   'fluentd'
// ]
// 
// def environments = [
//   'sandbox',
//   'integration',
//   'qa'
// ]

def environments = [
  sandbox: [
    fabio: {
      url:    "https://github.com/alexandruast/platform-inception",
      branch: "*/devel"
    },
    fluentd: {
      url:    "https://github.com/alexandruast/platform-inception",
      branch: "*/devel"
    }
  ],
  integration: [
    fabio: {
      url:    "https://github.com/alexandruast/platform-inception",
      branch: "*/devel"
    },
    fluentd: {
      url:    "https://github.com/alexandruast/platform-inception",
      branch: "*/devel"
    }
  ],
  qa: [
    fabio: {
      url:    "https://github.com/alexandruast/platform-inception",
      branch: "*/devel"
    },
    fluentd: {
      url:    "https://github.com/alexandruast/platform-inception",
      branch: "*/devel"
    }
  ]
]

def jobSuffix='deploy'
environments.each { environment, pods ->
  pods.each { pod, details ->
    pipelineJob("${environment}-${pod}-${jobSuffix}") {
      description("Dynamically generated with job-dsl by ${JOB_NAME}\nAny changes to this item will be overwritten without notice.")
      def repo = 'https://github.com/alexandruast/platform-inception'
      keepDependencies(false)
      parameters {
        choiceParam('POD_ENVIRONMENT', ["${environment}"], "Running in environment")
        choiceParam('POD_NAME', ["${pod}"], "Pod name")
        choiceParam('POD_SCM', ["${details.url}"], "SCM URL")
        choiceParam('POD_BRANCH', ["${details.branch}"], "SCM branch")
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

