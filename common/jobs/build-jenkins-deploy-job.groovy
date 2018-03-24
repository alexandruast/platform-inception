def instance = Hudson.instance
def job = instance.getItem("{{JENKINS_BUILD_JOB}}")
def params = [
  new PasswordParameterValue("JENKINS_ADMIN_PASS", "{{JENKINS_ADMIN_PASS}}"),
  new StringParameterValue("ANSIBLE_TARGET", "{{ANSIBLE_TARGET}}"),
  new StringParameterValue("JENKINS_SCOPE", "{{JENKINS_SCOPE}}")
]
def futureTask = job.scheduleBuild2(0, new ParametersAction(params))
def build = futureTask.get()
if (build.result.toString() != "SUCCESS" && build.result.toString() != "UNSTABLE") {
  throw new AbortException("${build.fullDisplayName} ${build.result.toString()}")
}
println("${build.fullDisplayName} ${build.result.toString()}")