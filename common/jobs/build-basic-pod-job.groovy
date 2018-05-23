def instance = Hudson.instance
def job = instance.getItem("{{JENKINS_BUILD_JOB}}")
def params = [
  new StringParameterValue("PLATFORM_ENVIRONMENT", "{{PLATFORM_ENVIRONMENT}}"),
  new StringParameterValue("POD_NAME", "{{POD_NAME}}")
]
def futureTask = job.scheduleBuild2(0, new ParametersAction(params))
def build = futureTask.get()
if (build.result.toString() != "SUCCESS" && build.result.toString() != "UNSTABLE") {
  throw new AbortException("${build.fullDisplayName} ${build.result.toString()}")
}
println("${build.fullDisplayName} ${build.result.toString()}")