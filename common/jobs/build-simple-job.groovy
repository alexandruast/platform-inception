def instance = Hudson.instance
def job = instance.getItem("{{ JENKINS_BUILD_JOB }}")
def futureTask = job.scheduleBuild2(0)
def build = futureTask.get()
if (build.result.toString() != "SUCCESS" && build.result.toString() != "UNSTABLE") {
  throw new AbortException("${build.fullDisplayName} ${build.result.toString()}")
}
println("${build.fullDisplayName} ${build.result.toString()}")
